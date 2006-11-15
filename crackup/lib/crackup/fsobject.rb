require 'digest/sha2'

module Crackup
  
  # Represents a filesystem object on the local filesystem.
  module FileSystemObject
    attr_reader :name, :path_hash, :path
    
    #--
    # Class Methods
    #++
    
    def initialize(path)
      @path      = path.chomp('/')
      @name      = File.basename(@path)
      @path_hash = Digest::SHA256.hexdigest(@path)
    end
    
    # Gets a new Crackup::FileSystemObject representing the Hash _row_, which
    # should contain the contents of a database row.
    def self.from_db(row)
      return FileSystemObject.new(row['path'])
    end
    
    # Gets a new Crackup::FileSystemObject representing the local filesystem
    # object specified by _path_.
    def self.from_path(path)
      return FileSystemObject.new(path)
    end
    
    #--
    # Instance Methods
    #++
    
    def remove; end
    def restore(local_path); end
  end

end
