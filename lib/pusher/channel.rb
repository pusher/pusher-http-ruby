require 'crack/core_extensions' # Used for Hash#to_params
require 'hmac-sha2'

module Pusher
  class Channel
    attr_reader :name

    def initialize(base_url, name)
      @uri = base_url.dup
      @uri.path = @uri.path + "/channels/#{name}/events"
      @name = name
    end

    def trigger_async(event_name, data, socket_id = nil, &block)
      unless defined?(EventMachine) && EventMachine.reactor_running?
        raise Error, "In order to use trigger_async you must be running inside an eventmachine loop"
      end
      require 'em-http' unless defined?(EventMachine::HttpRequest)
      
      @http_async ||= EventMachine::HttpRequest.new(@uri)

      request = Pusher::Request.new(@uri, event_name, data, socket_id)

      deferrable = EM::DefaultDeferrable.new
      
      http = @http_async.post({
        :query => request.query, :timeout => 2, :body => request.body,
        :head => {'Content-Type'=> 'application/json'}
      })
      http.callback {
        begin
          handle_response(http.response_header.status, http.response.chomp)
          deferrable.succeed
        rescue => e
          deferrable.fail(e)
        end
      }
      http.errback {
        Pusher.logger.debug("Network error connecting to pusher: #{http.inspect}")
        deferrable.fail(Error.new("Network error connecting to pusher"))
      }
      
      deferrable
    end

    def trigger!(event_name, data, socket_id = nil)
      require 'net/http' unless defined?(Net::HTTP)
      require 'net/https' if (ssl? && !defined?(Net::HTTPS))

      @http_sync ||= begin
        http = Net::HTTP.new(@uri.host, @uri.port)
        http.use_ssl = true if ssl?
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if ssl?
        http
      end

      request = Pusher::Request.new(@uri, event_name, data, socket_id)

      response = @http_sync.post("#{@uri.path}?#{request.query.to_params}",
        request.body, { 'Content-Type'=> 'application/json' })

      handle_response(response.code.to_i, response.body.chomp)
    end

    def trigger(event_name, data, socket_id = nil)
      trigger!(event_name, data, socket_id)
    rescue StandardError => e
      handle_error e
    end
    
    # Auth string is:
    # if custom data provided:
    # socket_id:channel_name:[JSON-encoded custom data]
    # if no custom data:
    # socket_id:channel_name
    def socket_auth(socket_id, custom_string = nil)
      raise "Invalid socket_id" if socket_id.nil? || socket_id.empty?
      raise 'Custom argument must be a string' unless custom_string.nil? || custom_string.kind_of?(String)

      string_to_sign = [socket_id, name, custom_string].compact.map{|e|e.to_s}.join(':')
      Pusher.logger.debug "Signing #{string_to_sign}"
      token = Pusher.authentication_token
      signature = HMAC::SHA256.hexdigest(token.secret, string_to_sign)

      return "#{token.key}:#{signature}"
    end
    
    # Custom data is sent to server as JSON-encoded string in the :data key
    # If :data present, server must include it in auth check
    def authenticate(socket_id, custom_data = nil)
      custom_data = Pusher::JSON.generate(custom_data) if custom_data
      auth = socket_auth(socket_id, custom_data)
      r = {:auth => auth}
      r[:channel_data] = custom_data if custom_data
      r
    end

    private

    def handle_error(e)
      Pusher.logger.error("#{e.message} (#{e.class})")
      Pusher.logger.debug(e.backtrace.join("\n"))
    end

    def handle_response(status_code, body)
      case status_code
      when 202
        return true
      when 400
        raise Error, "Bad request: #{body}"
      when 401
        raise AuthenticationError, body
      when 404
        raise Error, "Resource not found: app_id is probably invalid"
      else
        raise Error, "Unknown error in Pusher: #{body}"
      end
    end

    def ssl?
      @uri.scheme == 'https'
    end
  end
end
