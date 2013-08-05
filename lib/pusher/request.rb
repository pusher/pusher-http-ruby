require 'signature'
require 'digest/md5'
require 'multi_json'

module Pusher
  class Request
    attr_reader :body, :params

    def initialize(client, verb, uri, params, body = nil)
      @client, @verb, @uri = client, verb, uri
      @head = {}

      if body
        @body = body
        params[:body_md5] = Digest::MD5.hexdigest(body)
        @head['Content-Type'] = 'application/json'
      end

      request = Signature::Request.new(verb.to_s.upcase, uri.path, params)
      request.sign(client.authentication_token)
      @params = request.signed_params
    end

    def send_sync
      http = @client.sync_http_client

      begin
        response = http.request(@verb, @uri, @params, @body, @head)
      rescue HTTPClient::BadResponseError, HTTPClient::TimeoutError,
             SocketError => e
        error = Pusher::HTTPError.new("#{e.message} (#{e.class})")
        error.original_error = e
        raise error
      end

      body = response.body ? response.body.chomp : nil

      return handle_response(response.code.to_i, body)
    end

    def send_async
      http_client = @client.em_http_client(@uri)
      df = EM::DefaultDeferrable.new

      http = case @verb
      when :post
        http_client.post({
          :query => @params, :timeout => 5, :body => @body, :head => @head
        })
      when :get
        http_client.get({
          :query => @params, :timeout => 5, :head => @head
        })
      else
        raise "Unsuported verb"
      end
      http.callback {
        begin
          df.succeed(handle_response(http.response_header.status, http.response.chomp))
        rescue => e
          df.fail(e)
        end
      }
      http.errback {
        Pusher.logger.debug("Network error connecting to pusher: #{http.inspect}")
        df.fail(Error.new("Network error connecting to pusher"))
      }

      df
    end

    private

    def handle_response(status_code, body)
      case status_code
      when 200
        return symbolize_first_level(MultiJson.decode(body))
      when 202
        return true
      when 400
        raise Error, "Bad request: #{body}"
      when 401
        raise AuthenticationError, body
      when 404
        raise Error, "404 Not found (#{@uri.path})"
      when 407
        raise Error, "Proxy Authentication Required"
      else
        raise Error, "Unknown error (status code #{status_code}): #{body}"
      end
    end

    def symbolize_first_level(hash)
      hash.inject({}) do |result, (key, value)|
        result[key.to_sym] = value
        result
      end
    end
  end
end
