module Pusher
  class Client
    attr_accessor :scheme, :host, :port, :app_id, :key, :secret
    attr_writer :logger

    # Initializes the client object.
    def initialize(options = {})
      options = {
        scheme: 'http',
        host: 'api.pusherapp.com',
      }.merge(options)
      @scheme, @host, @port, @app_id, @key, @secret, @logger = options.values_at(
        :scheme, :host, :port, :app_id, :key, :secret, :logger
      )
    end

    # Returns the logger associated to the client
    def logger
      @logger ||= begin
        log = Logger.new($stdout)
        log.level = Logger::INFO
        log
      end
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
      @port ||= boolean ? 443 : 80
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

    private

    def configured?
      host && scheme && key && secret && app_id
    end
  end
end
