autoload 'Logger', 'logger'
require 'uri'

# Used for configuring API credentials and creating Channel objects
#
module Pusher
  # All Pusher errors descend from this class so you can easily rescue Pusher
  # errors
  #
  # @example
  #   begin
  #     Pusher['a_channel'].trigger!('an_event', {:some => 'data'})
  #   rescue Pusher::Error => e
  #     # Do something on error
  #   end
  class Error < RuntimeError; end
  class AuthenticationError < Error; end
  class ConfigurationError < Error; end
  class HTTPError < Error; attr_accessor :original_error; end

  class << self
    attr_accessor :scheme, :host, :port
    attr_writer :logger
    attr_accessor :app_id, :key, :secret

    # @private
    def logger
      @logger ||= begin
        log = Logger.new($stdout)
        log.level = Logger::INFO
        log
      end
    end

    # @private
    def authentication_token
      Signature::Token.new(@key, @secret)
    end

    # @private Builds a connection url for Pusherapp
    def url
      URI::Generic.build({
        :scheme => self.scheme,
        :host => self.host,
        :port => self.port,
        :path => "/apps/#{self.app_id}"
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
      self.app_id = uri.path.split('/').last
      self.key    = uri.user
      self.secret = uri.password
      self.host   = uri.host
      self.port   = uri.port
    end

    # Configure whether Pusher API calls should be made over SSL
    # (default false)
    #
    # @example
    #   Pusher.encrypted = true
    #
    def encrypted=(boolean)
      Pusher.scheme = boolean ? 'https' : 'http'
      # Configure port if it hasn't already been configured
      Pusher.port ||= boolean ? 443 : 80
    end

    private

    def configured?
      host && scheme && key && secret && app_id
    end
  end

  # Defaults
  self.scheme = 'http'
  self.host = 'api.pusherapp.com'

  if ENV['PUSHER_URL']
    self.url = ENV['PUSHER_URL']
  end

  # Return a channel by name
  #
  # @example
  #   Pusher['my-channel']
  # @return [Channel]
  # @raise [ConfigurationError] unless key, secret and app_id have been
  #   configured
  def self.[](channel_name)
    raise ConfigurationError, 'Missing configuration: please check that Pusher.key, Pusher.secret and Pusher.app_id are configured.' unless configured?
    @channels ||= {}
    @channels[channel_name.to_s] ||= Channel.new(url, channel_name)
  end
end

require 'pusher/channel'
require 'pusher/request'