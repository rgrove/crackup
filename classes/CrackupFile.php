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
}
?>