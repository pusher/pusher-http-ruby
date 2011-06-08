require 'crack/core_extensions' # Used for Hash#to_params
require 'hmac-sha2'
require 'multi_json'

module Pusher
  # Trigger events on Channels
  class Channel
    attr_reader :name

    def initialize(base_url, name)
      @uri = base_url.dup
      @uri.path = @uri.path + "/channels/#{name}/events"
      @name = name
    end

    # Trigger event asynchronously using EventMachine::HttpRequest
    #
    # @param (see #trigger!)
    # @return [EM::DefaultDeferrable]
    #   Attach a callback to be notified of success (with no parameters).
    #   Attach an errback to be notified of failure (with an error parameter
    #   which includes the HTTP status code returned)
    # @raise [LoadError] unless em-http-request gem is available
    # @raise [Pusher::Error] unless the eventmachine reactor is running. You
    #   probably want to run your application inside a server such as thin
    #
    def trigger_async(event_name, data, socket_id = nil, &block)
      unless defined?(EventMachine) && EventMachine.reactor_running?
        raise Error, "In order to use trigger_async you must be running inside an eventmachine loop"
      end
      require 'em-http' unless defined?(EventMachine::HttpRequest)

      request = Pusher::Request.new(@uri, event_name, data, socket_id)

      deferrable = EM::DefaultDeferrable.new
      
      http = EventMachine::HttpRequest.new(@uri).post({
        :query => request.query, :timeout => 5, :body => request.body,
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

    # Trigger event
    #
    # @example
    #   begin
    #     Pusher['my-channel'].trigger!('an_event', {:some => 'data'})
    #   rescue Pusher::Error => e
    #     # Do something on error
    #   end
    #
    # @param data [Object] Event data to be triggered in javascript.
    #   Objects other than strings will be converted to JSON
    # @param socket_id Allows excluding a given socket_id from receiving the
    #   event - see http://pusherapp.com/docs/duplicates for more info
    #
    # @raise [Pusher::Error] on invalid Pusher response - see the error message for more details
    # @raise [Pusher::HTTPError] on any error raised inside Net::HTTP - the original error is available in the original_error attribute
    #
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

      begin
        response = @http_sync.post("#{@uri.path}?#{request.query.to_params}",
          request.body, { 'Content-Type'=> 'application/json' })
      rescue Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED,
             Timeout::Error, EOFError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
             Net::ProtocolError => e
        error = Pusher::HTTPError.new("#{e.message} (#{e.class})")
        error.original_error = e
        raise error
      end

      return handle_response(response.code.to_i, response.body.chomp)
    end

    # Trigger event, catching and logging any errors.
    #
    # @note CAUTION! No exceptions will be raised on failure
    # @param (see #trigger!)
    #
    def trigger(event_name, data, socket_id = nil)
      trigger!(event_name, data, socket_id)
    rescue Pusher::Error => e
      Pusher.logger.error("#{e.message} (#{e.class})")
      Pusher.logger.debug(e.backtrace.join("\n"))
    end
    
    # Compute authentication string required to subscribe to this channel.
    #
    # See http://pusherapp.com/docs/auth_signatures for more details.
    #
    # @param socket_id [String] Each Pusher socket connection receives a
    #   unique socket_id. This is sent from pusher.js to your server when
    #   channel authentication is required.
    # @param custom_string [String] Allows signing additional data
    # @return [String]
    #
    def authentication_string(socket_id, custom_string = nil)
      raise "Invalid socket_id" if socket_id.nil? || socket_id.empty?
      raise 'Custom argument must be a string' unless custom_string.nil? || custom_string.kind_of?(String)

      string_to_sign = [socket_id, name, custom_string].compact.map{|e|e.to_s}.join(':')
      Pusher.logger.debug "Signing #{string_to_sign}"
      token = Pusher.authentication_token
      signature = HMAC::SHA256.hexdigest(token.secret, string_to_sign)

      return "#{token.key}:#{signature}"
    end
    
    # Deprecated - for backward compatibility
    alias :socket_auth :authentication_string

    # Generate an authentication endpoint response
    #
    # @example Private channels
    #   render :json => Pusher['private-my_channel'].authenticate(params[:socket_id])
    #
    # @example Presence channels
    #   render :json => Pusher['private-my_channel'].authenticate(params[:socket_id], {
    #     :user_id => current_user.id, # => required
    #     :user_info => { # => optional - for example
    #       :name => current_user.name,
    #       :email => current_user.email
    #     }
    #   })
    #
    # @param socket_id [String]
    # @param custom_data [Hash] used for example by private channels
    #
    # @return [Hash]
    #
    # @private Custom data is sent to server as JSON-encoded string
    #
    def authenticate(socket_id, custom_data = nil)
      custom_data = MultiJson.encode(custom_data) if custom_data
      auth = socket_auth(socket_id, custom_data)
      r = {:auth => auth}
      r[:channel_data] = custom_data if custom_data
      r
    end

    private

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
        raise Error, "Unknown error (status code #{status_code}): #{body}"
      end
    end

    def ssl?
      @uri.scheme == 'https'
    end
  end
end
