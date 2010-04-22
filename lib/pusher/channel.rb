require 'crack/core_extensions' # Used for Hash#to_params
require 'digest/md5'

module Pusher
  class Channel
    def initialize(app_id, name)
      @uri = URI::HTTP.build({
        :host => Pusher.host,
        :port => Pusher.port,
        :path => "/apps/#{app_id}/channels/#{name}/events"
      })
      @http = Net::HTTP.new(@uri.host, @uri.port)
    end

    def trigger!(event_name, data, socket_id = nil)
      params = {
        :name => event_name,
      }
      params[:socket_id] = socket_id if socket_id

      body = case data
      when String
        data
      else
        begin
          self.class.turn_into_json(data)
        rescue => e
          Pusher.logger.error("Could not convert #{data.inspect} into JSON")
          raise e
        end
      end
      params[:body_md5] = Digest::MD5.hexdigest(body)

      request = Authentication::Request.new('POST', @uri.path, params)
      auth_hash = request.sign(Pusher.authentication_token)

      query_params = params.merge(auth_hash)
      @uri.query = query_params.to_params

      response = @http.post("#{@uri.path}?#{@uri.query}", body, {
        'Content-Type'=> 'application/json'
      })

      case response.code
      when "202"
        return true
      when "401"
        raise AuthenticationError, response.body.chomp
      when "404"
        raise Error, "Resource not found: app_id is probably invalid"
      else
        raise Error, "Unknown error in Pusher: #{response.body.chomp}"
      end
    end

    def trigger(event_name, data, socket_id = nil)
      trigger!(event_name, data, socket_id)
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
      Pusher.logger.error("#{e.message} (#{e.class})")
      Pusher.logger.debug(e.backtrace.join("\n"))
    end
  end
end
