require 'multi_json'
require 'hmac-sha2'

module Pusher
  class WebHook
    attr_reader :key, :signature

    # Provide either a Rack::Request or a Hash containing :key, :signature,
    # :body, and :content_type (optional)
    #
    def initialize(request)
      if request.kind_of?(Rack::Request)
        @key = request.env['HTTP_X_PUSHER_APPKEY']
        @signature = request.env["HTTP_X_PUSHER_HMAC_SHA256"]
        @content_type = request.content_type

        request.body.rewind
        @body = request.body.read
        request.body.rewind
      else
        @key, @signature, @body = request.values_at(:key, :signature, :body)
        @content_type = request[:content_type] || 'application/json'
      end
    end

    # Returns true if the WebHook is valid or false otherwise. In the case
    # that the webhook is not valid, the reason is logged
    #
    def valid?
      if @key == Pusher.key
        return check_signature(Pusher.secret)
      else
        Pusher.logger.warn "Received webhook with unknown key: #{key}"
        return false
      end
    end

    # Array of events (as Hashes) contained inside the webhook
    #
    def events
      data["events"]
    end

    # The time at which the WebHook was initially triggered by Pusher, i.e.
    # when the event occurred
    #
    # @return [Time]
    #
    def time
      Time.at(data["time_ms"].to_f/1000)
    end

    # Access the parsed WebHook body
    #
    def data
      @data ||= begin
        case @content_type
        when 'application/json'
          MultiJson.decode(@body)
        else
          raise "Unknown Content-Type (#{@content_type})"
        end
      end
    end

    private

    # Checks signature against secret and returns boolean
    #
    def check_signature(secret)
      expected = HMAC::SHA256.hexdigest(secret, @body)
      if @signature == expected
        return true
      else
        Pusher.logger.warn "Received WebHook with invalid signature: got #{@signature}, expected #{expected}"
        return false
      end
    end
  end
end
