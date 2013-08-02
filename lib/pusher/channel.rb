require 'openssl'
require 'multi_json'

module Pusher
  # Trigger events on Channels
  class Channel
    attr_reader :name

    def initialize(base_url, name, client = Pusher)
      @uri = base_url.dup
      @uri.path = @uri.path + "/channels/#{name}/"
      @name = name
      @client = client
    end

    # Trigger event asynchronously using EventMachine::HttpRequest
    #
    # [Deprecated] This method will be removed in a future gem version. Please
    # switch to Pusher.trigger_async or Pusher::Client#trigger_async instead
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
    def trigger_async(event_name, data, socket_id = nil)
      params = {}
      params[:socket_id] = socket_id if socket_id
      @client.trigger_async(name, event_name, data, params)
    end

    # Trigger event
    #
    # [Deprecated] This method will be removed in a future gem version. Please
    # switch to Pusher.trigger or Pusher::Client#trigger instead
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
    #   event - see http://pusher.com/docs/publisher_api_guide/publisher_excluding_recipients for more info
    #
    # @raise [Pusher::Error] on invalid Pusher response - see the error message for more details
    # @raise [Pusher::HTTPError] on any error raised inside http client - the original error is available in the original_error attribute
    #
    def trigger!(event_name, data, socket_id = nil)
      params = {}
      params[:socket_id] = socket_id if socket_id
      @client.trigger(name, event_name, data, params)
    end

    # Trigger event, catching and logging any errors.
    #
    # [Deprecated] This method will be removed in a future gem version. Please
    # switch to Pusher.trigger or Pusher::Client#trigger instead
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

    # Request info for a channel
    #
    # @param info [Array] Array of attributes required (as lowercase strings)
    # @return [Hash] Hash of requested attributes for this channel
    # @raise [Pusher::Error] on invalid Pusher response - see the error message for more details
    # @raise [Pusher::HTTPError] on any error raised inside http client - the original error is available in the original_error attribute
    #
    def info(attributes = [])
      @client.get("/channels/#{name}", :info => attributes.join(','))
    end

    # Compute authentication string required as part of the authentication
    # endpoint response. Generally the authenticate method should be used in
    # preference to this one
    #
    # @param socket_id [String] Each Pusher socket connection receives a
    #   unique socket_id. This is sent from pusher.js to your server when
    #   channel authentication is required.
    # @param custom_string [String] Allows signing additional data
    # @return [String]
    #
    def authentication_string(socket_id, custom_string = nil)
      if socket_id.nil? || socket_id.empty?
        raise Error, "Invalid socket_id #{socket_id}"
      end

      unless custom_string.nil? || custom_string.kind_of?(String)
        raise Error, 'Custom argument must be a string'
      end

      string_to_sign = [socket_id, name, custom_string].
        compact.map(&:to_s).join(':')
      Pusher.logger.debug "Signing #{string_to_sign}"
      token = @client.authentication_token
      digest = OpenSSL::Digest::SHA256.new
      signature = OpenSSL::HMAC.hexdigest(digest, token.secret, string_to_sign)

      return "#{token.key}:#{signature}"
    end

    # Generate the expected response for an authentication endpoint.
    # See http://pusher.com/docs/authenticating_users for details.
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
      auth = authentication_string(socket_id, custom_data)
      r = {:auth => auth}
      r[:channel_data] = custom_data if custom_data
      r
    end
  end
end
