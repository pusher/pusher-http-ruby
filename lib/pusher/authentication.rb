require 'hmac-sha2'
require 'base64'

module Authentication
  class AuthenticationError < RuntimeError; end

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

    # http://www.w3.org/TR/NOTE-datetime
    ISO8601 = "%Y-%m-%dT%H:%M:%SZ"

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

    # Authenticates the request with a token
    #
    # Timestamp check: Unless timestamp_grace is set to nil (which will skip
    # the timestamp check), an exception will be raised if timestamp is not
    # supplied or if the timestamp provided is not within timestamp_grace of
    # the real time (defaults to 10 minutes)
    #
    # Signature check: Raises an exception if the signature does not match the
    # computed value
    #
    def authenticate_by_token!(token, timestamp_grace = 600)
      validate_timestamp!(timestamp_grace)
      validate_signature!(token)
      true
    end

    def authenticate_by_token(token, timestamp_grace = 600)
      authenticate_by_token!(token, timestamp_grace)
    rescue AuthenticationError
      false
    end

    def authenticate(timestamp_grace = 600, &block)
      key = @auth_hash['auth_key']
      raise AuthenticationError, "Authentication key required" unless key
      token = yield key
      unless token && token.secret
        raise AuthenticationError, "Invalid authentication key"
      end
      authenticate_by_token!(token, timestamp_grace)
      return token
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

      def validate_timestamp!(grace)
        return true if grace.nil?

        timestamp = @auth_hash["auth_timestamp"]
        error = (timestamp.to_i - Time.now.to_i).abs
        raise AuthenticationError, "Timestamp required" unless timestamp
        if error >= grace
          raise AuthenticationError, "Timestamp expired: Given timestamp "\
            "(#{Time.at(timestamp.to_i).utc.strftime(ISO8601)}) "\
            "not within #{grace}s of server time "\
            "(#{Time.now.utc.strftime(ISO8601)})"
        end
        return true
      end

      def validate_signature!(token)
        string = string_to_sign
        hmac_signature = HMAC::SHA256.digest(token.secret, string)
        # chomp because the Base64 output ends with \n
        base64_signature = Base64.encode64(hmac_signature).chomp
        unless @auth_hash["auth_signature"] == base64_signature
          raise AuthenticationError, "Invalid signature: you should have "\
            "sent Base64Encode(HmacSHA256(#{string.inspect}, your_secret_key))"
        end
        return true
      end
  end
end
