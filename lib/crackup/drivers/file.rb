require 'crackup/driver'
require 'fileutils'
require 'uri'

module Crackup; module Driver

  # Filesystem storage driver for Crackup.
  # 
  # Author::    Ryan Grove (mailto:ryan@wonko.com)
  # Copyright:: Copyright (c) 2006 Ryan Grove. All rights reserved.
  # License::   New BSD License (http://opensource.org/licenses/bsd-license.php)
  # 
  class FileDriver
    include Driver
  
    # Deletes the file at the specified <em>url</em>.
    def delete(url)
      File.delete(get_path(url))
      return true
      
    rescue => e
      raise Crackup::StorageError, "Unable to delete #{url}: #{e}"
    end
    
    # Downloads the file at <em>url</em> to <em>local_filename</em>.
    def get(url, local_filename)
      FileUtils::copy(get_path(url), local_filename)
      return true
    
    rescue => e
      raise Crackup::StorageError, "Unable to get #{url}: #{e}"
    end
    
    # Gets the filesystem path represented by <em>url</em>. This method is
    # capable of parsing URLs in any of the following formats:
    # 
    # - file:///foo/bar
    # - file://c:/foo/bar
    # - c:/foo/bar
    # - /foo/bar
    # - //smbhost/foo/bar
    def get_path(url)
      uri  = URI::parse(url)
      path = ''
      
      if uri.scheme =~ /^[a-z]$/i
        # Windows drive letter.
        path = uri.scheme + ':'
      elsif uri.host =~ /^[a-z]$/i
        # Windows drive letter.
        path = uri.host + ':'
      elsif uri.scheme.nil? && !uri.host.nil?
        # SMB share.
        path = '//' + uri.host
      end
      
      return path += uri.path
      
    rescue => e
      raise Crackup::StorageError, "Invalid URL: #{url}"
    end
    
    # Uploads the file at <em>local_filename</em> to <em>url</em>.
    def put(url, local_filename)
      FileUtils::copy(local_filename, get_path(url))
      return true
      
    rescue => e
      raise Crackup::StorageError, "Unable to put #{url}: #{e}"
    end
  end

end; end
