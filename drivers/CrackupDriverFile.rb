require 'fileutils'

module Crackup

  # Filesystem storage driver for Crackup.
  # 
  # Author::    Ryan Grove (mailto:ryan@wonko.com)
  # Copyright:: Copyright (c) 2006 Ryan Grove. All rights reserved.
  # License::   New BSD License (http://opensource.org/licenses/bsd-license.php)
  # 
  class CrackupDriverFile < CrackupDriver
    def delete(url)
      File.delete(get_path(url))
      return true
    end
    
    def get(url, local_filename)
      FileUtils::copy(get_path(url), local_filename)
      return true
    end
    
    def put(url, local_filename)
      FileUtils::copy(local_filename, get_path(url))
      return true
    end
    
    #private
    
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
      
      rescue URI::InvalidURIError => e
        Crackup::error "Invalid URL: #{url}"
    end
  end
end
