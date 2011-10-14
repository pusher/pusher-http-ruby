require 'crack/core_extensions' # Used for Hash#to_params
require 'hmac-sha2'
require 'multi_json'

module Pusher
  # Trigger events on Channels
  class Channel
    attr_reader :name

    def initialize(base_url, name)
      @uri = base_url.dup
      @uri.path = @uri.path + "/channels/#{name}/"
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
      request = construct_event_request(event_name, data, socket_id)
      request.send_async
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
    #   event - see http://pusher.com/docs/publisher_api_guide/publisher_excluding_recipients for more info
    #
    # @raise [Pusher::Error] on invalid Pusher response - see the error message for more details
    # @raise [Pusher::HTTPError] on any error raised inside Net::HTTP - the original error is available in the original_error attribute
    #
    def trigger!(event_name, data, socket_id = nil)
      request = construct_event_request(event_name, data, socket_id)
      request.send_sync
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
    
    # Request channel stats
    #
    # @return [Hash] See Pusher api docs for reported stats
    # @raise [Pusher::Error] on invalid Pusher response - see the error message for more details
    # @raise [Pusher::HTTPError] on any error raised inside Net::HTTP - the original error is available in the original_error attribute
    #
    def stats
      request = Pusher::Request.new(:get, @uri + 'stats', {})
      return request.send_sync
    end

    # Compute authentication string required to subscribe to this channel.
    #
    # See http://pusher.com/docs/auth_signatures for more details.
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

    def construct_event_request(event_name, data, socket_id)
      params = {
        :name => event_name,
      }
      params[:socket_id] = socket_id if socket_id

      body = case data
      when String
        data
      else
        begin
          MultiJson.encode(data)
        rescue MultiJson::DecodeError => e
          Pusher.logger.error("Could not convert #{data.inspect} into JSON")
          raise e
        end
      end

      request = Pusher::Request.new(:post, @uri + 'events', params, body)
    end
  end
end
