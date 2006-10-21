<?php
/**
 * CrackupDirectory represents a filesystem directory and can contain any number
 * of CrackupFileSystemObject objects as children.
 * 
 * This class implements the Iterator interface to allow iteration over the
 * directory's children.
 * 
 * @author Ryan Grove <ryan@wonko.com>
 * @package Crackup
 */
class CrackupDirectory extends CrackupFileSystemObject implements Iterator {
  // -- Private Instance Variables ---------------------------------------------
  private $_children = array();
  
  // -- Constructor ------------------------------------------------------------

  /**
   * Constructs a new CrackupDirectory object.
   * 
   * @param String $name directory name
   */
  public function __construct($name) {
    if (!is_dir($name)) {
      throw new Exception($name.' does not exist or is not a directory');
    }
    
    parent::__construct(rtrim($name, '/'));
    
    $this->updateChildren();
  }
  
  // -- Public Instance Methods ------------------------------------------------
  
  /**
   * Returns the current element in the children array, or <em>false</em> if the
   * internal pointer points beyond the end of the element list.
   * 
   * @return mixed
   */
  public function current() {
    return current($this->_children);
  }
  
  /**
   * Gets the child with the specified local filename, or <em>null</em> if the
   * filename does not match any children.
   *
   * @param String $name local filename
   * @return CrackupFileSystemObject
   */
  public function get($name) {
    if (isset($this->_children[$name])) {
      return $this->_children[$name];
    }
    
    return null;
  }
  
  /**
   * Gets an array of all children of this directory.
   *
   * @return Array array of CrackupFileSystemObject objects
   */
  public function getChildren() {
    return $this->_children;
  }
  
  /**
   * Returns the key (the local filename) of the current element in the children
   * array.
   *
   * @return String
   */
  public function key() {
    return key($this->_children);
  }
  
  /**
   * Advances the internal array pointer of the children array and returns the
   * next value, or <em>false</em> if there are no more elements.
   *
   * @return mixed
   */
  public function next() {
    return next($this->_children);
  }
  
  /**
   * Sets the internal pointer of the children array to the first element and
   * returns it, or <em>false</em> if the array is empty.
   *
   * @return mixed
   */
  public function rewind() {
    reset($this->_children);
  }
  
  /**
   * Rebuilds the children array by analyzing the local filesystem. An update is
   * automatically performed when a CrackupDirectory object is instantiated.
   */
  public function updateChildren() {
    $this->_children = array();
    
    if (false === ($filenames = glob($this->getName().'/*'))) {
      throw new Exception('Error updating children');
    }
    
    foreach($filenames as $filename) {
      if (is_dir($filename)) {
        $this->_children[rtrim($filename, '/')] = new CrackupDirectory(
            $filename);
      }
      elseif (is_file($filename)) {
        $this->_children[$filename] = new CrackupFile($filename);
      }
    }
  }
  
  /**
   * Returns <em>true</em> if the internal pointer of the children array is
   * pointing to a valid element, <em>false</em> otherwise.
   *
   * @return boolean
   */
  public function valid() {
    return $this->current() !== false;
  }
}
?>