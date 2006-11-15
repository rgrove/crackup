require 'sqlite3'
require 'yaml'

module Crackup

  # Represents a Crackup index database (essentially a friendly interface to an
  # SQLite3 database file).
  class Index
    include Enumerable
    
    attr_reader :db, :filename, :sql
    
    #--
    # Public Class Methods
    #++
    
    # Returns an instance of Crackup::Index representing the index at the
    # specified remote _url_, or a new index if the remote index doesn't exist.
    def self.get_remote_index(url)
      tempfile = Crackup.get_tempfile()
      
      # Download the index file.
      begin
        Crackup.driver.get(url, tempfile)
      rescue => e
        return Crackup::Index.new(tempfile)
      end
      
      # Decompress/decrypt the index file.
      oldfile  = tempfile
      tempfile = Crackup.get_tempfile()
      
      if Crackup.options[:passphrase].nil?
        begin
          Crackup.decompress_file(oldfile, tempfile)
        rescue => e
          raise Crackup::IndexError, "Unable to decompress index file. Maybe " +
              "it's encrypted?"
        end
      else
        begin
          Crackup.decrypt_file(oldfile, tempfile)
        rescue => e
          raise Crackup::IndexError, "Unable to decrypt index file."
        end
      end
      
      return Index.new(tempfile)
    end
    
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
        open(filename)

        # Create tables if they don't already exist.
        @db.transaction do |db|
          db.execute(@sql['dirs']['create'])
          db.execute(@sql['files']['create'])
        end
      rescue => e
        raise Crackup::IndexError, "Unable to open index database: #{e}"
      end
    end
    
    #--
    # Public Instance Methods
    #++
    
    # Gets a Crackup::FileSystemObject representing the file or directory
    # specified by _path_, or +nil+ if _path_ does not exist in the index. 
    def [](path)
      if has_dir?(path)
        row = @db.get_first_row(@sql['dirs']['get_by_path'], ':path' => path)
        return Crackup::DirectoryObject.from_db(row, get_children(row['path']))
      elsif has_file?(path)
        row = @db.get_first_row(@sql['files']['get_by_path'], ':path' => path)
        return Crackup::FileObject.from_db(row)
      end
      
      return nil
      
    rescue => e
      raise Crackup::IndexError, e
    end
    
    # Adds _fsobject_ to the index (or replaces it if it already exists).
    def []=(path, fsobject)
      unless fsobject.is_a?(Crackup::FileSystemObject)
        raise ArgumentError, "Expected Crackup::FileSystemObject, got " +
            "#{fsobject.class}"
      end
    
      if fsobject.is_a?(Crackup::DirectoryObject)
        if has_dir?(path)
          @db.execute(@sql['dirs']['update'],
              fsobject.get_index_params(:update))
        elsif has_file?(path)
          # The previously-existing file has been replaced by a directory at the
          # same path, so we need to get rid of the old file.
          @db.transaction do |db|
            db.execute(@sql['files']['delete'],
                fsobject.get_index_params(:delete))
            
            # Now add the new directory.
            db.execute(@sql['dirs']['add'], fsobject.get_index_params(:add))
          end
        else
          @db.execute(@sql['dirs']['add'], fsobject.get_index_params(:add))
        end
      elsif fsobject.is_a?(Crackup::FileObject)
        if has_dir?(path)
          # The previously-existing directory has been replaced by a file at the
          # same path, so we need to get rid of the old directory.
          @db.transaction do |db|
            db.execute(@sql['dirs']['delete'],
                fsobject.get_index_params(:delete))
            db.execute(@sql['files']['delete_by_dir_path'],
                fsobject.get_index_params(:delete_by_dir_path))
            
            # Now add the new file.
            db.execute(@sql['files']['add'], fsobject.get_index_params(:add))
          end
        elsif has_file?(path)
          @db.execute(@sql['files']['update'],
              fsobject.get_index_params(:update))
        else
          @db.execute(@sql['files']['add'], fsobject.get_index_params(:add))
        end
      end
    
    rescue => e
      raise Crackup::IndexError, e
    end
    
    # Calls _block_ once for each element in _self_, passing that element as a
    # parameter.
    def each
      @db.execute(@sql['dirs']['get_all']) do |row|
        yield Crackup::DirectoryObject.from_db(row, get_children(row[':path']))
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
    
      @db.execute(@sql['dirs']['get_by_parent'],
          ':parent_path' => path) do |row|
        children[row['path']] = Crackup::DirectoryObject.from_db(row,
            get_children(row['path']))
      end
      
      @db.execute(@sql['files']['get_by_dir'], ':dir_path' => path) do |row|
        children[row['path']] = Crackup::FileObject.from_db(row)
      end
      
      return children
      
    rescue => e
      raise Crackup::IndexError, e
    end
    
    # Returns +true+ if the index contains a directory whose path matches
    # _path_, +false+ if it does not.
    def has_dir?(path)
      return '1' == @db.get_first_value(@sql['dirs']['has_dir?'], 
          ':path' => path)
    
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
    
    # Compresses/encrypts the index and uploads it to the specified remote
    # _url_.
    def upload(url)
      @db.close()
      
      # Compress/encrypt the index database.
      tempfile = Crackup.get_tempfile()
      
      if Crackup.options[:passphrase].nil?
        Crackup.compress_file(@filename, tempfile)
      else
        Crackup.encrypt_file(@filename, tempfile)
      end
      
      begin
        Crackup.driver.put(url, tempfile)
      rescue => e
        retry if prompt('Unable to update remote index. Try again? (y/n)').
            downcase == 'y'
        raise Crackup::IndexError, "Unable to update remote index: #{e}"
      end
    end

    #--
    # Private Instance Methods
    #++

    private
    
    # Opens a database connection to _filename_.
    def open(filename)
      @db.close() if @db.is_a?(SQLite3::Database)
      @db = SQLite3::Database.new(@filename, {:results_as_hash  => true})
    
    rescue => e
      raise Crackup::IndexError, "Unable to open index database: #{e}"
    end
  end

end
