require 'set'
require 'tempfile'
require 'yaml'
require 'zlib'
require "#{File.dirname(__FILE__)}/CrackupFileSystemObject"
require "#{File.dirname(__FILE__)}/CrackupDirectory"
require "#{File.dirname(__FILE__)}/CrackupDriver"
require "#{File.dirname(__FILE__)}/CrackupFile"

# Crackup (Crappy Remote Backup) is a pretty simple, pretty secure remote
# backup solution for folks who want to keep their data securely backed up but
# aren't particularly concerned about bandwidth usage.
# 
# Crackup is ideal for backing up lots of small files, but somewhat less ideal
# for backing up large files, since any change to a file means the entire file
# must be transferred. If you need something bandwidth-efficient, try Duplicity.
# 
# Backups are compressed and encrypted via GPG and can be transferred to the
# remote location over a variety of protocols, including FTP.
#
# Requires Ruby 1.8.5+ and GPG 1.4.2+
# 
# Author::    Ryan Grove (mailto:ryan@wonko.com)
# Copyright:: Copyright (c) 2006 Ryan Grove. All rights reserved.
# License::   New BSD License (http://opensource.org/licenses/bsd-license.php)
module Crackup
  GPG_DECRYPT = 'echo :passphrase | gpg --batch --quiet --no-tty --no-secmem-warning --cipher-algo aes256 --compress-algo bzip2 --passphrase-fd 0 --output :output_file :input_file'
  GPG_ENCRYPT = 'echo :passphrase | gpg --batch --quiet --no-tty --no-secmem-warning --cipher-algo aes256 --compress-algo bzip2 --passphrase-fd 0 --output :output_file --symmetric :input_file'
  
  attr_accessor :driver, :local_files, :options, :remote_files
  
  # Reads <em>infile</em> and compresses it to <em>outfile</em> using zlib
  # compression.
  def self.compress_file(infile, outfile)
    File.open(infile, 'rb') do |input|
      Zlib::GzipWriter.open(outfile, 9) do |output|
        while data = input.read(1048576) do
          output.write(data)
        end
      end
    end
  end
  
  # Prints <em>message</em> to stdout if verbose mode is enabled.
  def self.debug(message)
    puts message if @options[:verbose] || $VERBOSE
  end
  
  # Reads <em>infile</em> and decompresses it to <em>outfile</em> using zlib
  # compression.
  def self.decompress_file(infile, outfile)
    Zlib::GzipReader.open(infile) do |input|
      File.open(outfile, 'wb') do |output|
        while data = input.read(1048576) do
          output.write(data)
        end
      end
    end
  end
  
  # Calls GPG to decrypt <em>infile</em> to <em>outfile</em>.
  def self.decrypt_file(infile, outfile)
    File.delete(outfile) if File.exist?(outfile)

    gpg_command = String.new(GPG_DECRYPT)
    gpg_command.gsub!(':input_file', escapeshellarg(infile))
    gpg_command.gsub!(':output_file', escapeshellarg(outfile))
    gpg_command.gsub!(':passphrase', escapeshellarg(@options[:passphrase]))
    
    system gpg_command
  end
  
  def self.driver
    return @driver
  end
  
  # Calls GPG to encrypt <em>infile</em> to <em>outfile</em>.
  def self.encrypt_file(infile, outfile)
    File.delete(outfile) if File.exist?(outfile)

    gpg_command = String.new(GPG_ENCRYPT)
    gpg_command.gsub!(':input_file', escapeshellarg(infile))
    gpg_command.gsub!(':output_file', escapeshellarg(outfile))
    gpg_command.gsub!(':passphrase', escapeshellarg(@options[:passphrase]))
    
    system gpg_command
  end
  
  # Prints the specified <em>message</em> to stderr and exits with an error
  # code of 1.
  def self.error(message)
    abort "Error: #{message}"
  end
  
  # Wraps <em>arg</em> in single quotes, escaping any single quotes contained
  # therein, thus making it safe for use as a shell argument.
  def self.escapeshellarg(arg)
    return "'#{arg.gsub("'", "\\'")}'"
  end
  
  # Searches the remote file index for a file whose local filename matches
  # <em>filename</em> and returns it if found, or <em>nil</em> otherwise.
  def self.find_remote_file(filename)
    filename.chomp!('/')
    
    if @remote_files.has_key?(filename)
      return @remote_files[filename]
    end
    
    @remote_files.each do |name, file|
      next unless file.is_a?(CrackupDirectory)
      
      if child = file.find(filename)
        return child
      end
    end
    
    return nil
  end
  
  # Gets a SortedSet of CrackupFileSystemObjects representing the files and
  # directories on the local system in the locations specified by the array of
  # filenames in @local.
  def self.get_local_files
    local_files = {}
    
    @options[:from].each do |filename|
      next unless File.exist?(filename = filename.chomp('/'))
      next if local_files.has_key?(filename)
      
      if File.directory?(filename)
        debug '--> ' + filename
        local_files[filename] = CrackupDirectory.new(filename)
      elsif File.file?(filename)
        debug '--> ' + filename
        local_files[filename] = CrackupFile.new(filename)
      end
    end
    
    return local_files
  end
  
  # Gets a SortedSet of CrackupFileSystemObjects present at the remote location.
  def self.get_remote_files(url)
    tempfile = get_tempfile()
    
    begin
      @driver.get(url + '/.crackup_index', tempfile)
    rescue => e
      return {}
    end
    
    oldfile  = tempfile
    tempfile = get_tempfile()
    
    if @options[:passphrase].nil?
      decompress_file(oldfile, tempfile)
    else
      decrypt_file(oldfile, tempfile)
    end
    
    file_list = YAML::load_file(tempfile)
    
    if file_list.is_a?(Hash)
      return file_list
    end
    
    return {}
  end
  
  # Gets an array of CrackupFileSystemObjects representing files and directories
  # that exist at the remote location but no longer exist at the local location.
  def self.get_removed_files(local_files, remote_files)
    removed = []
    
    remote_files.each do |name, remotefile|
      unless local_files.has_key?(name)
        removed << remotefile
        next
      end
      
      localfile = local_files[name]
      
      if remotefile.is_a?(CrackupDirectory) && localfile.is_a?(CrackupDirectory)
        removed += get_removed_files(localfile.children, remotefile.children)
      end
    end
    
    return removed
  end
  
  # Creates a new temporary file in the system's temporary directory and returns
  # its name. All temporary files will be deleted when the program exits.
  def self.get_tempfile
    tempfile = Tempfile.new('.crackup')
    tempfile.close
    
    return tempfile.path
  end

  # Gets an array of CrackupFileSystemObjects representing files and directories
  # that are new or have been modified at the local location and need to be
  # updated at the remote location.
  def self.get_updated_files(local_files, remote_files)
    updated = []
    
    local_files.each do |name, localfile|
      # Add the file to the list if it doesn't exist at the remote location.
      unless remote_files.has_key?(name)
        updated << localfile
        next
      end
      
      remotefile = remote_files[name]
      
      if localfile.is_a?(CrackupDirectory) && remotefile.is_a?(CrackupDirectory)
        # Add to the list all updated files contained in the directory and its 
        # subdirectories.
        updated += get_updated_files(localfile.children, remotefile.children)
      elsif localfile.is_a?(CrackupFile) && remotefile.is_a?(CrackupFile)
        # Add the file to the list if the local file has been modified.
        unless localfile.file_hash == remotefile.file_hash
          updated << localfile
        end
      end
    end
    
    return updated
  end
  
  def self.options
    return @options
  end

  # Prints <em>message</em> to stdout and waits for user input, which is
  # then returned.
  def self.prompt(message)
    puts message + ': '
    return $stdin.gets
  end
  
  # Deletes each CrackupFileSystemObject specified in the <em>files</em> array
  # from the remote location.
  def self.remove_files(files)
    files.each do |file|
      file.remove
    end
  end
  
  # Uploads each CrackupFileSystemObject specified in the <em>files</em> array
  # to the remote location.
  def self.update_files(files)
    files.each do |file|
      file.update
    end
  end
  
  # Brings the remote file index up to date with the local one.
  def self.update_remote_index
    tempfile   = get_tempfile()
    remotefile = @options[:to] + '/.crackup_index'
  
    File.open(tempfile, 'w') do |file|
      YAML.dump(@local_files, file)
    end
    
    oldfile  = tempfile
    tempfile = get_tempfile()
    
    if @options[:passphrase].nil?
      compress_file(oldfile, tempfile)
    else
      encrypt_file(oldfile, tempfile)
    end
    
    success = false
    
    while success == false do
      begin
        success = @driver.put(remotefile, tempfile)
      rescue => e
        tryagain = prompt('Unable to update remote index. Try again? (y/n)')
      
        unless tryagain.downcase == 'y'
          abort
        end
      end
    end
  end
end
