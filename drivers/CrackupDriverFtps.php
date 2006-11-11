<?php
/**
 * SSL-FTP storage driver for Crackup. Please note that SSL-FTP is NOT the same
 * as SFTP!
 * 
 * This driver will not work on Windows unless your PHP binaries were compiled
 * with OpenSSL support (the official PHP Windows binaries aren't).
 * 
 * @author Ryan Grove <ryan@wonko.com>
 * @package Crackup
 */
class CrackupDriverFtps extends CrackupDriver {
  // -- Private Instance Variables ---------------------------------------------
  private $_stream;
  
  // -- Public Instance Methods ------------------------------------------------
  public function __construct($url) {
    $parsedUrl = parse_url($url);
    
    if (!isset($parsedUrl['host'])) {
      throw new CrackupDriverUrlException('No hostname specified: '.$url);
    }
    
    // Attempt to connect to the FTP server.
    $this->_stream = @ftp_ssl_connect($parsedUrl['host'], 
        (isset($parsedUrl['port']) ? $parsedUrl['port'] : 21));
    
    if ($this->_stream === false) {
      throw new CrackupDriverException('Unable to connect to host: '.$url);
    }
    
    // Login if necessary.
    if (isset($parsedUrl['user']) && isset($parsedUrl['pass'])) {
      if (!@ftp_login($this->_stream, $parsedUrl['user'], $parsedUrl['pass'])) {
        throw new CrackupDriverException('Login failed: '.$url);
      }
    }
    
    // Turn passive mode on.
    ftp_pasv($this->_stream, true);
    
    parent::__construct($url);
  }
  
  public function __destruct() {
    @ftp_close($this->_stream);
  }
  
  public function delete($url) {
    if (@ftp_delete($this->_stream, parse_url($url, PHP_URL_PATH))) {
      return true;
    }
    
    throw new CrackupDriverDeleteException('Unable to delete remote file: '.
        $url);
  }
  
  public function get($url, $local_filename) {
    if (@ftp_get($this->_stream, $local_filename, parse_url($url, PHP_URL_PATH),
        FTP_BINARY)) {

      return true;
    }
    
    throw new CrackupDriverGetException('Unable to get remote file: '.$url);
  }
  
  public function put($local_filename, $url) {
    if (@ftp_put($this->_stream, parse_url($url, PHP_URL_PATH), $local_filename,
        FTP_BINARY)) {
          
      return true;
    }
    
    throw new CrackupDriverPutException('Unable to put remote file: '.$url);
  }
}
?>