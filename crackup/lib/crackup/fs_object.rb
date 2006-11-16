require 'digest/sha2'

module Crackup
  
  # Represents a filesystem object on the local filesystem.
  module FileSystemObject
    attr_reader :name, :name_hash
    
    #--
    # Public Class Methods
    #++
    
    # Returns an instance of the appropriate FileSystemObject subclass to
    # represent _path_.
    def self.from(path)
      return Crackup::SymlinkObject.new(path) if File.symlink?(path)
      return Crackup::DirectoryObject.new(path) if File.directory?(path)
      return Crackup::FileObject.new(path) if File.file?(path)
      
      raise Crackup::Error, "Unsupported filesystem object: #{path}"
    end
    
    #--
    # Public Instance Methods
    #++
    
    def initialize(name)
      @name      = name.chomp('/')
      @name_hash = Digest::SHA256.hexdigest(name)
    end
    
    def ==(fs_object); end
    def remove; end
    def restore(path); end
    
    def to_s
      return @name
    end
    
    def update; end
  end

end
