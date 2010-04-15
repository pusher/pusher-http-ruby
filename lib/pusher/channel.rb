require 'crack/core_extensions' # Used for Hash#to_params

module Pusher
  class Channel
    def initialize(app_id, name)
      @uri = URI::HTTP.build({
        :host => Pusher.host,
        :port => Pusher.port,
        :path => "/app/#{app_id}/channel/#{name}/event"
      })
      @http = Net::HTTP.new(@uri.host, @uri.port)
    end

    def trigger(event_name, data, socket_id = nil)
      params = {
        :name => event_name,
      }
      params[:socket_id] = socket_id if socket_id

      body = case data
      when String
        data
      when Hash
        self.class.turn_into_json(data)
      end

      request = Authentication::Request.new(@uri.path, params, body)
      auth_hash = request.sign(Pusher.authentication_token)

      query_params = params.merge(auth_hash)
      @uri.query = query_params.to_params

      @http.post("#{@uri.path}?#{@uri.query}", body, {
        'Content-Type'=> 'application/json'
      })
    rescue StandardError => e
      handle_error e
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
