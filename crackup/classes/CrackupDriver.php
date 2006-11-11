<?php
/**
 * CrackupDriver is a base class representing a Crackup storage driver.
 * 
 * @author Ryan Grove <ryan@wonko.com>
 * @package Crackup
 */
abstract class CrackupDriver {
  // -- Private Instance Variables ---------------------------------------------
  private $_url;
  
  // -- Public Static Methods --------------------------------------------------

  /**
   * Parses a URL and returns an instance of the appropriate Crackup storage
   * driver (if any).
   * 
   * @param string $url
   * @return CrackupDriver
   */
  public static function getDriver($url) {
    // Parse the URL.
    if (false === ($parsedUrl = @parse_url($url))) {
      throw new CrackupDriverUrlException('Invalid URL: '.$url);
    }
    
    // Look for the driver.
    $driverName  = (isset($parsedUrl['scheme']) ? 
        strtolower($parsedUrl['scheme']) : 'file');
    $driverClass = 'CrackupDriver'.ucfirst($driverName);
    $driverFile  = dirname(__FILE__).'/../drivers/'.$driverClass.'.php';
    
    if (!file_exists($driverFile)) {
      throw new CrackupDriverNotFoundException('Driver not found: '.
          $driverName);
    }
    
    // Load the driver.
    require_once $driverFile;
    
    return new $driverClass($url);
  }
  
  // -- Public Instance Methods ------------------------------------------------
  public function __construct($url) {
    $this->_url = $url;
  }
  
  // -- Abstract Public Instance Methods ---------------------------------------  
  abstract public function delete($filename);  
  abstract public function get($remote_filename, $local_filename);
  abstract public function put($local_filename, $remote_filename);
}

class CrackupDriverException extends Exception {}
class CrackupDriverDeleteException extends CrackupDriverException {}
class CrackupDriverGetException extends CrackupDriverException {}
class CrackupDriverNotFoundException extends CrackupDriverException {}
class CrackupDriverPutException extends CrackupDriverException {}
class CrackupDriverUrlException extends CrackupDriverException {}
?>