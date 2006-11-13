<?php
/**
 * Filesystem storage driver for Crackup.
 * 
 * @author Ryan Grove <ryan@wonko.com>
 * @package Crackup
 */
class CrackupDriverFile extends CrackupDriver {
  // -- Public Instance Methods ------------------------------------------------
  public function delete($url) {
    if (@unlink($url)) {
      return true;
    }
    
    throw new CrackupDriverDeleteException('Unable to delete remote file: '.
        $url);
  }
  
  public function get($url, $local_filename) {
    if (@copy($url, $local_filename)) {
      return true;
    }
    
    throw new CrackupDriverGetException('Unable to get remote file: '.$url);
  }
  
  public function put($local_filename, $url) {
    if (@copy($local_filename, $url)) {
      return true;
    }
    
    throw new CrackupDriverPutException('Unable to put remote file: '.$url);
  }
}
?>