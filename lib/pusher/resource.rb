module Pusher
  class Resource
    def initialize(client, path)
      @client = client
      @path = path
    end

    def get(params)
      Request.new(:get, @client.url(@path), params, nil, nil, @client).send_sync
    end

    def get_async(params)
      Request.new(:get, @client.url(@path), params, nil, nil, @client).send_async
    end

    def post(params)
      body = MultiJson.encode(params)
      Request.new(:post, @client.url(@path), {}, body, nil, @client).send_sync
    end

    def post_async(params)
      body = MultiJson.encode(params)
      Request.new(:post, @client.url(@path), {}, body, nil, @client).send_async
    end
  end
end
