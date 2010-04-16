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
    
    def initialize(path, query, body=nil)
      raise ArgumentError, "Expected string" unless path.kind_of?(String)
      raise ArgumentError, "Expected hash" unless query.kind_of?(Hash)

      query_hash = {}
      auth_hash = {}
      query.each do |key, v|
        k = key.to_s.downcase
        k[0..4] == 'auth_' ? auth_hash[k] = v : query_hash[k] = v
      end

      @path, @query_hash, @auth_hash, @body = path, query_hash, auth_hash,body
    end

    def sign(token)
      @auth_hash = {
        :auth_key => token.key,
        :auth_timestamp => Time.now.to_i
      }

      hmac_signature = HMAC::SHA256.digest(token.secret, string_to_sign)
      # chomp because the Base64 output ends with \n
      @auth_hash[:auth_signature] = Base64.encode64(hmac_signature).chomp
      
      return @auth_hash
    end

    def authenticate(token, authorization_header = nil)
      # TODO: Parse authorization_header if supplied
      # TODO: Check timestamp

      signature = @auth_hash.delete("auth_signature")

      hmac_signature = HMAC::SHA256.digest(token.secret, string_to_sign)
      # chomp because the Base64 output ends with \n
      base64_signature = Base64.encode64(hmac_signature).chomp

      return base64_signature == signature
    end

    def auth_hash
      raise "Request not signed" unless @auth_hash && @auth_hash[:auth_signature]
      @auth_hash
    end

    private

      def string_to_sign
        [@path, parameter_string, @body].compact.join("\n")
      end

      def parameter_string
        param_hash = @query_hash.merge(@auth_hash || {})
        
        # Convert keys to lowercase strings
        hash = {}; param_hash.each { |k,v| hash[k.to_s.downcase] = v }

        # Exclude signature from signature generation!
        hash.delete("auth_signature")

        hash.keys.sort.map { |k| "#{k}=#{hash[k]}" }.join("&")
      end
  end
end
