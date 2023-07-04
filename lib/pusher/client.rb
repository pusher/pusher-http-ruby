require 'base64'
require 'pusher-signature'

module Pusher
  class Client
    attr_accessor :scheme, :host, :port, :app_id, :key, :secret, :encryption_master_key
    attr_reader :http_proxy, :proxy
    attr_writer :connect_timeout, :send_timeout, :receive_timeout,
                :keep_alive_timeout

    ## CONFIGURATION ##
    DEFAULT_CONNECT_TIMEOUT = 5
    DEFAULT_SEND_TIMEOUT = 5
    DEFAULT_RECEIVE_TIMEOUT = 5
    DEFAULT_KEEP_ALIVE_TIMEOUT = 30
    DEFAULT_CLUSTER = "mt1"

    # Loads the configuration from an url in the environment
    def self.from_env(key = 'PUSHER_URL')
      url = ENV[key] || raise(ConfigurationError, key)
      from_url(url)
    end

    # Loads the configuration from a url
    def self.from_url(url)
      client = new
      client.url = url
      client
    end

    def initialize(options = {})
      @scheme = "https"
      @port = options[:port] || 443

      if options.key?(:encrypted)
        warn "[DEPRECATION] `encrypted` is deprecated and will be removed in the next major version. Use `use_tls` instead."
      end

      if options[:use_tls] == false || options[:encrypted] == false
        @scheme = "http"
        @port = options[:port] || 80
      end

      @app_id = options[:app_id]
      @key = options[:key]
      @secret = options[:secret]

      @host = options[:host]
      @host ||= "api-#{options[:cluster]}.pusher.com" unless options[:cluster].nil? || options[:cluster].empty?
      @host ||= "api-#{DEFAULT_CLUSTER}.pusher.com"

      @encryption_master_key = Base64.strict_decode64(options[:encryption_master_key_base64]) if options[:encryption_master_key_base64]

      @http_proxy = options[:http_proxy]

      # Default timeouts
      @connect_timeout = DEFAULT_CONNECT_TIMEOUT
      @send_timeout = DEFAULT_SEND_TIMEOUT
      @receive_timeout = DEFAULT_RECEIVE_TIMEOUT
      @keep_alive_timeout = DEFAULT_KEEP_ALIVE_TIMEOUT
    end

    # @private Returns the authentication token for the client
    def authentication_token
      raise ConfigurationError, :key unless @key
      raise ConfigurationError, :secret unless @secret
      Pusher::Signature::Token.new(@key, @secret)
    end

    # @private Builds a url for this app, optionally appending a path
    def url(path = nil)
      raise ConfigurationError, :app_id unless @app_id
      URI::Generic.build({
        scheme: @scheme,
        host: @host,
        port: @port,
        path: "/apps/#{@app_id}#{path}"
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

    def http_proxy=(http_proxy)
      @http_proxy = http_proxy
      uri = URI.parse(http_proxy)
      @proxy = {
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        user: uri.user,
        password: uri.password
      }
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

    def encrypted?
      @scheme == 'https'
    end

    def cluster=(cluster)
      cluster = DEFAULT_CLUSTER if cluster.nil? || cluster.empty?

      @host = "api-#{cluster}.pusher.com"
    end

    # Convenience method to set all timeouts to the same value (in seconds).
    # For more control, use the individual writers.
    def timeout=(value)
      @connect_timeout, @send_timeout, @receive_timeout = value, value, value
    end

    # Set an encryption_master_key to use with private-encrypted channels from
    # a base64 encoded string.
    def encryption_master_key_base64=(s)
      @encryption_master_key = s ? Base64.strict_decode64(s) : nil
    end

    ## INTERACT WITH THE API ##

    def resource(path)
      Resource.new(self, path)
    end

    # GET arbitrary REST API resource using a synchronous http client.
    # All request signing is handled automatically.
    #
    # @example
    #   begin
    #     Pusher.get('/channels', filter_by_prefix: 'private-')
    #   rescue Pusher::Error => e
    #     # Handle error
    #   end
    #
    # @param path [String] Path excluding /apps/APP_ID
    # @param params [Hash] API params (see http://pusher.com/docs/rest_api)
    #
    # @return [Hash] See Pusher API docs
    #
    # @raise [Pusher::Error] Unsuccessful response - see the error message
    # @raise [Pusher::HTTPError] Error raised inside http client. The original error is wrapped in error.original_error
    #
    def get(path, params = {})
      resource(path).get(params)
    end

    # GET arbitrary REST API resource using an asynchronous http client.
    # All request signing is handled automatically.
    #
    # When the eventmachine reactor is running, the em-http-request gem is used;
    # otherwise an async request is made using httpclient. See README for
    # details and examples.
    #
    # @param path [String] Path excluding /apps/APP_ID
    # @param params [Hash] API params (see http://pusher.com/docs/rest_api)
    #
    # @return Either an EM::DefaultDeferrable or a HTTPClient::Connection
    #
    def get_async(path, params = {})
      resource(path).get_async(params)
    end

    # POST arbitrary REST API resource using a synchronous http client.
    # Works identially to get method, but posts params as JSON in post body.
    def post(path, params = {})
      resource(path).post(params)
    end

    # POST arbitrary REST API resource using an asynchronous http client.
    # Works identially to get_async method, but posts params as JSON in post
    # body.
    def post_async(path, params = {})
      resource(path).post_async(params)
    end

    ## HELPER METHODS ##

    # Convenience method for creating a new WebHook instance for validating
    # and extracting info from a received WebHook
    #
    # @param request [Rack::Request] Either a Rack::Request or a Hash containing :key, :signature, :body, and optionally :content_type.
    #
    def webhook(request)
      WebHook.new(request, self)
    end

    # Return a convenience channel object by name that delegates operations
    # on a channel. No API request is made.
    #
    # @example
    #   Pusher['my-channel']
    # @return [Channel]
    # @raise [Pusher::Error] if the channel name is invalid.
    #   Channel names should be less than 200 characters, and
    #   should not contain anything other than letters, numbers, or the
    #   characters "_\-=@,.;"
    def channel(channel_name)
      Channel.new(nil, channel_name, self)
    end

    alias :[] :channel

    # Request a list of occupied channels from the API
    #
    # GET /apps/[id]/channels
    #
    # @param params [Hash] Hash of parameters for the API - see REST API docs
    #
    # @return [Hash] See Pusher API docs
    #
    # @raise [Pusher::Error] Unsuccessful response - see the error message
    # @raise [Pusher::HTTPError] Error raised inside http client. The original error is wrapped in error.original_error
    #
    def channels(params = {})
      get('/channels', params)
    end

    # Request info for a specific channel
    #
    # GET /apps/[id]/channels/[channel_name]
    #
    # @param channel_name [String] Channel name (max 200 characters)
    # @param params [Hash] Hash of parameters for the API - see REST API docs
    #
    # @return [Hash] See Pusher API docs
    #
    # @raise [Pusher::Error] Unsuccessful response - see the error message
    # @raise [Pusher::HTTPError] Error raised inside http client. The original error is wrapped in error.original_error
    #
    def channel_info(channel_name, params = {})
      get("/channels/#{channel_name}", params)
    end

    # Request info for users of a presence channel
    #
    # GET /apps/[id]/channels/[channel_name]/users
    #
    # @param channel_name [String] Channel name (max 200 characters)
    # @param params [Hash] Hash of parameters for the API - see REST API docs
    #
    # @return [Hash] See Pusher API docs
    #
    # @raise [Pusher::Error] Unsuccessful response - see the error message
    # @raise [Pusher::HTTPError] Error raised inside http client. The original error is wrapped in error.original_error
    #
    def channel_users(channel_name, params = {})
      get("/channels/#{channel_name}/users", params)
    end

    # Trigger an event on one or more channels
    #
    # POST /apps/[app_id]/events
    #
    # @param channels [String or Array] 1-10 channel names
    # @param event_name [String]
    # @param data [Object] Event data to be triggered in javascript.
    #   Objects other than strings will be converted to JSON
    # @param params [Hash] Additional parameters to send to api, e.g socket_id
    #
    # @return [Hash] See Pusher API docs
    #
    # @raise [Pusher::Error] Unsuccessful response - see the error message
    # @raise [Pusher::HTTPError] Error raised inside http client. The original error is wrapped in error.original_error
    #
    def trigger(channels, event_name, data, params = {})
      post('/events', trigger_params(channels, event_name, data, params))
    end

    # Trigger multiple events at the same time
    #
    # POST /apps/[app_id]/batch_events
    #
    # @param events [Array] List of events to publish
    #
    # @return [Hash] See Pusher API docs
    #
    # @raise [Pusher::Error] Unsuccessful response - see the error message
    # @raise [Pusher::HTTPError] Error raised inside http client. The original error is wrapped in error.original_error
    #
    def trigger_batch(*events)
      post('/batch_events', trigger_batch_params(events.flatten))
    end

    # Trigger an event on one or more channels asynchronously.
    # For parameters see #trigger
    #
    def trigger_async(channels, event_name, data, params = {})
      post_async('/events', trigger_params(channels, event_name, data, params))
    end

    # Trigger multiple events asynchronously.
    # For parameters see #trigger_batch
    #
    def trigger_batch_async(*events)
      post_async('/batch_events', trigger_batch_params(events.flatten))
    end


    # Generate the expected response for an authentication endpoint.
    # See https://pusher.com/docs/channels/server_api/authorizing-users for details.
    #
    # @example Private channels
    #   render :json => Pusher.authenticate('private-my_channel', params[:socket_id])
    #
    # @example Presence channels
    #   render :json => Pusher.authenticate('presence-my_channel', params[:socket_id], {
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
    # @raise [Pusher::Error] if channel_name or socket_id are invalid
    #
    # @private Custom data is sent to server as JSON-encoded string
    #
    def authenticate(channel_name, socket_id, custom_data = nil)
      channel_instance = channel(channel_name)
      r = channel_instance.authenticate(socket_id, custom_data)
      if channel_name.match(/^private-encrypted-/)
        r[:shared_secret] = Base64.strict_encode64(
          channel_instance.shared_secret(encryption_master_key)
        )
      end
      r
    end

    # @private Construct a net/http http client
    def sync_http_client
      require 'httpclient'

      @client ||= begin
        HTTPClient.new(@http_proxy).tap do |c|
          c.connect_timeout = @connect_timeout
          c.send_timeout = @send_timeout
          c.receive_timeout = @receive_timeout
          c.keep_alive_timeout = @keep_alive_timeout
        end
      end
    end

    # @private Construct an em-http-request http client
    def em_http_client(uri)
      begin
        unless defined?(EventMachine) && EventMachine.reactor_running?
          raise Error, "In order to use async calling you must be running inside an eventmachine loop"
        end
        require 'em-http' unless defined?(EventMachine::HttpRequest)

        connection_opts = {
          connect_timeout: @connect_timeout,
          inactivity_timeout: @receive_timeout,
        }

        if defined?(@proxy)
          proxy_opts = {
            host: @proxy[:host],
            port: @proxy[:port]
          }
          if @proxy[:user]
            proxy_opts[:authorization] = [@proxy[:user], @proxy[:password]]
          end
          connection_opts[:proxy] = proxy_opts
        end

        EventMachine::HttpRequest.new(uri, connection_opts)
      end
    end

    private

    def trigger_params(channels, event_name, data, params)
      channels = Array(channels).map(&:to_s)
      raise Pusher::Error, "Too many channels (#{channels.length}), max 100" if channels.length > 100

      encoded_data = if channels.any?{ |c| c.match(/^private-encrypted-/) } then
        raise Pusher::Error, "Cannot trigger to multiple channels if any are encrypted" if channels.length > 1
        encrypt(channels[0], encode_data(data))
      else
        encode_data(data)
      end

      params.merge({
        name: event_name,
        channels: channels,
        data: encoded_data,
      })
    end

    def trigger_batch_params(events)
      {
        batch: events.map do |event|
          event.dup.tap do |e|
            e[:data] = if e[:channel].match(/^private-encrypted-/) then
              encrypt(e[:channel], encode_data(e[:data]))
            else
              encode_data(e[:data])
            end
          end
        end
      }
    end

    # JSON-encode the data if it's not a string
    def encode_data(data)
      return data if data.is_a? String
      MultiJson.encode(data)
    end

    # Encrypts a message with a key derived from the master key and channel
    # name
    def encrypt(channel_name, encoded_data)
      raise ConfigurationError, :encryption_master_key unless @encryption_master_key

      # Only now load rbnacl, so that people that aren't using it don't need to
      # install libsodium
      require_rbnacl

      secret_box = RbNaCl::SecretBox.new(
        channel(channel_name).shared_secret(@encryption_master_key)
      )

      nonce = RbNaCl::Random.random_bytes(secret_box.nonce_bytes)
      ciphertext = secret_box.encrypt(nonce, encoded_data)

      MultiJson.encode({
        "nonce" => Base64::strict_encode64(nonce),
        "ciphertext" => Base64::strict_encode64(ciphertext),
      })
    end

    def configured?
      host && scheme && key && secret && app_id
    end

    def require_rbnacl
      require 'rbnacl'
    rescue LoadError => e
      $stderr.puts "You don't have rbnacl installed in your application. Please add it to your Gemfile and run bundle install"
      raise e
    end
  end
end
