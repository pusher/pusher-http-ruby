require 'json'
require 'uri'
require 'net/http'

autoload 'Logger', 'logger'

module Pusher
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

  self.host = 'api.pusherapp.com'
  self.port = 80

  def self.[](channel_name)
    raise ArgumentError, 'Missing configuration: please check that Pusher.app_id, Pusher.key, and Pusher.secret are all configured' unless @app_id && @key && @secret
    @channels ||= {}
    @channels[channel_name.to_s] = Channel.new(@app_id, channel_name)
  end
end

require 'pusher/channel'
require 'pusher/authentication'
