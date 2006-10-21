<?php
/**
 * CrackupFileSystemObject is an abstract class that provides core functionality
 * intended to be extended by more specific classes such as CrackupFile and
 * CrackupDirectory.
 *
 * @author Ryan Grove <ryan@wonko.com>
 * @package Crackup
 */
abstract class CrackupFileSystemObject {
  // -- Private Instance Variables ---------------------------------------------
  private $_name     = '';
  private $_nameHash = '';
  
  // -- Constructor ------------------------------------------------------------

  /**
   * Constructs a new CrackupFileSystemObject.
   * 
   * @param String $name object name
   */
  public function __construct($name) {
    $this->_name     = $name;
    $this->_nameHash = hash('sha256', $name);
  }
  
  // -- Public Instance Methods ------------------------------------------------
  
  /**
   * Gets the name of the filesystem object represented by this instance.
   * 
   * @return String
   */
  public function getName() {
    return $this->_name;
  }
  
  /**
   * Gets the SHA256 hash of the name of the filesystem object represented by
   * this instance.
   *
   * @return String
   */
  public function getNameHash() {
    return $this->_nameHash;
  }
}
?>