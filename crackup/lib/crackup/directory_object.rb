require 'crackup/fs_object'
require 'fileutils'

module Crackup

  # Represents a directory on the local filesystem. Can contain any number of
  # Crackup::FileSystemObjects as children.
  class DirectoryObject
    include Enumerable
    include FileSystemObject

    attr_reader :children

    #--
    # Public Instance Methods
    #++
    
    def initialize(name)
      unless File.directory?(name)
        raise ArgumentError, "#{name} is not a directory"
      end

      super(name)

      refresh_children()
    end
    
    # Compares the specified Crackup::DirectoryObject to this one. Returns
    # +true+ if the directories and all their children are the same, +false+
    # otherwise.
    def ==(directory)
      return false unless directory.name == @name      
      return directory.all?{|child| child == @children[child.name] }
    end
    
    def [](key)
      return @children[key]
    end
    
    def each
      @children.each {|child| yield child }
    end
    
    # Gets an array of files contained in this directory or its children whose
    # local filenames match _pattern_.
    def find(pattern)
      files = []
      
      @children.each do |name, child|
        if File.fnmatch?(pattern, child.name) ||
            File.fnmatch?(pattern, File.basename(child.name))
          files << child
          next
        end
        
        if child.is_a?(Crackup::DirectoryObject)
          if result = child.find(pattern)
            files += result
          end 
        end
      end
      
      return files
    end

    # Builds a Hash of child objects by analyzing the local filesystem. A
    # refresh is automatically performed when the object is instantiated.
    def refresh_children
      @children = {}

      Dir.open(@name) do |dir|
        dir.each do |filename|
          next if filename == '.' || filename == '..'

          path = File.join(dir.path, filename).gsub("\\", "/")

          # Skip this file if it's in the exclusion list.
          unless Crackup::options[:exclude].nil?
            next if Crackup::options[:exclude].any? do |pattern|
              File.fnmatch?(pattern, path)
            end
          end

          @children[path] = Crackup::FileSystemObject.from(path)
        end
      end
      
      return @children
    end

    # Removes the remote copy of this directory and all its children.
    def remove
      @children.each_value {|child| child.remove }
    end

    # Restores the remote copy of this directory to the specified local _path_.
    # The path will be created if it doesn't exist.
    def restore(path)
      @children.each_value {|child| child.restore(path) }
    end
    
    def to_s
      childnames = []
      @children.each_value {|child| childnames << child.to_s }
      return childnames.join("\n")
    end
    
    # Uploads this directory and all its children to the remote location.
    def update
      @children.each_value {|child| child.update }
    end
  end

end
