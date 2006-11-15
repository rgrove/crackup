require 'crackup/fsobject'

module Crackup

  # Represents a directory on the local filesystem. Can contain any number of
  # CrackupFileSystemObjects as children.
  class DirectoryObject
    include FileSystemObject

    attr_reader :children, :parent_path, :timestamp

    #--
    # Public Class Methods
    #++
    
    def initialize(path, parent_path, timestamp = Time.new.to_i, children = {})
      super(path)
      
      @parent_path = parent_path
      @timestamp   = timestamp
      @children    = children
    end
    
    def self.from_db(row, children = {})
      return DirectoryObject.new(row['path'], row['parent_path'],
          row['timestamp'], children)
    end
    
    def self.from_path(path)
      unless File.directory?(path)
        raise ArgumentError, "#{path} is not a directory"
      end
      
      dir = DirectoryObject.new(path, File.dirname(path))
      dir.refresh_children()
      
      return dir
    end
    
    #--
    # Public Instance Methods
    #++
    
    # Gets an array of files contained in this directory or its children whose
    # local filenames match <em>pattern</em>.
    def find(pattern)
      files = []
      
      @children.each do |name, child|
        if File.fnmatch?(pattern, child.path)
          files << child
          next
        end
        
        next unless child.is_a?(Crackup::DirectoryObject)
        
        if result = child.find(pattern)
          files << result
        end
      end
      
      return files
    end
    
    def get_index_params(query_name)
      case query_name
        when :add
          return {
            ':path'        => @path,
            ':parent_path' => @parent_path,
            ':name'        => @name,
            ':timestamp'   => Time.new.to_i
          }
        
        when :delete
          return {':path' => @path}
      
        when :update
          return {
            ':path'        => @path,
            ':parent_path' => @parent_path,
            ':timestamp'   => Time.new.to_i
          }
      end
    end

    # Refreshes children by analyzing the local filesystem.
    def refresh_children
      @children = {}

      Dir.open(@path) do |dir|
        dir.each do |filename|
          next if filename == '.' || filename == '..'

          filename = File.join(dir.path, filename).gsub("\\", "/")

          # Skip this file if it's in the exclusion list.
          unless Crackup::options[:exclude].nil?
            next if Crackup::options[:exclude].any? do |pattern|
              File.fnmatch?(pattern, filename)
            end
          end

          if File.directory?(filename)
            @children[filename.chomp('/')] = Crackup::DirectoryObject.from_path(
                filename)
          elsif File.file?(filename)
            @children[filename] = Crackup::FileObject.from_path(filename)
          end
        end
      end
    end

    # Removes the remote copy of this directory and all its children.
    def remove
      @children.each_value {|child| child.remove }
    end

    # Restores the remote copy of this directory to the specified local 
    # <em>path</em>.
    def restore(path)
      @children.each_value {|child| child.restore(path) }
    end
    
    # Uploads this directory and all its children to the remote location.
    def update
      @children.each_value {|child| child.update }
    end
  end

end
