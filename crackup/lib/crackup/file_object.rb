require 'crackup/fs_object'
require 'digest/sha2'

module Crackup

  # Represents a file on the local filesystem.
  class FileObject
    include FileSystemObject

    attr_reader :file_hash, :url
  
    def initialize(filename)
      unless File.file?(filename)
        raise ArgumentError, "#{filename} is not a file"
      end
      
      super(filename)
      
      # Get the file's SHA256 hash.
      digest = Digest::SHA256.new
      
      File.open(filename, 'rb') do |file|
        while buffer = file.read(1048576) do
          digest << buffer
        end
      end

      @file_hash = digest.hexdigest()
      @url       = "#{Crackup.driver.url}/crackup_#{@name_hash}"
    end

    # Compares the specified Crackup::FileObject to this one. Returns +false+ if
    # _file_ is different, +true+ if _file_ is the same. The comparison is
    # performed using an SHA256 hash of the file contents.
    def ==(file)
      return file.name == @name && file.file_hash == @file_hash
    end

    # Removes this file from the remote location.
    def remove
      Crackup.debug "--> #{@name}"
      Crackup.driver.delete(@url)
    end

    # Restores the remote copy of this file to the local path specified by
    # _path_. If the file already exists at _path_, it will be overwritten.
    def restore(path)
      path     = path.chomp('/') + '/' + File.dirname(@name).delete(':')
      filename = path + '/' + File.basename(@name)

      Crackup.debug "--> #{filename}"
      
      # Create the path if it doesn't exist.
      unless File.directory?(path)
        begin
          FileUtils.mkdir_p(path)
        rescue => e
          raise Crackup::Error, "Unable to create local directory: #{path}"
        end
      end
      
      # Download the remote file.
      tempfile = Crackup.get_tempfile()
      Crackup.driver.get(@url, tempfile)
      
      # Decompress/decrypt the file.
      if Crackup.options[:passphrase].nil?
        Crackup.decompress_file(tempfile, filename)
      else
        Crackup.decrypt_file(tempfile, filename)
      end
    end
    
    # Uploads this file to the remote location.
    def update
      Crackup.debug "--> #{@name}"
      
      # Compress/encrypt the file.
      tempfile = Crackup.get_tempfile()
      
      if Crackup.options[:passphrase].nil?
        Crackup.compress_file(@name, tempfile)
      else
        Crackup.encrypt_file(@name, tempfile)
      end
      
      # Upload the file.
      Crackup.driver.put(@url, tempfile)
    end
  end

end
