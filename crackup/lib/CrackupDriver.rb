require 'uri'

module Crackup

  # Base storage driver class for Crackup.
  class CrackupDriver
    attr_reader :url
    
    # Gets an instance of the appropriate storage driver to handle the specified
    # <em>url</em>. If no suitable driver is found, raises an error of type
    # StandardError.
    def self.get_driver(url)
      begin
        uri = URI::parse(url)
      rescue => e
        abort("Invalid URL: #{url}")
      end
      
      # Use the filesystem driver if no scheme is specified or if the scheme is
      # a single letter (which indicates a Windows drive letter).
      if uri.scheme.nil? || uri.scheme =~ /^[a-z]$/i
        scheme = 'File'
      else
        scheme = uri.scheme.capitalize
      end
      
      driver_class = "CrackupDriver#{scheme}"
      driver_file  = File.dirname(__FILE__) + "/../drivers/#{driver_class}.rb"
      
      # Load the driver.
      unless require(driver_file)
        raise StandardError, "Driver not found: #{uri.scheme}"
      end
      
      return Crackup::const_get(driver_class).new(url)
    end
    
    def initialize(url)
      @url = url
    end
    
    def delete(url)
      return false
    end
    
    def get(url, local_filename)
      return false
    end
    
    def put(url, local_filename)
      return false
    end
  end
end
