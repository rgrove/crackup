require 'net/ftp'
require 'uri'

module Crackup

  # FTP storage driver for Crackup.
  # 
  # Author::    Ryan Grove (mailto:ryan@wonko.com)
  # Copyright:: Copyright (c) 2006 Ryan Grove. All rights reserved.
  # License::   New BSD License (http://opensource.org/licenses/bsd-license.php)
  # 
  class CrackupDriverFtp < CrackupDriver
  
    # Connects to the FTP server specified in <em>url</em>.
    def initialize(url)
      super(url)
      
      # Parse URL.
      begin
        uri = URI::parse(url)
      rescue => e
        raise CrackupStorageError, "Invalid URL: #{url}: #{e}"
      end
      
      @ftp = Net::FTP.new
      @ftp.passive = true

      begin
        @ftp.connect(uri.host, uri.port.nil? ? 21 : uri.port)
      rescue => e
        raise CrackupStorageError, "FTP connect failed: #{e}"
      end
      
      begin
        @ftp.login(uri.user.nil? ? 'anonymous' : uri.user, uri.password)
      rescue => e
        raise CrackupStorageError, "FTP login failed: #{e}"
      end
    end

    # Deletes the file at the specified <em>url</em>.
    def delete(url)
      @ftp.delete(get_path(url))
      return true
      
    rescue => e
      raise CrackupStorageError, "Unable to delete #{url}: #{e}"
    end
    
    # Downloads the file at <em>url</em> to <em>local_filename</em>.
    def get(url, local_filename)
      @ftp.getbinaryfile(get_path(url), local_filename)
      return true
    
    rescue => e
      raise CrackupStorageError, "Unable to download #{url}: #{e}"
    end
    
    # Uploads the file at <em>local_filename</em> to <em>url</em>.
    def put(url, local_filename)
      @ftp.putbinaryfile(local_filename, get_path(url))
      return true
      
    rescue => e
      raise CrackupStorageError, "Unable to upload #{url}: #{e}"
    end
  end
end
