#!/usr/local/bin/php
<?php
/**
 * Restores files from Crackup backups.
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
require_once 'classes/CrackupDriver.php';
require_once 'classes/CrackupFileSystemObject.php';
require_once 'classes/CrackupDirectory.php';
require_once 'classes/CrackupFile.php';

// -- Constants ----------------------------------------------------------------

define('APP_NAME', 'Crackup Restore');
define('APP_VERSION', '0.1-svn');
define('APP_COPYRIGHT', 'Copyright (c) 2006 Ryan Grove (ryan@wonko.com). All rights reserved.');
define('APP_URL', 'http://wonko.com/software/crackup');

define('GPG_DECRYPT', 'echo :passphrase | gpg --batch --quiet --no-tty --no-secmem-warning --cipher-algo aes256 --compress-algo bzip2 --passphrase-fd 0 --output :output_file :input_file');
define('GPG_ENCRYPT', 'echo :passphrase | gpg --batch --quiet --no-tty --no-secmem-warning --cipher-algo aes256 --compress-algo bzip2 --passphrase-fd 0 --output :output_file --symmetric :input_file');

define('TEMP_DIR', (isset($_ENV['TMP']) ? rtrim($_ENV['TMP'], '/') : '.'));

// -- Command-line arguments ---------------------------------------------------
$argConfig = array(
  'all' => array(
    'short' => 'a',
    'max'   => 0,
    'min'   => 0,
    'desc'  => 'Restore all files'
  ),

  'from' => array(
    'short' => 'f',
    'max'   => 1,
    'min'   => 1,
    'desc'  => 'Backup URL to restore from (e.g., '.
        'ftp://user:pass@server.com/path)'
  ),
  
  'only|just' => array(
    'short' => 'o|j',
    'max'   => -1,
    'min'   => 1,
    'desc'  => 'Restore only the specified files and directories (and all '.
        'contents, in the case of directories)'
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
    'desc'  => 'Destination root directory for the restored files'
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

if (!$args->isDefined('from') || !$args->isDefined('to') || 
    (!$args->isDefined('all') && !$args->isDefined('only'))) {

  echo Console_Getargs::getHelp($argConfig, null, "\nMissing one or more ".
      "required arguments\n", 80, 2);
  exit(1);
}

if ($args->getValue('passphrase') == '') {
  define('CRACKUP_NOGPG', true);
}

// -- The Good Stuff -----------------------------------------------------------

Crackup::$passphrase = $args->getValue('passphrase');
Crackup::$local      = rtrim($args->getValue('to'), '/');
Crackup::$remote     = rtrim($args->getValue('from'), '/');

// Make sure the local location exists.
if (!is_dir(Crackup::$local)) {
  Crackup::error('Invalid local location: '.Crackup::$local);
}

// Load driver.
try {
  Crackup::$driver = CrackupDriver::getDriver(Crackup::$remote);
}
catch (Exception $e) {
  Crackup::error($e->getMessage());
}

// Get the list of remote files and directories.
Crackup::debug('Retrieving remote file list...');
Crackup::$remoteFiles = Crackup::getRemoteFiles();

Crackup::debug('Restoring files...');

if ($args->isDefined('all')) {
  foreach(Crackup::$remoteFiles as $file) {
    $file->restore(Crackup::$local);
  }
}
else {
  $filenames = $args->getValue('only');
  
  if (!is_array($filenames)) {
    $filenames = array($filenames);
  }
  
  foreach($filenames as $filename) {
    if (!($file = Crackup::findRemoteFile($filename))) {
      Crackup::error('Remote file not found: "'.$filename.'"');
    }
    
    $file->restore(Crackup::$local);
  }
}
?>