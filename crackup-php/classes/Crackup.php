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
  public static $driver;
  public static $local       = array();
  public static $localFiles  = array();
  public static $passphrase  = '';
  public static $remote      = '';
  public static $remoteFiles = array();
  
  // -- Public Static Methods --------------------------------------------------
  
  /**
   * Compresses the specified local input file using bzip2 compression and
   * writes the compressed data to the specified output file.
   * 
   * @param string $infile name of the input file
   * @param string $outfile name of the output file
   */
  public static function compressFile($infile, $outfile) {
    $fp = fopen($infile, 'rb');
    $bz = bzopen($outfile, 'w');
    
    while (!feof($fp)) {
      bzwrite($bz, fread($fp, 1048576));
    }
    
    bzclose($bz);
    fclose($fp);
  }
  
  /**
   * Prints the specified debugging message if verbose mode is enabled.
   * 
   * @param string $message message to print
   */
  public static function debug($message) {
    if (defined('VERBOSE')) {
      echo "--> ".$message."\n";
    }
  }
  
  /**
   * Decompresses the specified local input file using bzip2 and writes the
   * decompressed data to the specified output file.
   * 
   * @param string $infile name of the input file
   * @param string $outfile name of the output file
   */  
  public static function decompressFile($infile, $outfile) {
    $bz = bzopen($infile, 'r');
    $fp = fopen($outfile, 'wb');
    
    while(!feof($bz)) {
      fwrite($fp, bzread($bz, 1048576));
    }
    
    fclose($fp);
    bzclose($bz);
  }
  
  /**
   * Decrypts the specified local file using GPG.
   * 
   * @param string $infile filename of the file to decrypt
   * @param string $outfile filename of the file to decrypt to
   */
  public static function decryptFile($infile, $outfile) {
    $gpgCommand = strtr(GPG_DECRYPT, array(
      ':input_file'  => escapeshellarg($infile),
      ':output_file' => escapeshellarg($outfile),
      ':passphrase'  => escapeshellarg(self::$passphrase)
    ));
    
    @shell_exec($gpgCommand);
  }
  
  /**
   * Encrypts the specified local file using GPG.
   *
   * @param string $infile filename of the file to encrypt
   * @param string $outfile filename of the file to encrypt to
   */
  public static function encryptFile($infile, $outfile) {
    $gpgCommand = strtr(GPG_ENCRYPT, array(
      ':input_file'  => escapeshellarg($infile),
      ':output_file' => escapeshellarg($outfile),
      ':passphrase'  => escapeshellarg(self::$passphrase)
    ));
    
    @shell_exec($gpgCommand);
  }
  
  /**
   * Prints the specified error message to stderr and exists with an error code.
   *
   * @param string $message message to print
   */
  public static function error($message) {
    fwrite(STDERR, "Error: ".$message."\n");
    exit(1);
  }
  
  /**
   * Searches the remote file index for a file whose local filename matches the
   * name specified and returns it if found, or <em>false</em> otherwise.
   *
   * @param string $filename local filename to search for
   * @return mixed
   */
  public static function findRemoteFile($filename) {
    $filename = rtrim($filename, '/');
    
    foreach(self::$remoteFiles as $file) {
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
   * @return array
   * @see getRemoteFiles()
   */
  public static function getLocalFiles() {
    $localFiles = array();
    
    foreach(self::$local as $pattern) {
      if (false === ($filenames = glob($pattern, GLOB_NOSORT))) {
        continue;
      }
      
      foreach($filenames as $filename) {
        $filename = rtrim($filename, '/');
        
        if (isset($localFiles[$filename])) {
          continue;
        }
        
        if (is_dir($filename)) {
          self::debug($filename);
          $localFiles[$filename] = new CrackupDirectory($filename);
        }
        elseif (is_file($filename)) {
          self::debug($filename);
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
   * @return array
   * @see getLocalFiles()
   */
  public static function getRemoteFiles() {
    $tmpFileList = self::getTempFile();
    
    try {
      self::$driver->get(self::$remote.'/.crackup_index', $tmpFileList);
    }
    catch (Exception $e) {
      @unlink($tmpFileList);
      return array();
    }
      
    $oldFile     = $tmpFileList;
    $tmpFileList = self::getTempFile();
    
    if (defined('CRACKUP_NOGPG')) {
      self::decompressFile($oldFile, $tmpFileList);
    }
    else {        
      self::decryptFile($oldFile, $tmpFileList);        
    }
    
    $fileList = @unserialize(@file_get_contents($tmpFileList));
    
    @unlink($oldFile);
    @unlink($tmpFileList);
    
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
   * @param array $localFiles array of local CrackupFileSystemObject objects
   * @param array $remoteFiles array of remote CrackupFileSystemObject objects
   * @return array removed CrackupFileSystemObject objects
   * @see getUpdatedFiles
   */
  public static function getRemovedFiles($localFiles, $remoteFiles) {
    $removed = array();
    
    foreach($remoteFiles as $name => $remoteFile) {
      // Remote remote files that no longer exist.
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
   * Generates a unique temporary filename.
   * 
   * @return string
   */
  public static function getTempFile() {
    return TEMP_DIR.'/'.uniqid('.crackup_temp');
  }
  
  /**
   * Gets an array of CrackupFileSystemObject objects representing files and
   * directories that are new or have been modified on the local machine and
   * need to be updated at the destination location.
   *
   * @param array $localFiles array of local CrackupFileSystemObject objects
   * @param array $remoteFiles array of remote CrackupFileSystemObject objects
   * @return array updated CrackupFileSystemObject objects
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
   * @param string $message message to display
   * @return string user input
   */
  public static function prompt($message) {
    echo $message.': ';
    return trim(fgets(STDIN));
  }
  
  /**
   * Deletes the specified files/directories from the remote location.
   *
   * @param array $files array of CrackupFileSystemObject objects to delete
   * @see update()
   */
  public static function remove($files) {
    foreach($files as $file) {
      if ($file instanceof CrackupDirectory) {
        self::remove($file);
      }
      elseif ($file instanceof CrackupFile) {
        self::debug($file->getName());
        
        try {
          self::$driver->delete(self::$remote.'/crackup_'.$file->getNameHash());
        }
        catch (Exception $e) {
          self::error('Unable to remove "'.$file->getName().'" from remote '.
              'location');
        }
      }
    }
  }
  
  /**
   * Uploads the specified files/directories to the remote location.
   *
   * @param array $files array of CrackupFileSystemObject objects to update
   * @see remove()
   */
  public static function update($files) {
    foreach($files as $file) {
      if ($file instanceof CrackupDirectory) {
        self::update($file);
      }
      elseif ($file instanceof CrackupFile) {
        self::debug($file->getName());
        
        $remoteFile = self::$remote.'/crackup_'.$file->getNameHash();
        $tempFile   = self::getTempFile();        
        
        // Create a compressed (and encrypted, if necessary) temporary file.
        if (defined('CRACKUP_NOGPG')) {
          self::compressFile($file->getName(), $tempFile);
        }
        else {
          self::encryptFile($file->getName(), $tempFile);
        }
          
        // Upload the temporary file to the remote location, then delete it.
        try {
          self::$driver->put($tempFile, $remoteFile);
        }
        catch (Exception $e) {
          @unlink($tempFile);
          self::error('Unable to upload file: '.$file->getName());
        }
        
        @unlink($tempFile);
      }
    }
  }
  
  /**
   * Brings the remote file index up to date with the local one.
   */
  public static function updateRemoteIndex() {
    $indexFile  = self::getTempFile();
    $remoteFile = self::$remote.'/.crackup_index';
    
    if (!file_put_contents($indexFile, serialize(self::$localFiles))) {
      self::error('Unable to write temporary file');
    }
    
    $oldFile   = $indexFile;
    $indexFile = self::getTempFile();
      
    if (defined('CRACKUP_NOGPG')) {
      self::compressFile($oldFile, $indexFile);
    }
    else {
      self::encryptFile($oldFile, $indexFile);
    }
    
    @unlink($oldFile);

    $success = false;
    
    while(!$success) {
      try {
        $success = self::$driver->put($indexFile, $remoteFile);
      }
      catch (Exception $e) {
        $tryAgain = self::prompt('Unable to update remote index. Try again? '.
            '(y/n)');
        
        if (strtolower($tryAgain) != 'y') {
          @unlink($indexFile);
          exit(-1);
        }
      }
    }
    
    @unlink($indexFile);
  }
}
?>