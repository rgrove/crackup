require 'sqlite3'
require 'yaml'

module Crackup

  # Represents a Crackup index database (essentially a friendly interface to an
  # SQLite3 database file).
  class Index
    include Enumerable
    
    attr_reader :db, :filename, :sql
    
    # Opens _filename_ as a Crackup index database. If the file doesn't exist,
    # a new database will be created.
    def initialize(filename)
      @filename = filename
    
      # Load SQL queries.
      begin
        @sql = YAML.load_file("#{File.dirname(__FILE__)}/db/sql.yaml")
      rescue => e
        raise Crackup::IndexError, "Unable to load database query file: #{e}"
      end
      
      # Open database.
      begin
        @db = SQLite3::Database.new(@filename, {:results_as_hash  => true})

        # Create tables if they don't already exist.
        @db.transaction do |db|
          db.execute(@sql['chunks']['create'])
          db.execute(@sql['dirs']['create'])
          db.execute(@sql['files']['create'])
        end
      rescue => e
        raise Crackup::IndexError, "Unable to open index database: #{e}"
      end
    end
    
    # Gets a Crackup::FileSystemObject representing the file or directory
    # specified by _path_, or +nil+ if _path_ does not exist in the index. 
    def [](path)
      if has_dir?(path)
        row = @db.get_first_row(@sql['dirs']['get_by_path'], 'path' => path)
        return Crackup::DirObject.from_db(row, get_children(row['path']))
      elsif has_file?(path)
        row = @db.get_first_row(@sql['files']['get_by_path'], 'path' => path)
        return Crackup::FileObject.from_db(row)
      end
      
      return nil
      
    rescue => e
      raise Crackup::IndexError, e
    end
    
    # Calls _block_ once for each element in _self_, passing that element as a
    # parameter.
    def each
      @db.execute(@sql['dirs']['get_all']) do |row|
        yield Crackup::DirectoryObject.from_db(row, get_children(row['path']))
      end
      
      @db.execute(@sql['files']['get_all']) do |row|
        yield Crackup::FileObject.from_db(row)
      end
      
    rescue => e
      raise Crackup::IndexError, e
    end
    
    # Returns a Hash of Crackup::FileSystemObjects representing the children of
    # the directory with the specified <em>path</em>, or +nil+ if the directory
    # cannot be found.
    def get_children(path)
      children = {}
    
      @db.execute(@sql['dirs']['get_by_parent'], 'parent_path' => path) do |row|
        children[row['path']] = Crackup::DirectoryObject.from_db(row,
            get_children(row['path']))
      end
      
      @db.execute(@sql['files']['get_by_dir'], 'dir_path' => path) do |row|
        children[row['path']] = Crackup::FileObject.from_db(row)
      end
      
      return children
      
    rescue => e
      raise Crackup::IndexError, e
    end
    
    # Returns +true+ if the index contains a directory whose path matches
    # _path_, +false+ if it does not.
    def has_dir?(path)
      return '1' == @db.get_first_value(@sql['dirs']['has_dir?'], ':path' => path)
    
    rescue => e
      raise Crackup::IndexError, "Database query failed: #{e}"
    end
    
    # Returns +true+ if the index contains a file whose path matches _path_,
    # +false+ if it does not.
    def has_file?(path)
      return '1' == @db.get_first_value(@sql['files']['has_file?'], 
          ':path' => path)
      
    rescue => e
      raise Crackup::IndexError, "Database query failed: #{e}"
    end

    # Returns +true+ if the index contains a file or directory whose path
    # matches _path_, +false+ if it does not.
    def has_key?(path)
      return has_dir?(path) || has_file?(path)
    end
    
  end

end
