require 'json'
require 'uri'
require 'net/http'

autoload 'Logger', 'logger'

class Pusher
  
  class ArgumentError < ::ArgumentError
    def message
      'You must configure both Pusher.key in order to authenticate your Pusher app'
    end
  end
  
  class << self
    attr_accessor :host, :port, :logger
    attr_writer :logger
    attr_writer :key, :secret

    def logger
      @logger ||= begin
        log = Logger.new(STDOUT)
        log.level = Logger::INFO
        log
      end
    end
  end

  self.host   = 'api.pusherapp.com'
  self.port   = 80

  def self.[](channel_id)
    raise ArgumentError unless @key
    @channels ||= {}
    @channels[channel_id.to_s] = Channel.new(@key, channel_id)
  end

  class Channel
    def initialize(key, id)
      @uri = URI.parse("http://#{Pusher.host}:#{Pusher.port}/app/#{key}/channel/#{id}")
      @http = Net::HTTP.new(@uri.host, @uri.port)
    end

    def trigger(event_name, data, socket_id = nil)
      begin
        @http.post( 
          @uri.path, 
          self.class.turn_into_json({
            :event => event_name,
            :data => data,
            :socket_id => socket_id
            }),
          {'Content-Type'=> 'application/json'}
        )
      rescue StandardError => e
        handle_error e
      end
    end
    
    def self.turn_into_json(data)
      if Object.const_defined?('ActiveSupport')
        data.to_json
      else
        JSON.generate(data)
      end
    end

    private

    def handle_error(e)
      self.logger.error(e.backtrace.join("\n"))
    end

  end

end
