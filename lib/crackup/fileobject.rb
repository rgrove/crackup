require 'crackup/fsobject'
require 'digest/sha2'
require 'fileutils'
require 'time'

module Crackup

  # Represents a file on the local filesystem.
  class FileObject
    include FileSystemObject
    
    attr_reader :path, :dir_path, :ctime, :mtime, :inode, :size, :timestamp
  
    # --
    # Class Methods
    # ++
    
    def initialize(path, dir_path, hash, ctime, mtime, inode, size,
        timestamp = Time.new.to_i)
      super(path)
      
      @dir_path  = dir_path
      @hash      = hash
      @ctime     = ctime
      @mtime     = mtime
      @inode     = inode
      @size      = size
      @timestamp = timestamp
    end
    
    # Gets a new Crackup::FileObject representing the Hash _row_, which should
    # contain the contents of a database row.
    def self.from_db(row)
      return FileObject.new(row['path'], row['dir_path'], row['hash'],
          row['ctime'], row['mtime'], row['inode'], row['size'], 
          row['timestamp'])
    end
    
    # Creates a new Crackup::FileObject representing the specified local
    # filename. 
    def self.from_path(path)
      unless File.file?(path)
        raise ArgumentError, "#{path} is not a file"
      end
      
      unless File.readable?(path)
        raise Crackup::Error, "#{path} is not readable"
      end
      
      stat = File.stat(path)
      
      return FileObject.new(path, File.dirname(path), nil, stat.ctime.to_i,
          stat.mtime.to_i, stat.ino, stat.size)
    end
    
    # --
    # Instance Methods
    # ++
    
    # Gets an SHA256 hash of the file's contents. The results of this method are
    # cached, so subsequent calls will always return the same hash. 
    def hash
      return @hash unless @hash.nil?
      
      digest = Digest::SHA256.new
      
      File.open(@path, 'rb') do |file|
        while buffer = file.read(1048576) do
          digest << buffer
        end
      end

      return @hash = digest.hexdigest()
      
    rescue => e
      raise Crackup::Error, "Unable to generate file hash: #{e}"
    end

    # Removes this file from the remote location.
    def remove
      Crackup.debug "--> #{@name}"
      Crackup.driver.delete(@url)
    end

    # Restores the remote copy of this file to the local path specified by
    # <em>path</em>.
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
