#!/usr/bin/env ruby
#
# crackup-restore.rb - command-line tool for restoring files from Crackup
# backups. See <tt>crackup-restore -h</tt> for usage information.
#
# Author::    Ryan Grove (mailto:ryan@wonko.com)
# Version::   0.1-svn
# Copyright:: Copyright (c) 2006 Ryan Grove. All rights reserved.
# License::   New BSD License (http://opensource.org/licenses/bsd-license.php)
#

require 'lib/Crackup'
require 'optparse'

module Crackup
  APP_NAME      = 'crackup-restore'
  APP_VERSION   = '0.1-svn'
  APP_COPYRIGHT = 'Copyright (c) 2006 Ryan Grove (ryan@wonko.com). All rights reserved.'
  APP_URL       = 'http://wonko.com/software/crackup'
  
  @options = {
    :all        => false,
    :from       => nil,
    :only       => [],
    :passphrase => nil,
    :to         => nil,
    :verbose    => false
  }
  
  optparse = OptionParser.new do |optparse|
    optparse.summary_width  = 24
    optparse.summary_indent = '  '
    
    optparse.banner = 'Usage: crackup-restore -f <url> [-p <pass>] [-v] [<file|dir> ...]'
    optparse.separator ''
    
    optparse.on '-f', '--from <url>',
        'Remote URL to restore from (e.g.,',
        'ftp://user:pass@server.com/path)' do |url|
      @options[:from] = url.gsub("\\", '/').chomp('/')
    end
    
    optparse.on '-p', '--passphrase <pass>',
        'Encryption passphrase (if not specified, no',
        'encryption will be used)' do |passphrase|
      @options[:passphrase] = passphrase
    end
    
    optparse.on '-t', '--to <path>',
        'Destination root directory for the restored files' do |path|
      @options[:to] = path.chomp('/')
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
      puts "the New BSD License. For details, see the LICENSE file contained in"
      puts "the source distribution."
      exit
    end
  end
  
  # Parse command line options.
  begin
    optparse.parse!(ARGV)
  rescue => e
    abort("Error: #{e}")
  end
  
  # Add files to the "only" array.
  if ARGV.length > 0
    @options[:only] = []
    
    while filename = ARGV.shift
      @options[:only] << filename.chomp('/')
    end
  else
    @options[:all] = true
  end
  
  # Load driver.
  @driver = CrackupDriver::get_driver(@options[:from])
  
  # Get the list of remote files and directories.
  debug 'Retrieving remote file list...'
  @remote_files = get_remote_files(@options[:from])
  
  # Restore files.
  debug 'Restoring files...'

  if @options[:all]
    @remote_files.each_value {|file| file.restore(@options[:to]) }
  else
    @options[:only].each do |filename|
      unless file = find_remote_file(filename)
        error "Remote file not found: #{filename}"
      end
      
      file.restore(@options[:to])
    end
  end
  
  debug 'Finished!'
end
