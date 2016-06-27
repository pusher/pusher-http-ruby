module Pusher
  module NativeNotification
    class Client
      attr_reader :app_id, :host

      API_PREFIX = "customer_api"
      API_VERSION = "v1"

      def initialize(app_id, host, pusher_client)
        @app_id = app_id
        @host = host
        @pusher_client = pusher_client
      end

      # Send a notification via the native notifications API
      def notify(interests, data = {})
        Request.new(
          @pusher_client,
          :post,
          url("/notifications"),
          {},
          payload(interests, data)
        ).send_sync
      end

      private

      # TODO: Actual links
      #
      # {
      #   interests: [Array of interests],
      #   apns: {
      #     See https://pusher.com/docs/native_notifications/payloads#apns
      #   },
      #   gcm: {
      #     See https://pusher.com/docs/native_notifications/payloads#gcm
      #   }
      # }
      #
      # @raise [Pusher::Error] if the `apns` or `gcm` key does not exist
      # @return [String]
      def payload(interests, data)
        interests = Array(interests).map(&:to_s)

        payload = { interests: interests }

        unless (data.has_key?(:apns) || data.has_key?(:gcm))
          raise Pusher::Error, "GCM or APNS data must be provided"
        end

        payload.merge({ gcm: data[:gcm] }) if data.has_key?(:gcm)
        payload.merge({ apns: data[:apns] }) if data.has_key?(:apns)

        MultiJson.encode(payload)
      end

      def url(path = nil)
        URI.parse("https://#{@host}/#{API_PREFIX}/#{API_VERSION}/apps/#{@app_id}#{path}")
      end
    end
  end
end