require "phpass"
class GrandfatheredCryptoProvider < Sorcery::CryptoProviders::BCrypt
  class << self
    def matches?(_crypted, pass, _salt)
      if _crypted.starts_with?("$P$")
         phpass = Phpass.new(8)
         return phpass.check( pass, _crypted)
      else
        super
      end
    end
  end
end