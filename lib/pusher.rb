autoload 'Logger', 'logger'
require 'uri'
require 'forwardable'

require 'pusher/client'

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
    extend Forwardable

    def_delegators :default_client, :scheme, :host, :port, :app_id, :key, :secret
    def_delegators :default_client, :scheme, :host=, :port=, :app_id=, :key=, :secret=

    def_delegators :default_client, :authentication_token, :url
    def_delegators :default_client, :encrypted=, :url=

    def_delegators :default_client, :channels, :presence_channels, :trigger

    attr_writer :logger

    # Return a channel by name
    #
    # @example
    #   Pusher['my-channel']
    # @return [Channel]
    # @raise [ConfigurationError] unless key, secret and app_id have been
    #   configured
    def [](channel_name)
      begin
        default_client[channel_name]
      rescue ConfigurationError
        raise ConfigurationError, 'Missing configuration: please check that Pusher.key, Pusher.secret and Pusher.app_id are configured.'
      end
    end

    def logger
      @logger ||= begin
        log = Logger.new($stdout)
        log.level = Logger::INFO
        log
      end
    end

    private

    def default_client
      @default_client ||= Pusher::Client.new
    end
  end

  if ENV['PUSHER_URL']
    self.url = ENV['PUSHER_URL']
  end
end

require 'pusher/channel'
require 'pusher/request'
require 'pusher/webhook'
