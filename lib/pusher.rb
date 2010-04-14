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
    attr_accessor :key, :secret

    def logger
      @logger ||= begin
        log = Logger.new(STDOUT)
        log.level = Logger::INFO
        log
      end
    end
  end

  self.host = 'api.pusherapp.com'
  self.port = 80

  def self.[](channel_id)
    raise ArgumentError unless @key
    @channels ||= {}
    @channels[channel_id.to_s] = Channel.new(@key, channel_id)
  end
end

require 'pusher/channel'
