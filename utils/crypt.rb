require 'openssl'
require 'base64'
require 'digest'

def encrypt(string, key)
  ciphertxt = aes(key,string)
  return Base64.encode64(ciphertxt).gsub /\s/, ''
end

def decrypt(string, key)
  return aes_decrypt(key, Base64.decode64(string))
end

def aes(key,string)
  cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
  cipher.encrypt
  cipher.key = Digest::SHA256.digest(key)
  cipher.iv = initialization_vector = cipher.random_iv
  cipher_text = cipher.update(string)
  cipher_text << cipher.final
  return initialization_vector + cipher_text
end

def aes_decrypt(key, encrypted)
  cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
  cipher.decrypt
  cipher.key = Digest::SHA256.digest(key)    
  cipher.iv = init_vector = encrypted.slice!(0,16)
  d = cipher.update(encrypted)
  d << cipher.final
end

