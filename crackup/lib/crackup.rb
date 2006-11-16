ENV['PATH'] = "#{File.dirname(__FILE__)};#{ENV['PATH']}"

require 'crackup/errors'
require 'crackup/dirobject'
require 'crackup/driver'
require 'crackup/fileobject'
require 'tempfile'
require 'zlib'

module Crackup

  GPG_DECRYPT = 'echo :passphrase | gpg --batch --quiet --no-tty --no-secmem-warning --cipher-algo aes256 --compress-algo bzip2 --passphrase-fd 0 --output :output_file :input_file'
  GPG_ENCRYPT = 'echo :passphrase | gpg --batch --quiet --no-tty --no-secmem-warning --cipher-algo aes256 --compress-algo bzip2 --passphrase-fd 0 --output :output_file --symmetric :input_file'
  
  attr_accessor :driver, :local_files, :options, :remote_files
  
  # Reads _infile_ and compresses it to _outfile_ using zlib compression.
  def self.compress_file(infile, outfile)
    File.open(infile, 'rb') do |input|
      Zlib::GzipWriter.open(outfile, 9) do |output|
        while data = input.read(1048576) do
          output.write(data)
        end
      end
    end
    
  rescue => e
    raise Crackup::CompressionError, "Unable to compress #{infile}: #{e}"
  end
  
  # Prints _message_ to +stdout+ if verbose mode is enabled.
  def self.debug(message)
    puts message if @options[:verbose] || $VERBOSE
  end
  
  # Reads _infile_ and decompresses it to _outfile_ using zlib compression.
  def self.decompress_file(infile, outfile)
    Zlib::GzipReader.open(infile) do |input|
      File.open(outfile, 'wb') do |output|
        while data = input.read(1048576) do
          output.write(data)
        end
      end
    end
  
  rescue => e
    raise Crackup::CompressionError, "Unable to decompress #{infile}: #{e}"
  end
  
  # Calls GPG to decrypt _infile_ to _outfile_.
  def self.decrypt_file(infile, outfile)
    File.delete(outfile) if File.exist?(outfile)

    gpg_command = String.new(GPG_DECRYPT)
    gpg_command.gsub!(':input_file', escapeshellarg(infile))
    gpg_command.gsub!(':output_file', escapeshellarg(outfile))
    gpg_command.gsub!(':passphrase', escapeshellarg(@options[:passphrase]))
    
    unless system(gpg_command)
      raise Crackup::EncryptionError, "Unable to decrypt file: #{infile}"
    end
  end
  
  def self.driver
    return @driver
  end
  
  # Calls GPG to encrypt _infile_ to _outfile_.
  def self.encrypt_file(infile, outfile)
    File.delete(outfile) if File.exist?(outfile)

    gpg_command = String.new(GPG_ENCRYPT)
    gpg_command.gsub!(':input_file', escapeshellarg(infile))
    gpg_command.gsub!(':output_file', escapeshellarg(outfile))
    gpg_command.gsub!(':passphrase', escapeshellarg(@options[:passphrase]))
    
    unless system(gpg_command)
      raise Crackup::EncryptionError, "Unable to encrypt file: #{infile}"
    end
  end
  
  # Prints the specified _message_ to +stderr+ and exits with an error
  # code of 1.
  def self.error(message)
    abort "#{APP_NAME}: #{message}"
  end
  
  # Wraps _arg_ in single quotes, escaping any single quotes contained therein,
  # thus making it safe for use as a shell argument.
  def self.escapeshellarg(arg)
    return "'#{arg.gsub("'", "\\'")}'"
  end
  
  # Gets an array of files in the remote file index whose local paths match
  # _pattern_.
  def self.find_remote_files(pattern)
    files = []
    pattern.chomp!('/')
    
    @remote_files.each do |name, file|
      if File.fnmatch?(pattern, file.name)
        files << file
        next
      end

      next unless file.is_a?(Crackup::DirectoryObject)
      files += file.find(pattern)
    end
    
    return files
  end
  
  # Gets a flat array of filenames from _files_, which may be either a Hash
  # or a Crackup::FileSystemObject.
  def self.get_list(files)
    list = []
  
    if files.is_a?(Hash)
      files.each_value {|value| list += get_list(value) }
    elsif files.is_a?(Crackup::DirectoryObject)
      list += get_list(files.children)
    elsif files.is_a?(Crackup::FileObject)
      list << files.name 
    end
    
    return list
  end

  # Gets a Hash of Crackup::FileSystemObjects representing the files and
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
        local_files[filename] = Crackup::DirectoryObject.new(filename)
      elsif File.file?(filename)
        debug "--> #{filename}"
        local_files[filename] = Crackup::FileObject.new(filename)
      end
    end
    
    return local_files
  end
  
  # Gets a Hash of Crackup::FileSystemObjects present at the remote location.
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
        raise Crackup::IndexError, "Unable to decompress index file. Maybe " +
            "it's encrypted?"
      end
    else
      begin
        decrypt_file(oldfile, tempfile)
      rescue => e
        raise Crackup::IndexError, "Unable to decrypt index file."
      end
    end
    
    # Load the index file.
    file_list = {}

    begin
      File.open(tempfile, 'rb') {|file| file_list = Marshal.load(file) }
    rescue => e
      raise Crackup::IndexError, "Remote index is invalid!"
    end
    
    unless file_list.is_a?(Hash)
      raise Crackup::IndexError, "Remote index is invalid!"
    end
    
    return file_list
  end
  
  # Gets an Array of Crackup::FileSystemObjects representing files and
  # directories that exist at the remote location but no longer exist at the
  # local location.
  def self.get_removed_files(local_files, remote_files)
    removed = []

    remote_files.each do |name, remotefile|
      unless local_files.has_key?(name)
        removed << remotefile
        next
      end

      localfile = local_files[name]
      
      if remotefile.is_a?(Crackup::DirectoryObject) && 
          localfile.is_a?(Crackup::DirectoryObject)
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

  # Gets an Array of Crackup::FileSystemObjects representing files and
  # directories that are new or have been modified at the local location and
  # need to be updated at the remote location.
  def self.get_updated_files(local_files, remote_files)
    updated = []
    
    local_files.each do |name, localfile|
      # Add the file to the list if it doesn't exist at the remote location.
      unless remote_files.has_key?(name)
        updated << localfile
        next
      end
      
      remotefile = remote_files[name]
      
      if localfile.is_a?(Crackup::DirectoryObject) && 
          remotefile.is_a?(Crackup::DirectoryObject)
        # Add to the list all updated files contained in the directory and its 
        # subdirectories.
        updated += get_updated_files(localfile.children, remotefile.children)
      elsif localfile.is_a?(Crackup::FileObject) && 
          remotefile.is_a?(Crackup::FileObject)
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

  # Prints _message_ to +stdout+ and waits for user input, which is then
  # returned.
  def self.prompt(message)
    puts message + ': '
    return $stdin.gets
  end
  
  # Deletes each Crackup::FileSystemObject specified in the _files_ array from
  # the remote location.
  def self.remove_files(files)
    files.each do |file|
      file.remove
    end
  end
  
  # Uploads each Crackup::FileSystemObject specified in the _files_ array to the
  # remote location.
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
      raise Crackup::IndexError, "Unable to update remote index: #{e}"
    end
  end
  
end
