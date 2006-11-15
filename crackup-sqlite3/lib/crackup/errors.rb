module Crackup

  class Error < StandardError; end
  class CompressionError < Crackup::Error; end
  class EncryptionError < Crackup::Error; end
  class IndexError < Crackup::Error; end
  class StorageError < Crackup::Error; end

end
