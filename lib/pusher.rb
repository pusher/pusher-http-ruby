autoload 'Logger', 'logger'

module Pusher
  class Error < RuntimeError; end
  class AuthenticationError < Error; end

  class << self
    attr_accessor :host, :port
    attr_writer :logger
    attr_accessor :app_id, :key, :secret

    def logger
      @logger ||= begin
        log = Logger.new(STDOUT)
        log.level = Logger::INFO
        log
      end
    end
    
    def authentication_token
      Authentication::Token.new(@key, @secret)
    end
  end

  self.app_id = ENV["PUSHER_APP_ID"] if ENV["PUSHER_APP_ID"]
  self.key    = ENV["PUSHER_KEY"]    if ENV["PUSHER_KEY"]
  self.secret = ENV["PUSHER_SECRET"] if ENV["PUSHER_SECRET"]
  self.host = ENV["PUSHER_API_HOST"] || 'api.pusherapp.com'
  self.port = ENV["PUSHER_API_PORT"] || 80

  def self.[](channel_name)
    raise ArgumentError, 'Missing configuration: please check that Pusher.app_id, Pusher.key, and Pusher.secret are all configured' unless @app_id && @key && @secret
    @channels ||= {}
    @channels[channel_name.to_s] = Channel.new(@app_id, channel_name)
  end
end

require 'pusher/channel'
require 'pusher/authentication'
