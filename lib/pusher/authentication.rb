require 'hmac-sha2'
require 'base64'

module Authentication
  class Token
    attr_reader :key, :secret
    
    def initialize(key, secret)
      @key, @secret = key, secret
    end

    def sign(request)
      request.sign(self)
    end
  end

  class Request
    attr_accessor :path, :query_hash, :body
    
    def initialize(path, query_hash, body=nil)
      raise ArgumentError, "Expected string" unless path.kind_of?(String)
      raise ArgumentError, "Expected hash" unless query_hash.kind_of?(Hash)

      @path, @query_hash, @body = path, query_hash, body
    end

    def sign(token)
      @auth_hash = {
        :key => token.key,
        :timestamp => Time.now.to_i
      }

      hmac_signature = HMAC::SHA256.digest(token.secret, string_to_sign)
      # chomp because the Base64 output ends with \n
      base64_signature = Base64.encode64(hmac_signature).chomp
      
      return @auth_hash.merge(:signature => base64_signature)
    end

    def authenticate(token, authorization_header = nil)
      # TODO: Parse authorization_header if supplied
      # TODO: Check timestamp

      signature = @query_hash.delete("signature") || @query_hash.delete(:signature)

      hmac_signature = HMAC::SHA256.digest(token.secret, string_to_sign)
      # chomp because the Base64 output ends with \n
      base64_signature = Base64.encode64(hmac_signature).chomp

      return base64_signature == signature
    end

    private

      def string_to_sign
        [@path, parameter_string, @body].compact.join("\n")
      end

      def parameter_string
        param_hash = @query_hash.merge(@auth_hash || {})
        
        # Convert keys to lowercase strings
        hash = {}; param_hash.each { |k,v| hash[k.to_s.downcase] = v }

        hash.keys.sort.map { |k| "#{k}=#{hash[k]}" }.join("&")
      end
  end
end
