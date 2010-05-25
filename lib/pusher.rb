autoload 'Logger', 'logger'
require 'uri'

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
      Signature::Token.new(@key, @secret)
    end

    # Builds a connection url for Pusherapp
    def url
      @url ||= URI::HTTP.build({
        :host => self.host,
        :port => self.port,
        :path => "/apps/#{self.app_id}"
      })
    end

    # Allows configuration from a url
    def url=(url)
      uri = URI.parse(url)
      self.app_id = uri.path.split('/').last
      self.key    = uri.user
      self.secret = uri.password
      self.host   = uri.host
      self.port   = uri.port
    end

    private

    def configured?
      host && port && key && secret && app_id
    end
  end

  self.host = 'api.pusherapp.com'
  self.port = 80

  if ENV['PUSHER_URL']
    self.url = ENV['PUSHER_URL']
  end

  def self.[](channel_name)
    raise ArgumentError, 'Missing configuration: please check that Pusher.url is configured' unless configured?
    @channels ||= {}
    @channels[channel_name.to_s] = Channel.new(url, channel_name)
  end
end

require 'pusher/channel'
require 'pusher/request'
