#!/usr/bin/env ruby

require 'lib/Crackup'
require 'optparse'

module Crackup
  APP_NAME      = 'Crackup'
  APP_VERSION   = '0.1-svn'
  APP_COPYRIGHT = 'Copyright (c) 2006 Ryan Grove (ryan@wonko.com). All rights reserved.'
  APP_URL       = 'http://wonko.com/software/crackup'
  
  @options = {
    :from       => ['.'],
    :passphrase => nil,
    :to         => nil,
    :verbose    => false
  }
  
  optparse = OptionParser.new do |optparse|
    optparse.summary_width  = 24
    optparse.summary_indent = '  '
    
    optparse.banner = 'Usage: crackup -t <url> [-p <pass>] [-v] [<file|dir> ...]'
    optparse.separator ''
    
    optparse.on '-p', '--passphrase <pass>',
        'Encryption passphrase (if not specified, no',
        'encryption will be used)' do |passphrase|
      @options[:passphrase] = passphrase
    end
    
    optparse.on '-t', '--to <url>',
        'Destination URL (e.g.,',
        'ftp://user:pass@server.com/path)' do |url|
      @options[:to] = url.chomp('/')
    end
    
    optparse.on '-v', '--verbose',
        'Verbose output' do
      @options[:verbose] = true
    end
    
    optparse.on_tail '-h', '--help',
        'Display usage information (this message)' do
      puts optparse
      exit
    end
    
    optparse.on_tail '--version',
        'Display version information' do
      puts "#{APP_NAME} v#{APP_VERSION} <#{APP_URL}>"
      puts "#{APP_COPYRIGHT}"
      puts
      puts "#{APP_NAME} comes with ABSOLUTELY NO WARRANTY."
      puts
      puts "This program is open source software distributed under the terms of"
      puts "the BSD License. For details, see the LICENSE file contained in the"
      puts "source distribution."
      exit
    end
  end
  
  # Parse command line options.
  begin
    optparse.parse!(ARGV)
  rescue => e
    abort("Error: #{e}")
  end
  
  # Add files to the "from" array.
  if ARGV.length
    @options[:from] = []
    
    while filename = ARGV.shift
      @options[:from] << filename
    end
  end
  
  # Load driver.
  @driver = CrackupDriver::get_driver(@options[:to])
  
  # Get the list of remote files and directories.
  debug 'Retrieving remote file list...'
  @remote_files = get_remote_files()
  
  # Build a list of local files and directories.
  debug 'Building local file list...'
  @local_files = get_local_files()
  
  # Determine differences.
  debug 'Determining differences...'  
  update = get_updated_files(@local_files, @remote_files)
  remove = get_removed_files(@local_files, @remote_files)

  # Remove files from the remote location if necessary.
  unless remove.empty?
    debug 'Removing stale files from remote location...'
    remove_files(remove)
  end
  
  # Update files at the remote location if necessary.
  unless update.empty?
    debug 'Updating remote location with new/changed files...'
    update_files(update)
  end
  
  # Update the remote file index if necessary.
  unless remove.empty? && update.empty?
    debug 'Updating remote index...'
    update_remote_index
  end
  
  debug 'Finished!'
end
