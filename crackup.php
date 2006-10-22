#!/usr/local/bin/php
<?php
/**
 * Crackup (Crappy Remote Backup) is a pretty simple, pretty secure remote
 * backup solution for folks who want to keep their data securely backed up but
 * aren't particularly concerned about bandwidth usage.
 * 
 * Crackup is ideal for backing up lots of small files, but somewhat less ideal
 * for backing up large files, since any change to a file means the entire file
 * must be transferred. If you need something bandwidth-efficient, try Duplicity
 * or Brackup.
 * 
 * Backups are compressed and encrypted via GPG and can be transferred to the
 * remote location over a variety of protocols, including FTP, FTPS, and SFTP.
 *
 * Requires PHP 5.1.6+ and GPG 1.4.2+
 * 
 * Requires the following PEAR packages:
 *   - Console_Getargs
 * 
 * @author    Ryan Grove <ryan@wonko.com>
 * @version   0.1-svn
 * @copyright Copyright &copy; 2006 Ryan Grove. All rights reserved.
 * @license   http://opensource.org/licenses/bsd-license.php BSD License
 * @package   Crackup
 */

require_once 'Console/Getargs.php';
require_once 'classes/Crackup.php';
require_once 'classes/CrackupFileSystemObject.php';
require_once 'classes/CrackupDirectory.php';
require_once 'classes/CrackupFile.php';

// -- Constants ----------------------------------------------------------------

define('APP_NAME', 'Crackup');
define('APP_VERSION', '0.1-svn');
define('APP_COPYRIGHT', 'Copyright (c) 2006 Ryan Grove (ryan@wonko.com). All rights reserved.');
define('APP_URL', 'http://wonko.com/software/crackup');

define('GPG_DECRYPT', 'echo :passphrase | gpg --batch --quiet --no-tty --no-secmem-warning --cipher-algo aes256 --compress-algo bzip2 --passphrase-fd 0 --output :output_file :input_file');
define('GPG_ENCRYPT', 'echo :passphrase | gpg --batch --quiet --no-tty --no-secmem-warning --cipher-algo aes256 --compress-algo bzip2 --passphrase-fd 0 --output :output_file --symmetric :input_file');

define('TEMP_DIR', (isset($_ENV['TMP']) ? rtrim($_ENV['TMP'], '/') : '.'));

// -- Command-line arguments ---------------------------------------------------
$argConfig = array(
  'from' => array(
    'short' => 'f',
    'max'   => -1,
    'min'   => 1,
    'desc'  => 'Local files/directories to back up (wildcards are allowed)'
  ),
  
  'passphrase|pass|password' => array(
    'short'   => 'p',
    'max'     => 1,
    'min'     => 1,
    'desc'    => 'Encryption passphrase (if not specified, no encryption will '.
        'be used)',
    'default' => ''
  ),
  
	'to' => array(
    'short' => 't',
    'max'   => 1,
    'min'   => 1,
    'desc'  => 'Destination URL (e.g., ftp://user:pass@server.com/path)'
  ),

  'verbose' => array(
    'short' => 'v',
    'max'   => 0,
    'desc'  => 'Verbose output'
  ),
  
  'version' => array(
    'max'  => 0,
    'desc' => 'Display version number'
  ),
);

$args = Console_Getargs::factory($argConfig);

if (PEAR::isError($args)) {
  if ($args->getCode() === CONSOLE_GETARGS_ERROR_USER) {
    echo Console_Getargs::getHelp($argConfig, null, $args->getMessage(), 78, 2);
  }
  else if ($args->getCode() === CONSOLE_GETARGS_HELP) {
    echo Console_Getargs::getHelp($argConfig, null, null, 78, 2);
  }
  
  exit(1);
}

if ($args->isDefined('version')) {
  echo APP_NAME." v".APP_VERSION."\n";
  echo APP_COPYRIGHT."\n";
  echo "<".APP_URL.">\n\n";
  
  echo "Redistribution and use in source and binary forms, with or without\n".
       "modification, are permitted provided that the following conditions\n".
       "are met:\n\n".
       "  * Redistributions of source code must retain the above copyright\n".
       "    notice, this list of conditions and the following disclaimer.\n".
       "  * Redistributions in binary form must reproduce the above\n".
       "    copyright notice, this list of conditions and the following\n".
       "    disclaimer in the documentation and/or other materials provided\n".
       "    with the distribution.\n\n".
       "THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS\n".
       "\"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT\n".
       "LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS\n".
       "FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE\n".
       "COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,\n".
       "INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,\n".
       "BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;\n".
       "LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER\n".
       "CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT\n".
       "LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN\n".
       "ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE\n".
       "POSSIBILITY OF SUCH DAMAGE.\n";
  exit;
}

if ($args->isDefined('verbose')) {
  define('VERBOSE', true);
}

if (!$args->isDefined('from') || !$args->isDefined('to')) {
  echo Console_Getargs::getHelp($argConfig, null, "\nMissing one or more ".
      "required arguments\n", 80, 2);
  exit(1);
}

if ($args->getValue('passphrase') == '') {
  define('CRACKUP_NOGPG', true);
}

// -- The Good Stuff -----------------------------------------------------------

Crackup::$passphrase = $args->getValue('passphrase');
Crackup::$remote     = rtrim($args->getValue('to'), '/');
Crackup::$local      = $args->getValue('from');

if (!is_array(Crackup::$local)) {
  Crackup::$local = array(Crackup::$local);
}

// Make sure the remote location exists.
if (!is_dir(Crackup::$remote)) {
  Crackup::error('Invalid remote location: '.Crackup::$remote);
}

// Get the list of remote files and directories.
Crackup::debug('Retrieving remote file list...');
Crackup::$remoteFiles = Crackup::getRemoteFiles();

// Build a list of source files and directories.
Crackup::debug('Building local file list...');
Crackup::$localFiles = Crackup::getLocalFiles();

// Determine differences.
Crackup::debug('Determining differences...');
$update = Crackup::getUpdatedFiles(Crackup::$localFiles, Crackup::$remoteFiles);
$remove = Crackup::getRemovedFiles(Crackup::$localFiles, Crackup::$remoteFiles);

// Remove files from the remote location if necessary.
if (count($remove)) {
  Crackup::debug('Removing outdated files from destination...');
  Crackup::remove($remove);
}

// Update files at the remote location if necessary.
if (count($update)) {
  Crackup::debug('Updating destination with new/changed files...');
  Crackup::update($update);
}

// Update the remote file index if necessary.
if (count($remove) || count($update)) {
  Crackup::debug('Updating remote index...');
  Crackup::updateRemoteIndex();
}

Crackup::debug('Finished!');
?>