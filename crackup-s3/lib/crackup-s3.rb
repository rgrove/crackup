require 'rubygems'
require 'crackup'
require 'S33r'
require 'uri'

module Crackup; module Driver

  # Amazon S3 storage driver for Crackup. Use the following format for S3 URLs:
  # 
  #   s3://<public access key>:<secret access key>@s3.amazonaws.com/<bucket>
  # 
  # If the specified storage bucket does not exist, the driver will attempt to
  # create it.
  # 
  # Author::    Ryan Grove (mailto:ryan@wonko.com)
  # Version::   1.0.0
  # Copyright:: Copyright (c) 2006 Ryan Grove. All rights reserved.
  # License::   New BSD License (http://opensource.org/licenses/bsd-license.php)
  # 
  class S3Driver
    include Driver
  
    # Creates a s33r client instance.
    def initialize(url)
      super(url)
      
      # Parse URL.
      begin
        uri = URI::parse(url)
      rescue => e
        raise Crackup::StorageError, "Invalid URL: #{url}: #{e}"
      end
      
      if uri.user.nil?
        raise Crackup::StorageError,
            'Amazon S3 public access key not specified.'
      end
      
      if uri.password.nil?
        raise Crackup::StorageError,
            'Amazon S3 secret access key not specified.'
      end
      
      begin
        @s3 = S33r::Client.new(uri.user, uri.password, :use_ssl => true,
            :dump_requests => false)
        
        # Create the bucket if it doesn't exist.
        bucket_name = get_bucket(url)        
        @s3.create_bucket(bucket_name) unless @s3.bucket_exists?(bucket_name)
        
        # Open the bucket.
        @bucket = S33r::NamedBucket.new(uri.user, uri.password,
            :default_bucket  => get_bucket(url),
            :public_contents => false)
      rescue => e
        raise Crackup::StorageError, "Unable to initialize S3 client: #{e}"
      end
    end

    # Deletes the file at the specified _url_.
    def delete(url)
      @s3.delete_resource(get_bucket(url), get_key(url))
      return true
      
    rescue => e
      raise Crackup::StorageError, "Unable to delete #{url}: #{e}"
    end
    
    # Downloads the file at _url_ to _local_filename_.
    def get(url, local_filename)
      key = get_key(url)
    
      # Get the data (let's hope it's not too big to fit in RAM).
      unless @bucket.key_exists?(key) && data = @bucket[key] 
        raise Crackup::StorageError, "Unable to download #{url}: key not found"
      end

      # Write the data to local_filename.
      File.open(local_filename, 'wb') {|file| file.write(data) }
      return true
    
    rescue => e
      raise Crackup::StorageError, "Unable to download #{url}: #{e}"
    end
    
    # Parses _url_ and returns the name of the S3 bucket to which it refers.
    def get_bucket(url)
      begin
        uri = URI.parse(url)
      rescue => e
        raise Crackup::StorageError, "Invalid URL: #{url}: #{e}"
      end
      
      unless uri.path =~ /^\/(.+?)(?:\/.+)?$/
        raise Crackup::StorageError, "Invalid URL: #{url}: invalid bucket name"
      end
      
      return $1
    end
    
    # Parses _url_ and returns the name of the S3 key to which it refers.
    def get_key(url)
      begin
        uri = URI.parse(url)
      rescue => e
        raise Crackup::StorageError, "Invalid URL: #{url}: #{e}"
      end
      
      unless uri.path =~ /^\/(?:.+?)\/(.+?)\/?$/
        raise Crackup::StorageError, "Invalid URL: #{url}: invalid key"
      end
      
      return $1
    end
    
    # Uploads the file at _local_filename_ to _url_.
    def put(url, local_filename)
      @bucket.put_file(local_filename, get_key(url))
      return true
      
    rescue => e
      raise Crackup::StorageError, "Unable to upload #{url}: #{e}"
    end
  end

end; end
