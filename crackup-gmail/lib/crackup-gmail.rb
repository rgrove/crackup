require 'rubygems'
require 'crackup'
require 'gmailer'
require 'uri'

module Crackup; module Driver

  # GMail storage driver for Crackup.
  #
  #  gmail://<username>:<password>@gmail.com/<label>
  #
  # Author::    Brett Stimmerman (mailto:brettstimmerman@gmail.com)
  # Version::   1.0.0
  # Copyright:: Copyright (c) 2006 Brett Stimmerman. All rights reserved.
  # License::   New BSD License (http://opensource.org/licenses/bsd-license.php)
  #
  class GmailDriver
    include Driver

    # Connects to the GMail account specified in _url_.
    def initialize(url)
      super(url)

      # Parse URL.
      begin
        uri = URI::parse(url)
      rescue => e
        raise Crackup::StorageError, "Invalid URL: #{url}: #{e}"
      end

      if uri.user.nil?
        raise Crackup::StorageError, 'GMail username not specified.'
      end

      if uri.password.nil?
        raise Crackup::StorageError, 'GMail password not specified.'
      end

      Crackup::debug 'Connecting to GMail...'

      begin
        @gmail = GMailer.connect(uri.user, uri.password)

        # Load messages for the given label, or create the label if it doesn't
        # exist.
        @messages = {}
        label     = get_label(url)

        if @gmail.labels.include?(label)
          @messages = load_messages(label)
        else
          @gmail.create_label(label)
        end

       rescue => e
        raise Crackup::StorageError, "Unable to initialize connection: #{e}"
      end
    end

    # Deletes the file at the specified _url_.
    def delete(url)
      message_id = get_message_id(url)

      unless message_id
        return false
      end

      @gmail.trash(message_id)

      return true
    rescue => e
        raise Crackup::StorageError, "Unable to delete #{url}: #{e}"
    end

    # Downloads the file at _url_ to _local_filename_.
    def get(url, local_filename)
      @gmail.attachment(get_attachment_id(url), get_message_id(url),
          local_filename)

      return true
    rescue => e
      raise Crackup::StorageError, "Unable to download #{url}: #{e}"
    end

    # Get the attachment id for _url_.
    def get_attachment_id(url)
      return get_message(url) {|msg| return msg.attachment[0].id }
    end

    # Gets the key portion of _url_.
    def get_key(url)
      begin
        uri = URI.parse(url)
      rescue => e
        raise Crackup::StorageError, "Invalid URL: #{url}: #{e}"
      end

      unless uri.path =~ /^\/(?:.+?)\/(.+)\/?$/
        raise Crackup::StorageError, "Invalid URL: #{url}: invalid key"
      end

      return '[' + get_label(url) '] ' + $1
    end

    # Gets the label portion of _url_.
    def get_label(url)
      begin
        uri = URI.parse(url)
      rescue => e
        raise Crackup::StorageError, "Invalid URL: #{url}: #{e}"
      end

      unless uri.path =~ /^\/(.+?)(?:\/.+)?$/
        raise Crackup::StorageError, "Invalid URL: #{url}: invalid label name"
      end

      return $1
    end

    # Get the message for _url_ if it exists.  If the message exists, it is
    # passed to _block_ and its return value is used. Otherwise returns _false_.
    def get_message(url, &block)
      key = get_key(url)

      unless @messages.has_key?(key)
        return false
      end

      return block.call(@messages[key])
    end

    # Get the message id for _url_.
    def get_message_id(url)
      return get_message(url) {|msg| return msg.id }
    end

    # Get the To: address for _url_.
    def get_to_address(url)
       begin
        uri = URI.parse(url)
      rescue => e
        raise Crackup::StorageError, "Invalid URL: #{url}: #{e}"
      end

      return uri.user + '+' + get_label(url) + '@gmail.com'
    end

    # Retrieve all backup messages labeled with _label_.  Because there's no
    # easy way to request a single message using the GMail 'API'.
    def load_messages(label)
      begin
        messages = {}

        @gmail.messages(:label => label) do |ml|
          if ml.total > 0
            ml.each_msg {|msg| messages[msg.conv[0].subject] = msg.conv[0] }
          end
        end

        return messages

      rescue => e
        raise Crackup::StorageError, "Unable to load messages: #{e}"
      end
    end

    # Uploads the file at _local_filename_ to _url_.
    def put(url, local_filename)

      file_size = File.size(local_filename)

      # GMail has a 10MB attachment limit
      if file_size > 10485760
        raise Crackup::StorageError, 'File is larger than 10MB limit: ' +
          file_size + ' bytes'
      end

      # Remove an existing message
      delete(url)

      # Send the new message
      @gmail.send(
        :to      => get_to_address(url),
        :subject => get_key(url),
        :files   => [local_filename])

      return true

    rescue => e
      raise Crackup::StorageError, "Unable to upload #{url}: #{e}"
    end
  end

end; end