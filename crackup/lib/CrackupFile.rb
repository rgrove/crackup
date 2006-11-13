require 'digest/sha2'
require 'fileutils'

module Crackup

  # Represents a file on the local filesystem.
  class CrackupFile < CrackupFileSystemObject
    attr_reader :file_hash, :url
  
    def initialize(filename)
      unless File.file?(filename)
        raise ArgumentError, "#{filename} is not a file"
      end
      
      super(filename)
      
      # Get the file's SHA256 hash.
      digest = Digest::SHA256.new()
      
      File.open(filename, 'rb') do |file|
        until file.eof? do
          digest << file.read(1048576)
        end
      end

      @file_hash = digest.hexdigest()
      @url       = "#{Crackup::driver.url}/crackup_#{@name_hash}"
    end
    
    # Removes this file from the remote location.
    def remove
      Crackup::debug '--> ' + @name
      Crackup::driver.delete(@url)
      
    rescue => e
      Crackup::error "Unable to delete remote file: #{@url}"
    end

    # Restores the remote copy of this file to the local path specified by
    # <em>path</em>.
    def restore(path)
      path     = path.chomp('/') + '/' + File.dirname(@name).delete(':')
      filename = path + '/' + File.basename(@name)

      Crackup::debug '--> ' + filename
      
      # Create the path if it doesn't exist.
      unless File.directory?(path)
        begin
          FileUtils.mkdir_p(path)
        rescue => e
          Crackup::error "Unable to create local directory: #{path}"
        end
      end
      
      # Download the remote file.
      tempfile = Crackup::get_tempfile()
      
      begin
        Crackup::driver.get(@url, tempfile)
      rescue => e
        Crackup::error "Unable to restore file: #{filename}"
      end
      
      # Decompress/decrypt the file.
      if Crackup::options[:passphrase].nil?
        Crackup::decompress_file(tempfile, filename)
      else
        Crackup::decrypt_file(tempfile, filename)
      end
    end
    
    # Uploads this file to the remote location.
    def update
      Crackup::debug '--> ' + @name
      
      # Compress/encrypt the file.
      tempfile = Crackup::get_tempfile()
      
      if Crackup::options[:passphrase].nil?
        Crackup::compress_file(@name, tempfile)
      else
        Crackup::encrypt_file(@name, tempfile)
      end
      
      # Upload the file.
      begin
        Crackup::driver.put(@url, tempfile)
      rescue => e
        Crackup::error "Unable to upload file: #{@name}"
      end
    end
  end
end
