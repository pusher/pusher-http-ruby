require 'json'
require 'uri'
require 'net/http'

autoload 'Logger', 'logger'

module Pusher
  class ArgumentError < ::ArgumentError
    def message
      'You must configure both Pusher.key in order to authenticate your Pusher app'
    end
  end

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
    raise ArgumentError unless @key
    @channels ||= {}
    @channels[channel_name.to_s] = Channel.new(@app_id, channel_name)
  end
end

require 'pusher/channel'
require 'pusher/authentication'
