require 'signature'
require 'digest/md5'
require 'multi_json'

module Pusher
  class Request
    def initialize(verb, uri, params, body = nil, token = nil)
      @verb = verb
      @uri = uri

      if body
        @body = body
        params[:body_md5] = Digest::MD5.hexdigest(body)
      end

      request = Signature::Request.new(verb.to_s.upcase, uri.path, params)
      auth_hash = request.sign(token || Pusher.authentication_token)
      @params = params.merge(auth_hash)
    end

    def send_sync
      require 'net/http' unless defined?(Net::HTTP)
      require 'net/https' if (ssl? && !defined?(Net::HTTPS))

      @http_sync ||= begin
        http = Net::HTTP.new(@uri.host, @uri.port)
        http.use_ssl = true if ssl?
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if ssl?
        http
      end

      begin
        case @verb
        when :post
          response = @http_sync.post("#{@uri.path}?#{@params.to_params}",
            @body, { 'Content-Type'=> 'application/json' })
        when :get
          response = @http_sync.get("#{@uri.path}?#{@params.to_params}",
            { 'Content-Type'=> 'application/json' })
        else
          raise "Unknown verb"
        end
      rescue Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED,
             Errno::ETIMEDOUT, Errno::EHOSTUNREACH, Errno::ECONNRESET,
             Timeout::Error, EOFError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
             Net::ProtocolError => e
        error = Pusher::HTTPError.new("#{e.message} (#{e.class})")
        error.original_error = e
        raise error
      end

      return handle_response(response.code.to_i, response.body.chomp)
    end

    def send_async
      unless defined?(EventMachine) && EventMachine.reactor_running?
        raise Error, "In order to use trigger_async you must be running inside an eventmachine loop"
      end
      require 'em-http' unless defined?(EventMachine::HttpRequest)

      deferrable = EM::DefaultDeferrable.new

      http = EventMachine::HttpRequest.new(@uri).post({
        :query => @params, :timeout => 5, :body => @body,
        :head => {'Content-Type'=> 'application/json'}
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

    private

    def handle_response(status_code, body)
      case status_code
      when 200
        return MultiJson.decode(body, :symbolize_keys => true)
      when 202
        return true
      when 400
        raise Error, "Bad request: #{body}"
      when 401
        raise AuthenticationError, body
      when 404
        raise Error, "Resource not found: app_id is probably invalid"
      else
        raise Error, "Unknown error (status code #{status_code}): #{body}"
      end
    end

    def ssl?
      @uri.scheme == 'https'
    end
  end
end
