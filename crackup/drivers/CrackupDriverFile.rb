require 'fileutils'

module Crackup
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
    
    private
    
    def get_path(url)
      uri  = URI::parse(url)
      path = ''
      
      unless uri.host.nil?
        path = "#{uri.host}:"
      end
      
      return path += uri.path
      
      rescue URI::InvalidURIError => e
        abort "Invalid URL: #{url}"
    end
  end
end
