<?php
/**
 * Crackup is a static class providing a namespace for Crackup's core
 * functionality.
 * 
 * @static
 * @author    Ryan Grove <ryan@wonko.com>
 * @package   Crackup
 */
class Crackup {
  // -- Public Static Variables ------------------------------------------------
  public static $dest        = '';
  public static $destFiles   = array();
  public static $passphrase  = '';
  public static $source      = array();
  public static $sourceFiles = array();
  
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
   * Prints the specified error message to stderr and exists with an error code.
   *
   * @param String $message message to print
   */
  public static function error($message) {
    file_put_contents('php://stderr', "Error: ".$message."\n");
    exit(1);
  }
  
  /**
   * Returns an array of CrackupFileSystemObject objects present at the remote
   * location.
   *
   * @return Array
   * @see getSourceFiles()
   */
  public static function getDestFiles() {
    if (!($fileList = @file_get_contents(self::$dest.'/.crackup_index'))) {
      return array();
    }
    
    $fileList = @unserialize(@bzdecompress($fileList));
    
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
   * @param Array $sourceFiles array of local CrackupFileSystemObject objects
   * @param Array $destFiles array of remote CrackupFileSystemObject objects
   * @return Array removed CrackupFileSystemObject objects
   * @see getUpdatedFiles
   */
  public static function getRemovedFiles($sourceFiles, $destFiles) {
    $removed = array();
    
    foreach($destFiles as $name => $destFile) {
      if (!isset($sourceFiles[$name])) {
        $removed[] = $destFile;
        continue;
      }
      
      $sourceFile = $sourceFiles[$name];
      
      if (($destFile instanceof CrackupDirectory) && 
          ($sourceFile instanceof CrackupDirectory)) {
            
        $removed = array_merge($removed, self::getRemovedFiles(
            $sourceFile->getChildren(), $destFile->getChildren()));
      }
    }
    
    return $removed;
  }
  
  /**
   * Gets an array of CrackupFileSystemObject objects representing the files and
   * directories on the local system in the locations specified by the array of
   * file patterns in Crackup::$source.
   *
   * @return Array
   * @see getDestFiles()
   */
  public static function getSourceFiles() {
    $sourceFiles = array();
    
    foreach(Crackup::$source as $pattern) {
      if (false === ($filenames = glob($pattern, GLOB_NOSORT))) {
        continue;
      }
      
      foreach($filenames as $filename) {
        $filename = rtrim($filename, '/');
        
        if (isset($sourceFiles[$filename])) {
          continue;
        }
        
        if (is_dir($filename)) {
          Crackup::debug($filename);
          $sourceFiles[$filename] = new CrackupDirectory($filename);
        }
        elseif (is_file($filename)) {
          Crackup::debug($filename);
          $sourceFiles[$filename] = new CrackupFile($filename);
        }
      }
    }
    
    return $sourceFiles;
  }
  
  /**
   * Gets an array of CrackupFileSystemObject objects representing files and
   * directories that are new or have been modified on the local machine and
   * need to be updated at the destination location.
   *
   * @param Array $sourceFiles array of local CrackupFileSystemObject objects
   * @param Array $destFiles array of remote CrackupFileSystemObject objects
   * @return Array updated CrackupFileSystemObject objects
   * @see getRemovedFiles()
   */
  public static function getUpdatedFiles($sourceFiles, $destFiles) {
    $updated = array();
    
    foreach($sourceFiles as $name => $sourceFile) {
      if (!isset($destFiles[$name])) {
        $updated[] = $sourceFile;
        continue;
      }
      
      $destFile = $destFiles[$name];
      
      if (($sourceFile instanceof CrackupDirectory) &&
          ($destFile instanceof CrackupDirectory)) {

        $updated = array_merge($updated, self::getUpdatedFiles(
            $sourceFile->getChildren(), $destFile->getChildren()));
      }
      elseif (($sourceFile instanceof CrackupFile) &&
          ($destFile instanceof CrackupFile)) {

        if ($sourceFile->getFileHash() != $destFile->getFileHash()) {
          $updated[] = $sourceFile;
        }
      }
    }

    return $updated;
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
        
        if (false === @unlink(self::$dest.'/crackup_'.$file->getNameHash())) {
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
        
        $remoteFile = self::$dest.'/crackup_'.$file->getNameHash();
        
        // We have to manually delete the remote file if it already exists,
        // since some stream protocols don't allow overwriting by default.
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
          $tmpName = TEMP_DIR.'/'.uniqid('.crackup_temp');
          
          $gpgCommand = strtr(GPG, array(
            ':passphrase'  => escapeshellarg(Crackup::$passphrase),
            ':output_file' => escapeshellarg($tmpName),
            ':input_file'  => escapeshellarg($file->getName())
          ));
          
          $gpgResult = @shell_exec($gpgCommand);
          
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
    $index = bzcompress(serialize(Crackup::$sourceFiles));
    
    if (!@file_put_contents(Crackup::$dest.'/.crackup_index', $index)) {
      Crackup::error('Unable to update index at destination');
    }
  }
}
?>