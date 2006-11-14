require 'uri'

module Crackup

  # Base storage driver class for Crackup.
  # 
  # To write a Crackup storage driver, create a class named "CrackupDriverFoo"
  # where "Foo" is the URI scheme (e.g., "ftp", "sftp", etc.) and place your
  # class in Crackup's <tt>lib/drivers</tt> directory. Your class must inherit
  # CrackupDriver and should override at least the delete, get, and put
  # methods.
  # 
  # See CrackupDriverFile and CrackupDriverFtp for examples.
  class CrackupDriver
    attr_reader :url
    
    # Gets an instance of the appropriate storage driver to handle the specified
    # <em>url</em>. If no suitable driver is found, raises an error of type
    # CrackupStorageError.
    def self.get_driver(url)
      begin
        uri = URI::parse(url)
      rescue => e
        raise CrackupStorageError, "Invalid URL: #{url}: #{e}"
      end
      
      # Use the filesystem driver if no scheme is specified or if the scheme is
      # a single letter (which indicates a Windows drive letter).
      if uri.scheme.nil? || uri.scheme =~ /^[a-z]$/i
        scheme = 'File'
      else
        scheme = uri.scheme.capitalize
      end
      
      driver_class = "CrackupDriver#{scheme}"
      driver_file  = File.dirname(__FILE__) + "/drivers/#{driver_class}.rb"
      
      # Load the driver.
      unless require(driver_file)
        raise CrackupStorageError, "Driver not found: #{uri.scheme}"
      end
      
      return Crackup::const_get(driver_class).new(url)
    end
    
    def initialize(url)
      @url = url
    end
    
    # Deletes the file at the specified <em>url</em>. This method does nothing
    # and is intended to be overridden by an inheriting driver class.
    def delete(url)
      return false
    end
    
    # Downloads the file at <em>url</em> to <em>local_filename</em>. This method
    # does nothing and is intended to be overridden by an inheriting driver
    # class.
    def get(url, local_filename)
      return false
    end
    
    # Gets the path portion of <em>url</em>.
    def get_path(url)
      uri = URI::parse(url)
      return uri.path

    rescue => e
      raise CrackupStorageError, "Invalid URL: #{url}: #{e}"
    end
      
    # Uploads the file at <em>local_filename</em> to <em>url</em>. This method
    # does nothing and is intended to be overridden by an inheriting driver
    # class.
    def put(url, local_filename)
      return false
    end
  end
end
