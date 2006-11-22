require 'uri'

module Crackup

  # Base storage driver module for Crackup.
  # 
  # To write a Crackup storage driver:
  # 
  # - Create a class in Crackup::Driver named "FooDriver", where "Foo" is the
  #   capitalized version of the URI scheme your driver will handle (e.g.,
  #   "Ftp", "Sftp", etc.).
  # - In your class, mixin the Crackup::Driver module and override at least the
  #   delete, get, and put methods.
  # - Package your driver as a gem named "crackup-foo" (where "foo" is the
  #   lowercase version of the URI scheme your driver will handle).
  #   
  # That's all there is to it. See Crackup::Driver::FileDriver and
  # Crackup::Driver::FtpDriver for examples.
  module Driver
    attr_reader :url
    
    # Gets an instance of the appropriate storage driver to handle the specified
    # _url_. If no suitable driver is found, raises a Crackup::StorageError.
    def self.get_driver(url)
      begin
        uri = URI::parse(url)
      rescue => e
        raise Crackup::StorageError, "Invalid URL: #{url}: #{e}"
      end
      
      # Use the filesystem driver if no scheme is specified or if the scheme is
      # a single letter (which indicates a Windows drive letter).
      if uri.scheme.nil? || uri.scheme =~ /^[a-z]$/i
        scheme = 'file'
      else
        scheme = uri.scheme.downcase
      end
      
      # Load the driver.
      require "crackup-#{scheme}"
      
      begin
        return const_get("#{scheme.capitalize}Driver").new(url)
      rescue => e
        raise Crackup::StorageError,
            "Unable to load storage driver for scheme '#{scheme}'"
      end
    end
    
    def initialize(url)
      @url = url
    end
    
    # Deletes the file at the specified _url_. This method does nothing and is
    # intended to be overridden by a driver class.
    def delete(url)
      return false
    end
    
    # Downloads the file at _url_ to <em>local_filename</em>. This method does
    # nothing and is intended to be overridden by a driver class.
    def get(url, local_filename)
      return false
    end
    
    # Gets the path portion of _url_.
    def get_path(url)
      uri = URI::parse(url)
      return uri.path

    rescue => e
      raise Crackup::StorageError, "Invalid URL: #{url}: #{e}"
    end
      
    # Uploads the file at <em>local_filename</em> to _url_. This method does
    # nothing and is intended to be overridden by a driver class.
    def put(url, local_filename)
      return false
    end
  end

end
