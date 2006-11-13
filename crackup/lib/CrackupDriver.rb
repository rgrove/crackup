require 'uri'

module Crackup
  class CrackupDriver
    attr_reader :url
    
    # -- Static Methods --------------------------------------------------------
    def self.get_driver(url)
      begin
        uri = URI::parse(url)
      rescue => e
        abort("Invalid URL: #{url}")
      end
      
      driver_class = "CrackupDriver#{uri.scheme.capitalize}"
      driver_file  = File.dirname(__FILE__) + "/../drivers/#{driver_class}.rb"
      
      # Load the driver.
      unless require(driver_file)
        raise StandardError, "Driver not found: #{uri.scheme}"
      end
      
      return Crackup::const_get(driver_class).new(url)
    end
    
    # -- Instance Methods ------------------------------------------------------
    def initialize(url)
      @url = url
    end
    
    # -- Abstract Instance Methods ---------------------------------------------
    def delete(url)
    end
    
    def get(url, local_filename)
    end
    
    def put(url, local_filename)
    end
  end
end
