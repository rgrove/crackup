require 'net/ftp'
require 'uri'

module Crackup; module Driver

  # FTP storage driver for Crackup.
  # 
  # Author::    Ryan Grove (mailto:ryan@wonko.com)
  # Version::   1.0.2
  # Copyright:: Copyright (c) 2006 Ryan Grove. All rights reserved.
  # License::   New BSD License (http://opensource.org/licenses/bsd-license.php)
  # 
  class FtpDriver
    include Driver
  
    # Connects to the FTP server specified in _url_.
    def initialize(url)
      super(url)
      
      # Parse URL.
      begin
        uri = URI::parse(url)
      rescue => e
        raise Crackup::StorageError, "Invalid URL: #{url}: #{e}"
      end
      
      @ftp = Net::FTP.new
      @ftp.passive = true

      begin
        @ftp.connect(uri.host, uri.port.nil? ? 21 : uri.port)
      rescue => e
        raise Crackup::StorageError, "FTP connect failed: #{e}"
      end
      
      at_exit { @ftp.close }
      
      begin
        @ftp.login(uri.user.nil? ? 'anonymous' : uri.user, uri.password)
      rescue => e
        raise Crackup::StorageError, "FTP login failed: #{e}"
      end
    end

    # Deletes the file at the specified _url_.
    def delete(url)
      @ftp.delete(get_path(url))
      return true
      
    rescue => e
      raise Crackup::StorageError, "Unable to delete #{url}: #{e}"
    end
    
    # Downloads the file at _url_ to _local_filename_.
    def get(url, local_filename)
      @ftp.getbinaryfile(get_path(url), local_filename)
      return true
    
    rescue => e
      raise Crackup::StorageError, "Unable to download #{url}: #{e}"
    end
    
    # Uploads the file at _local_filename_ to _url_.
    def put(url, local_filename)
      @ftp.putbinaryfile(local_filename, get_path(url))
      return true
      
    rescue => e
      raise Crackup::StorageError, "Unable to upload #{url}: #{e}"
    end
  end

end; end
