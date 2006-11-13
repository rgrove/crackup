module Crackup

  # Represents a directory on the local filesystem. Can contain any number of
  # CrackupFileSystemObjects as children.
  class CrackupDirectory < CrackupFileSystemObject
    attr_reader :children

    def initialize(name)
      unless File.directory?(name)
        raise ArgumentError, "#{name} is not a directory"
      end

      super(name)

      refresh_children
    end
    
    # Gets an array of files contained in this directory or its children whose
    # local filenames match <em>pattern</em>.
    def find(pattern)
      files = []
      
      @children.each do |name, child|
        if File.fnmatch?(pattern, child.name)
          files << child
          next
        end
        
        next unless child.is_a?(CrackupDirectory)
        
        if result = child.find(pattern)
          files << result
        end
      end
      
      return files
    end

    # Builds a Hash of child objects by analyzing the local filesystem. A
    # refresh is automatically performed when the CrackupDirectory object is
    # instantiated.
    def refresh_children
      @children = {}

      Dir.open(@name) do |dir|
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
            @children[filename.chomp('/')] = CrackupDirectory.new(filename)
          elsif File.file?(filename)
            @children[filename] = CrackupFile.new(filename)
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
