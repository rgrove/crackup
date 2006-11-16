require 'crackup/fs_object'
require 'fileutils'

module Crackup

  # Represents a symbolic link on the local filesystem.
  class SymlinkObject
    include FileSystemObject

    attr_reader :file_hash, :target, :url
  
    #--
    # Public Instance Methods
    #++

    def initialize(linkname)
      unless File.symlink?(linkname)
        raise ArgumentError, "#{linkname} is not a symbolic link"
      end
      
      super(linkname)
      
      @target = File.readlink(linkname)
    end
    
    # Compares the specified Crackup::SymlinkObject to this one. Returns +true+
    # if they're the same, +false+ if _symlink_ is different.
    def ==(symlink)
      return symlink.name == @name && symlink.target == @target
    end
    
    # Removes this link from the remote location. This is actually a noop, since
    # link data is just stored in the index.
    def remove
      Crackup.debug "--> #{@name}"
    end

    # Restores the remote copy of this link to the local path specified by
    # _path_.
    def restore(path)
      path     = path.chomp('/') + '/' + File.dirname(@name).delete(':')
      linkname = path + '/' + File.basename(@name)

      Crackup.debug "--> #{linkname}"
      
      # Create the path if it doesn't exist.
      unless File.directory?(path)
        begin
          FileUtils.mkdir_p(path)
        rescue => e
          raise Crackup::Error, "Unable to create local directory: #{path}"
        end
      end
      
      # Create the link.
      File.symlink(@target, linkname)
    end
    
    # Uploads this link to the remote location. This is actually a noop, since
    # link data is just stored in the index.
    def update
      Crackup.debug "--> #{@name}"
    end
  end

end
