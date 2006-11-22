require 'rubygems'
require 'crackup'
require 'net/ssh'
require 'net/sftp'
require 'uri'

module Crackup; module Driver

  # SFTP storage driver for Crackup
  #
  # Author::    Brett Stimmerman (mailto:brettstimmerman@gmail.com)
  # Version::   1.0.0
  # Copyright:: Copyright (c) 2006 Brett Stimmerman. All rights reserved.
  # License::   New BSD License (http://opensource.org/licenses/bsd-license.php)
  #
  class SftpDriver
    include Driver
    
    # Connects to the SFTP server specified in _url_.
    def initialize(url)
      super(url)
      
      # Parse URL.
      begin
        uri = URI::parse(url)
      rescue => e
        raise Crackup::StorageError, "Invalid URL: #{url}: #{e}"
      end
      
      Crackup::debug 'Connecting...'
      
      begin
        @ssh  = Net::SSH::Session.new(uri.host, uri.port.nil? ? 22 : uri.port, 
            uri.user, uri.password)
          
        at_exit do
          begin
            @ssh.close
          rescue => e
          end
        end
      rescue => e
        raise Crackup::StorageError, "SSH login failed: #{e}"
      end
      
      begin
        @sftp = Net::SFTP::Session.new(@ssh)
        @sftp.connect
      rescue => e
        raise Crackup::StorageError, "SFTP connection failed: #{e}"
      end
    end
    
    # Deletes the file at the specified _url_.
    def delete(url)
      @sftp.remove("." + get_path(url))
      return true
    rescue => e
        raise Crackup::StorageError, "Unable to delete #{url}: #{e}"
    end
    
    # Downloads the file at _url_ to _local_filename_.
    def get(url, local_filename)
      @sftp.get_file("." + get_path(url), local_filename)
      return true
    rescue => e
      raise Crackup::StorageError, "Unable to download #{url}: #{e.message}"
    end
    
    # Uploads the file at _local_filename_ to _url_.
    def put(url, local_filename)
      @sftp.put_file(local_filename, "." + get_path(url))
      return true
    rescue => e
      raise Crackup::StorageError, "Unable to upload #{url}: #{e.message}"
    end
  end

end; end