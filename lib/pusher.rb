autoload 'Logger', 'logger'

module Pusher
  class Error < RuntimeError; end
  class AuthenticationError < Error; end

  class << self
    attr_accessor :host, :port
    attr_writer :logger
    attr_accessor :url, :key, :secret

    def logger
      @logger ||= begin
        log = Logger.new(STDOUT)
        log.level = Logger::INFO
        log
      end
    end
    
    def authentication_token
      Signature::Token.new(@key, @secret)
    end
  end

  if ENV['PUSHER_URL']
    self.url = ENV['PUSHER_URL']
    self.key = URI.parse(url).user
    self.secret = URI.parse(url).password
    self.host = URI.parse(url).host
    self.port = URI.parse(url).port
  end

  def self.[](channel_name)
    raise ArgumentError, 'Missing configuration: please check that Pusher.url is configured' unless @url && @key && @secret
    @channels ||= {}
    @channels[channel_name.to_s] = Channel.new(@url, channel_name)
  end
end

require 'pusher/channel'
require 'pusher/request'
