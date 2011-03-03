require 'signature'
require 'digest/md5'
require 'multi_json'

module Pusher
  class Request
    attr_reader :body, :query

    def initialize(resource, event_name, data, socket_id, token = nil)
      params = {
        :name => event_name,
      }
      params[:socket_id] = socket_id if socket_id

      @body = case data
      when String
        data
      else
        begin
          MultiJson.encode(data)
        rescue MultiJson::DecodeError => e
          Pusher.logger.error("Could not convert #{data.inspect} into JSON")
          raise e
        end
      end
      params[:body_md5] = Digest::MD5.hexdigest(body)

      request = Signature::Request.new('POST', resource.path, params)
      auth_hash = request.sign(token || Pusher.authentication_token)

      @query = params.merge(auth_hash)
    end

  end
end
