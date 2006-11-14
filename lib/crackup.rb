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

ENV['PATH'] = "#{File.dirname(__FILE__)};#{ENV['PATH']}"

require 'crackup/fsobject'
require 'crackup/directory'
require 'crackup/driver'
require 'crackup/file'
require 'tempfile'
require 'yaml'
require 'zlib'

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
    
  rescue => e
    raise CrackupCompressionError, "Unable to compress #{infile}: #{e}"
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
  
  rescue => e
    raise CrackupCompressionError, "Unable to decompress #{infile}: #{e}"
  end
  
  # Calls GPG to decrypt <em>infile</em> to <em>outfile</em>.
  def self.decrypt_file(infile, outfile)
    File.delete(outfile) if File.exist?(outfile)

    gpg_command = String.new(GPG_DECRYPT)
    gpg_command.gsub!(':input_file', escapeshellarg(infile))
    gpg_command.gsub!(':output_file', escapeshellarg(outfile))
    gpg_command.gsub!(':passphrase', escapeshellarg(@options[:passphrase]))
    
    unless system(gpg_command)
      raise CrackupEncryptionError, "Unable to decrypt file: #{infile}"
    end
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
    
    unless system(gpg_command)
      raise CrackupEncryptionError, "Unable to encrypt file: #{infile}"
    end
  end
  
  # Prints the specified <em>message</em> to stderr and exits with an error
  # code of 1.
  def self.error(message)
    abort "#{APP_NAME}: #{message}"
  end
  
  # Wraps <em>arg</em> in single quotes, escaping any single quotes contained
  # therein, thus making it safe for use as a shell argument.
  def self.escapeshellarg(arg)
    return "'#{arg.gsub("'", "\\'")}'"
  end
  
  # Gets an array of files in the remote file index whose local filenames match
  # <em>pattern</em>.
  def self.find_remote_files(pattern)
    files = []
    pattern.chomp!('/')
    
    @remote_files.each do |name, file|
      if File.fnmatch?(pattern, file.name)
        files << file
        next
      end

      next unless file.is_a?(CrackupDirectory)

      files += file.find(pattern)
    end
    
    return files
  end
  
  # Gets an array of filenames from <em>files</em>, which may be either a Hash
  # or a CrackupFileSystemObject.
  def self.get_list(files)
    list = []
  
    if files.is_a?(Hash)
      files.each_value {|value| list += get_list(value) }
    elsif files.is_a?(CrackupDirectory)
      list += get_list(files.children)
    elsif files.is_a?(CrackupFile)
      list << files.name 
    end
    
    return list
  end

  # Gets a Hash of CrackupFileSystemObjects representing the files and
  # directories on the local system in the locations specified by the array of
  # filenames in <tt>options[:from]</tt>.
  def self.get_local_files
    local_files = {}
    
    @options[:from].each do |filename|
      next unless File.exist?(filename = filename.chomp('/'))
      next if local_files.has_key?(filename)
      
      # Skip this file if it's in the exclusion list.
      unless @options[:exclude].nil?
        next if @options[:exclude].any? do |pattern|
          File.fnmatch?(pattern, filename)
        end
      end
      
      if File.directory?(filename)
        debug "--> #{filename}"
        local_files[filename] = CrackupDirectory.new(filename)
      elsif File.file?(filename)
        debug "--> #{filename}"
        local_files[filename] = CrackupFile.new(filename)
      end
    end
    
    return local_files
  end
  
  # Gets a Hash of CrackupFileSystemObjects present at the remote location.
  def self.get_remote_files(url)
    tempfile = get_tempfile()
    
    # Download the index file.
    begin
      @driver.get(url + '/.crackup_index', tempfile)
    rescue => e
      return {}
    end
    
    # Decompress/decrypt the index file.
    oldfile  = tempfile
    tempfile = get_tempfile()
    
    if @options[:passphrase].nil?
      begin
        decompress_file(oldfile, tempfile)
      rescue => e
        raise CrackupIndexError, "Unable to decompress index file. Maybe " +
            "it's encrypted?"
      end
    else
      begin
        decrypt_file(oldfile, tempfile)
      rescue => e
        raise CrackupIndexError, "Unable to decrypt index file."
      end
    end
    
    # Load the index file.
    file_list = {}

    begin
      File.open(tempfile, 'rb') {|file| file_list = Marshal.load(file) }
    rescue => e
      raise CrackupIndexError, "Remote index is invalid!"
    end
    
    unless file_list.is_a?(Hash)
      raise CrackupIndexError, "Remote index is invalid!"
    end
    
    return file_list
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
  
    File.open(tempfile, 'wb') {|file| Marshal.dump(@local_files, file) }
    
    oldfile  = tempfile
    tempfile = get_tempfile()
    
    if @options[:passphrase].nil?
      compress_file(oldfile, tempfile)
    else
      encrypt_file(oldfile, tempfile)
    end
    
    begin
      success = @driver.put(remotefile, tempfile)
    rescue => e
      tryagain = prompt('Unable to update remote index. Try again? (y/n)')
    
      retry if tryagain.downcase == 'y'
      raise CrackupIndexError, "Unable to update remote index: #{e}"
    end
  end
  
  class CrackupError < StandardError; end
  class CrackupCompressionError < CrackupError; end
  class CrackupEncryptionError < CrackupError; end
  class CrackupIndexError < CrackupError; end
  class CrackupStorageError < CrackupError; end
end
