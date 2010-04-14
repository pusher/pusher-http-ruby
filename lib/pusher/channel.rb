module Pusher
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
