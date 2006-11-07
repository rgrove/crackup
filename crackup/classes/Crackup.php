<?php
/**
 * Crackup is a static class providing a namespace for Crackup's core
 * functionality.
 * 
 * @static
 * @author Ryan Grove <ryan@wonko.com>
 * @package Crackup
 */
class Crackup {
  // -- Public Static Variables ------------------------------------------------
  public static $remote      = '';
  public static $remoteFiles = array();
  public static $passphrase  = '';
  public static $local       = array();
  public static $localFiles  = array();
  
  // -- Public Static Methods --------------------------------------------------
  
  /**
   * Prints the specified debugging message if verbose mode is enabled.
   * 
   * @param String $message message to print
   */
  public static function debug($message) {
    if (defined('VERBOSE')) {
      echo "--> ".$message."\n";
    }
  }
  
  /**
   * Decrypts the specified local file using GPG.
   * 
   * @param String $infile filename of the file to decrypt
   * @param String $outfile filename of the file to decrypt to
   */
  public static function decryptFile($infile, $outfile) {
    $gpgCommand = strtr(GPG_DECRYPT, array(
      ':input_file'  => escapeshellarg($infile),
      ':output_file' => escapeshellarg($outfile),
      ':passphrase'  => escapeshellarg(Crackup::$passphrase)
    ));
    
    @shell_exec($gpgCommand);
  }
  
  /**
   * Encrypts the specified local file using GPG.
   *
   * @param String $infile filename of the file to encrypt
   * @param String $outfile filename of the file to encrypt to
   */
  public static function encryptFile($infile, $outfile) {
    $gpgCommand = strtr(GPG_ENCRYPT, array(
      ':input_file'  => escapeshellarg($infile),
      ':output_file' => escapeshellarg($outfile),
      ':passphrase'  => escapeshellarg(Crackup::$passphrase)
    ));
    
    @shell_exec($gpgCommand);
  }
  
  /**
   * Prints the specified error message to stderr and exists with an error code.
   *
   * @param String $message message to print
   */
  public static function error($message) {
    file_put_contents('php://stderr', "Error: ".$message."\n");
    exit(1);
  }
  
  /**
   * Searches the remote file index for a file whose local filename matches the
   * name specified and returns it if found, or <em>false</em> otherwise.
   *
   * @param String $filename local filename to search for
   * @return mixed
   */
  public static function findRemoteFile($filename) {
    $filename = rtrim($filename, '/');
    
    foreach(Crackup::$remoteFiles as $file) {
      if ($file->getName() == $filename) {
        return $file;
      }
      
      if ($file instanceof CrackupDirectory) {
        if ($child = $file->find($filename)) {
          return $child;
        }
      }
    }
    
    return false;
  }
  
  /**
   * Gets an array of CrackupFileSystemObject objects representing the files and
   * directories on the local system in the locations specified by the array of
   * file patterns in Crackup::$local.
   *
   * @return Array
   * @see getRemoteFiles()
   */
  public static function getLocalFiles() {
    $localFiles = array();
    
    foreach(Crackup::$local as $pattern) {
      if (false === ($filenames = glob($pattern, GLOB_NOSORT))) {
        continue;
      }
      
      foreach($filenames as $filename) {
        $filename = rtrim($filename, '/');
        
        if (isset($localFiles[$filename])) {
          continue;
        }
        
        if (is_dir($filename)) {
          Crackup::debug($filename);
          $localFiles[$filename] = new CrackupDirectory($filename);
        }
        elseif (is_file($filename)) {
          Crackup::debug($filename);
          $localFiles[$filename] = new CrackupFile($filename);
        }
      }
    }
    
    return $localFiles;
  }
  
  /**
   * Returns an array of CrackupFileSystemObject objects present at the remote
   * location.
   *
   * @return Array
   * @see getLocalFiles()
   */
  public static function getRemoteFiles() {
    if (!($fileList = @file_get_contents(self::$remote.'/.crackup_index'))) {
      return array();
    }
    
    if (defined('CRACKUP_NOGPG')) {
      $fileList = @unserialize($fileList);
    }
    else {
      $tmpName1 = self::getTempFile();
      $tmpName2 = self::getTempFile();
      
      if (!@file_put_contents($tmpName1, $fileList)) {
        @unlink($tmpName1);
        @unlink($tmpName2);
        Crackup::error('Unable to write to temporary directory');
      }
      
      self::decryptFile($tmpName1, $tmpName2);
      
      $fileList = @unserialize(@file_get_contents($tmpName2));
      
      @unlink($tmpName1);
      @unlink($tmpName2);
    }
    
    if (is_array($fileList)) {
      return $fileList;
    }
    
    return array();
  }
  
  /**
   * Gets an array of CrackupFileSystemObject objects representing files and
   * directories that exist on the destination but no longer exist on the local
   * machine.
   *
   * @param Array $localFiles array of local CrackupFileSystemObject objects
   * @param Array $remoteFiles array of remote CrackupFileSystemObject objects
   * @return Array removed CrackupFileSystemObject objects
   * @see getUpdatedFiles
   */
  public static function getRemovedFiles($localFiles, $remoteFiles) {
    $removed = array();
    
    foreach($remoteFiles as $name => $remoteFile) {
      if (!isset($localFiles[$name])) {
        $removed[] = $remoteFile;
        continue;
      }
      
      $localFile = $localFiles[$name];
      
      if (($remoteFile instanceof CrackupDirectory) && 
          ($localFile instanceof CrackupDirectory)) {
            
        $removed = array_merge($removed, self::getRemovedFiles(
            $localFile->getChildren(), $remoteFile->getChildren()));
      }
    }
    
    return $removed;
  }
  
  /**
   * Returns a PHP stream context containing settings to be used for stream
   * operations.
   * 
   * @return stream context
   */
  public static function getStreamContext() {
    return stream_context_create(
      array(
        'ftp' => array(
          'overwrite' => true,
        ),
      )
    );
  }
  
  /**
   * Generates a unique temporary filename.
   */
  public static function getTempFile() {
    return TEMP_DIR.'/'.uniqid('.crackup_temp');
  }
  
  /**
   * Gets an array of CrackupFileSystemObject objects representing files and
   * directories that are new or have been modified on the local machine and
   * need to be updated at the destination location.
   *
   * @param Array $localFiles array of local CrackupFileSystemObject objects
   * @param Array $remoteFiles array of remote CrackupFileSystemObject objects
   * @return Array updated CrackupFileSystemObject objects
   * @see getRemovedFiles()
   */
  public static function getUpdatedFiles($localFiles, $remoteFiles) {
    $updated = array();
    
    foreach($localFiles as $name => $localFile) {
      if (!isset($remoteFiles[$name])) {
        $updated[] = $localFile;
        continue;
      }
      
      $remoteFile = $remoteFiles[$name];
      
      if (($localFile instanceof CrackupDirectory) &&
          ($remoteFile instanceof CrackupDirectory)) {

        $updated = array_merge($updated, self::getUpdatedFiles(
            $localFile->getChildren(), $remoteFile->getChildren()));
      }
      elseif (($localFile instanceof CrackupFile) &&
          ($remoteFile instanceof CrackupFile)) {

        if ($localFile->getFileHash() != $remoteFile->getFileHash()) {
          $updated[] = $localFile;
        }
      }
    }

    return $updated;
  }
  
  /**
   * Displays a message and prompts for user input.
   *
   * @param String $message message to display
   * @return String user input
   */
  public static function prompt($message) {
    echo $message.': ';
    return trim(fgets(STDIN));
  }
  
  /**
   * Deletes the specified files/directories from the remote location.
   *
   * @param Array $files array of CrackupFileSystemObject objects to delete
   * @see update()
   */
  public static function remove($files) {
    foreach($files as $file) {
      if ($file instanceof CrackupDirectory) {
        self::remove($file);
      }
      elseif ($file instanceof CrackupFile) {
        Crackup::debug($file->getName());
        
        if (false === @unlink(self::$remote.'/crackup_'.$file->getNameHash())) {
          Crackup::error('Unable to remove "'.$file->getName().'" from '.
              'destination');
        }
      }
    }
  }
  
  /**
   * Uploads the specified files/directories to the remote location.
   *
   * @param Array $files array of CrackupFileSystemObject objects to update
   * @see remove()
   */
  public static function update($files) {
    foreach($files as $file) {
      if ($file instanceof CrackupDirectory) {
        self::update($file);
      }
      elseif ($file instanceof CrackupFile) {
        Crackup::debug($file->getName());
        
        $remoteFile = self::$remote.'/crackup_'.$file->getNameHash();
        
        // We have to manually delete the remote file if it already exists,
        // since some stream protocols don't allow overwriting by default.
        // FIXME: For some reason, file_exists returns false even when the file exists on an FTP server. WTF?
        if (@file_exists($remoteFile)) {
          if (false === @unlink($remoteFile)) {
            Crackup::error('Unable to remove "'.$file->getName().'" from '.
                'destination prior to update');
          }
        }
        
        if (defined('CRACKUP_NOGPG')) {
          if (false === @copy($file->getName(), $remoteFile)) {
            Crackup::error('Unable to update "'.$file->getName().'" at '.
                'destination');
          }
        }
        else {
          // Create a temporary local file and compress/encrypt it with GPG.
          $tmpName = self::getTempFile();

          self::encryptFile($file->getName(), $tmpName);          
          
          // Copy the compressed/encrypted temporary file to the destination
          // location, then delete the local copy.
          if (false === @copy($tmpName, $remoteFile)) {
            @unlink($tmpName);
            Crackup::error('Unable to update "'.$file->getName().'" at '.
                'destination');
          }
          
          @unlink($tmpName);
        }
      }
    }
  }
  
  /**
   * Brings the remote file index up to date with the local one.
   */
  public static function updateRemoteIndex() {
    $index      = serialize(Crackup::$localFiles);
    $remoteFile = Crackup::$remote.'/.crackup_index';
    
    if (defined('CRACKUP_NOGPG')) {
      while (!@file_put_contents($remoteFile, $index, null,
          Crackup::getStreamContext())) {

        $tryAgain = Crackup::prompt('Unable to update remote index. Try '.
            'again? (y/n)');

        if (strtolower($tryAgain) != 'y') {
          exit(-1);
        }
      }
    }
    else {
      $tmpName1 = Crackup::getTempFile();
      $tmpName2 = Crackup::getTempFile();
      
      while (!@file_put_contents($tmpName1, $index)) {
        $tryAgain = Crackup::prompt('Unable to write to temporary directory. '.
            'Try again? (y/n)');
        
        if (strtolower($tryAgain) != 'y') {
          @unlink($tmpName1);
          @unlink($tmpName2);
          exit(-1);
        }
      }
      
      self::encryptFile($tmpName1, $tmpName2);
      
      if (@file_exists($remoteFile)) {
        @unlink($remoteFile);
      }
      
      while (!@copy($tmpName2, $remoteFile)) {
        $tryAgain = Crackup::prompt('Unable to update remote index. Try '.
            'again? (y/n)');
        
        if (strtolower($tryAgain) != 'y') {
          @unlink($tmpName1);
          @unlink($tmpName2);
          exit(-1);
        }
      }
      
      @unlink($tmpName1);
      @unlink($tmpName2);
    }
  }
}
?>