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
    
    # Searches all child files and directories for a file or directory with the
    # specified <em>filename</em>. Returns the file or directory if found, or
    # <em>nil</em> if not found.
    def find(filename)
      return @children[filename] if @children.has_key?(filename)
    
      @children.each do |name, child|
        next unless child.is_a?(CrackupDirectory)
        
        if result = child.find(filename)
          return result
        end
      end
      
      return nil
    end

    # Builds a SortedSet of child objects by analyzing the local filesystem. A
    # refresh is automatically performed when the CrackupDirectory object is
    # instantiated.
    def refresh_children
      @children = {}

      Dir.open(@name) do |dir|
        dir.each do |filename|
          next if filename == '.' || filename == '..'

          filename = File.join(dir.path, filename)

          if File.directory?(filename)
            @children[filename.chomp('/')] = CrackupDirectory.new(filename)
          elsif File.file?(filename)
            @children[filename] = CrackupFile.new(filename)
          end
        end
      end
    end

    # Removes the remote copies of this directory and all its children.
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
