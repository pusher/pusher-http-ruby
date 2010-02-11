require 'rest_client'
require 'json'

class Pusher

  class << self
    attr_accessor :host, :port
    attr_writer :key, :secret
  end

  self.host = 'api.pusherapp.com'
  self.port = 80

  def self.[](channel_id)
    @channels ||= {}
    @channels[channel_id.to_s] ||= Channel.new(@key, channel_id)
  end

  class Channel
    def initialize(key, id)
      @http = RestClient::Resource.new(
        "http://#{Pusher.host}:#{Pusher.port}/app/#{key}/channel/#{id}"
      )
    end

    def trigger(event_name, data)
      begin
        @http.post(:event => JSON.generate({
          :event => event_name,
          :data => data
        }))
      rescue StandardError => e
        handle_error e
      end
    end

    private

      def handle_error(e)
        puts e.inspect
      end

  end

end
