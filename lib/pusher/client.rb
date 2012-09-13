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

    # @private Builds a connection url for Pusherapp
    def url
      URI::Generic.build({
        :scheme => @scheme,
        :host => @host,
        :port => @port,
        :path => "/apps/#{@app_id}"
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

    # Return a channel by name
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
    # @return [Hash] See Pusher api docs
    # @raise [Pusher::Error] on invalid Pusher response - see the error message for more details
    # @raise [Pusher::HTTPError] on any error raised inside Net::HTTP - the original error is available in the original_error attribute
    #
    def channels
      @_channels_url ||= begin
        uri = url.dup
        uri.path = uri.path + '/channels'
        uri
      end
      request = Pusher::Request.new(:get, @_channels_url, {}, nil, nil, self)
      return request.send_sync
    end

    # Request presence channels from the API
    #
    # GET /apps/[id]/channels/presence
    #
    # @return [Hash] See Pusher api docs
    # @raise [Pusher::Error] on invalid Pusher response - see the error message for more details
    # @raise [Pusher::HTTPError] on any error raised inside Net::HTTP - the original error is available in the original_error attribute
    #
    def presence_channels
      @_pc_url ||= begin
        uri = url.dup
        uri.path = uri.path + '/channels/presence'
        uri
      end
      request = Pusher::Request.new(:get, @_pc_url, {}, nil, nil, self)
      return request.send_sync
    end

    def trigger(channels, event_name, data, socket_id = nil)
      @_trigger_url ||= begin
        uri = url.dup
        uri.path = uri.path + '/events'
        uri
      end

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

      body = {
        name: event_name,
        channels: channels,
        data: encoded_data,
      }
      body[:socket_id] = socket_id if socket_id

      request = Pusher::Request.new(:post, @_trigger_url, {}, MultiJson.encode(body), nil, self)
      return request.send_sync
    end

    private

    def configured?
      host && scheme && key && secret && app_id
    end
  end
end
