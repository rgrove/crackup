<?php
/**
 * CrackupFile represents a filesystem file.
 *
 * @author Ryan Grove <ryan@wonko.com>
 * @package Crackup
 */
class CrackupFile extends CrackupFileSystemObject {
  // -- Private Instance Variables ---------------------------------------------  
  private $_fileHash = '';
  
  // -- Constructor ------------------------------------------------------------
  
  /**
   * Constructs a new CrackupFile object.
   *
   * @param String $filename filename
   */
  public function __construct($filename) {
    if (!is_file($filename)) {
      throw new Exception($filename.' does not exist or is not a file');
    }
    
    $this->_fileHash = hash_file('sha256', $filename);
    
    parent::__construct($filename);
  }
  
  // -- Public Instance Methods ------------------------------------------------
  
  /**
   * Gets the SHA256 hash value of the file represented by this CrackupFile
   * instance as of the moment the class was instantiated.
   *
   * @return String
   */
  public function getFileHash() {
    return $this->_fileHash;
  }
  
  /**
   * Restores the remote copy of this file to the specified local path.
   * 
   * @param String $localPath
   */
  public function restore($localPath) {
    $localPath = rtrim($localPath, '/').'/'.str_replace(':', '', dirname(
        $this->getName()));
    $localFile  = $localPath.'/'.basename($this->getName());
    $remoteFile = Crackup::$remote.'/crackup_'.$this->getNameHash();

    // In Windows, PHP's mkdir() function only works with backslashes because
    // PHP was written by fucktards from the planet Spengo.
    $windowsLocalPath = str_replace("/", "\\", $localPath);
    $isWindows = strpos(php_uname('s'), 'Windows') === 0;
    
    Crackup::debug($localFile);

    if (!is_dir($localPath)) {
      if (!@mkdir(($isWindows ? $windowsLocalPath : $localPath), 0750, true)) {
        Crackup::error('Unable to create local directory: "'.$localPath.'"');
      }
    }
    
    // Download the file.
    $tmpFile = Crackup::getTempFile();
    
    try {
      Crackup::$driver->get($remoteFile, $tmpFile);
    }
    catch (Exception $e) {
      @unlink($tmpFile);
      Crackup::error('Unable to restore file: '.$localFile);
    }
    
    if (defined('CRACKUP_NOGPG')) {
      Crackup::decompressFile($tmpFile, $localFile);
    }
    else {
      Crackup::decryptFile($tmpFile, $localFile);
    }
    
    @unlink($tmpFile);
  }
}
?>