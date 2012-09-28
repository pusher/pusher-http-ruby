require 'signature'

module Pusher
  class Client
    attr_accessor :scheme, :host, :port, :app_id, :key, :secret

    # Initializes the client object.
    def initialize(options = {})
      options = {
        :scheme => 'http',
        :host => 'api.pusherapp.com',
        :port => 80,
      }.merge(options)
      @scheme, @host, @port, @app_id, @key, @secret = options.values_at(
        :scheme, :host, :port, :app_id, :key, :secret
      )
    end

    # @private Returns the authentication token for the client
    def authentication_token
      Signature::Token.new(@key, @secret)
    end

    # @private Builds a url for this app, optionally appending a path
    def url(path = nil)
      URI::Generic.build({
        :scheme => @scheme,
        :host => @host,
        :port => @port,
        :path => "/apps/#{@app_id}#{path}"
      })
    end

    # Configure Pusher connection by providing a url rather than specifying
    # scheme, key, secret, and app_id separately.
    #
    # @example
    #   Pusher.url = http://KEY:SECRET@api.pusherapp.com/apps/APP_ID
    #
    def url=(url)
      uri = URI.parse(url)
      @scheme = uri.scheme
      @app_id = uri.path.split('/').last
      @key    = uri.user
      @secret = uri.password
      @host   = uri.host
      @port   = uri.port
    end

    # Configure whether Pusher API calls should be made over SSL
    # (default false)
    #
    # @example
    #   Pusher.encrypted = true
    #
    def encrypted=(boolean)
      @scheme = boolean ? 'https' : 'http'
      # Configure port if it hasn't already been configured
      @port = boolean ? 443 : 80
    end

    # Return a convenience channel object by name. No API request is made.
    #
    # @example
    #   Pusher['my-channel']
    # @return [Channel]
    # @raise [ConfigurationError] unless key, secret and app_id have been
    #   configured
    def [](channel_name)
      raise ConfigurationError, 'Missing client configuration: please check that key, secret and app_id are configured.' unless configured?
      @channels ||= {}
      @channels[channel_name.to_s] ||= Channel.new(url, channel_name, self)
    end

    # Request a list of occupied channels from the API
    #
    # GET /apps/[id]/channels
    #
    # @param options [Hash] Hash of options for the API - see Pusher API docs
    # @return [Hash] See Pusher API docs
    # @raise [Pusher::Error] on invalid Pusher response - see the error message for more details
    # @raise [Pusher::HTTPError] on any error raised inside Net::HTTP - the original error is available in the original_error attribute
    #
    def channels(options = {})
      @_channels_url ||= url('/channels')
      request = Request.new(:get, @_channels_url, options, nil, nil, self)
      return request.send_sync
    end

    # Request info for a specific channel
    #
    # GET /apps/[id]/channels/[channel_name]
    #
    # @param channel_name [String] Channel name
    # @param options [Hash] Hash of options for the API - see Pusher API docs
    # @return [Hash] See Pusher API docs
    # @raise [Pusher::Error] on invalid Pusher response - see the error message for more details
    # @raise [Pusher::HTTPError] on any error raised inside Net::HTTP - the original error is available in the original_error attribute
    #
    def channel_info(channel_name, options = {})
      request = Request.new(:get, url("/channels/#{channel_name}"), options, nil, nil, self)
      return request.send_sync
    end

    # Trigger an event on one or more channels
    #
    # POST /apps/[app_id]/events
    #
    # @param channels [Array] One of more channel names
    # @param event_name [String]
    # @param data [Object] Event data to be triggered in javascript.
    #   Objects other than strings will be converted to JSON
    # @param options [Hash] Additional options to send to api, e.g socket_id
    # @return [Hash] See Pusher API docs
    # @raise [Pusher::Error] on invalid Pusher response - see the error message for more details
    # @raise [Pusher::HTTPError] on any error raised inside Net::HTTP - the original error is available in the original_error attribute
    #
    def trigger(channels, event_name, data, options = {})
      @_trigger_url ||= url('/events')

      encoded_data = case data
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

      options.merge!({
        :name => event_name,
        :channels => channels,
        :data => encoded_data,
      })

      request = Request.new(:post, @_trigger_url, {}, MultiJson.encode(options), nil, self)
      return request.send_sync
    end

    private

    def configured?
      host && scheme && key && secret && app_id
    end
  end
end
