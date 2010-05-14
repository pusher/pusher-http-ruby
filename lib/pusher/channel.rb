require 'crack/core_extensions' # Used for Hash#to_params
require 'signature'
require 'digest/md5'

require 'json'
require 'uri'

module Pusher
  class Channel
    def initialize(app_id, name)
      @uri = URI::HTTP.build({
        :host => Pusher.host,
        :port => Pusher.port,
        :path => "/apps/#{app_id}/channels/#{name}/events"
      })
    end

    def trigger_async(event_name, data, socket_id = nil, &block)
      unless defined?(EventMachine) && EventMachine.reactor_running?
        raise Error, "In order to use trigger_async you must be running inside an eventmachine loop"
      end
      require 'em-http' unless defined?(EventMachine::HttpRequest)
      
      @http_async ||= EventMachine::HttpRequest.new(@uri)

      request = Pusher::Request.new(@uri, event_name, data, socket_id)

      deferrable = EM::DefaultDeferrable.new
      
      http = @http_async.post({
        :query => request.query, :timeout => 2, :body => request.body
      })
      http.callback {
        begin
          handle_response(http.response_header.status, http.response.chomp)
          deferrable.succeed
        rescue => e
          deferrable.fail(e)
        end
      }
      http.errback {
        Pusher.logger.debug("Network error connecting to pusher: #{http.inspect}")
        deferrable.fail(Error.new("Network error connecting to pusher"))
      }
      
      deferrable
    end

    def trigger!(event_name, data, socket_id = nil)
      require 'net/http' unless defined?(Net::HTTP)

      @http_sync ||= Net::HTTP.new(@uri.host, @uri.port)

      request = Pusher::Request.new(@uri, event_name, data, socket_id)

      response = @http_sync.post("#{@uri.path}?#{request.query.to_params}",
        request.body, { 'Content-Type'=> 'application/json' })

      handle_response(response.code.to_i, response.body.chomp)
    end

    def trigger(event_name, data, socket_id = nil)
      trigger!(event_name, data, socket_id)
    rescue StandardError => e
      handle_error e
    end

    private

    def handle_error(e)
      Pusher.logger.error("#{e.message} (#{e.class})")
      Pusher.logger.debug(e.backtrace.join("\n"))
    end

    def handle_response(status_code, body)
      case status_code
      when 202
        return true
      when 400
        raise Error, "Bad request: #{body}"
      when 401
        raise AuthenticationError, body
      when 404
        raise Error, "Resource not found: app_id is probably invalid"
      else
        raise Error, "Unknown error in Pusher: #{body}"
      end
    end
  end
end
