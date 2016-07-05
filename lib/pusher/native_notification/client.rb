module Pusher
  module NativeNotification
    class Client
      attr_reader :app_id, :host

      API_PREFIX = "customer_api"
      API_VERSION = "v1"
      GCM_TTL = 241920
      RESTRICTED_GCM_PAYLOAD_KEYS = [:to, :registration_ids]
      WEBHOOK_LEVELS = ["DEBUG", "INFO"]

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

        raise Pusher::Error, "Too many interests provided" if interests.length > 1

        payload = { interests: interests }

        data = deep_symbolize_keys!(data)
        validate_payload(data)

        payload.merge!({ gcm: data[:gcm] }) if data.has_key?(:gcm)
        payload.merge!({ apns: data[:apns] }) if data.has_key?(:apns)

        MultiJson.encode(payload)
      end

      def url(path = nil)
        URI.parse("https://#{@host}/#{API_PREFIX}/#{API_VERSION}/apps/#{@app_id}#{path}")
      end

      # Validate payload
      # `time_to_live` -> value b/w 0 and 241920
      # If the `notification` key is provided, ensure
      # that there is an accompanying `title` and `icon`
      # field
      def validate_payload(payload)
        # Restricted keys
        RESTRICTED_GCM_PAYLOAD_KEYS.each { |k| payload.delete(k) }

        unless (payload.has_key?(:apns) || payload.has_key?(:gcm))
          raise Pusher::Error, "GCM or APNS data must be provided"
        end

        if (gcm_payload = payload[:gcm])
          if (ttl = gcm_payload[:time_to_live])

            if ttl.to_i < 0 || ttl.to_i > GCM_TTL
              raise Pusher::Error, "Time to live must be between 0 and 241920 (4 weeks)"
            end
          end

          # If the notification key is provided
          # validate the `icon` and `title`keys
          if (notification = gcm_payload[:notification])
            notification_title, notification_icon = notification.values_at(:title, :icon)

            if (!notification_title || notification_title.empty?)
              raise Pusher::Error, "Notification title is a required field"
            end

            if (!notification_icon || notification_icon.empty?)
              raise Pusher::Error, "Notification icon is a required field"
            end
          end
        end

        if (webhook_url = payload[:webhook_url])
          raise Pusher::Error, "Webhook url is invalid" unless webhook_url =~ /\A#{URI::regexp(['http', 'https'])}\z/
        end

        if (webhook_level = payload[:webhook_level])
          raise Pusher::Error, "Webhook level cannot be used without a webhook url" if !payload.has_key?(:webhook_url)

          unless WEBHOOK_LEVELS.includes?(webhook_level.upcase)
            raise Pusher::Error, "Webhook level must either be INFO or DEBUG"
          end
        end
      end

      # Symbolize all keys in the hash recursively
      def deep_symbolize_keys!(hash)
        hash.keys.each do |k|
          ks = k.respond_to?(:to_sym) ? k.to_sym : k
          hash[ks] = hash.delete(k)
          deep_symbolize_keys!(hash[ks]) if hash[ks].kind_of?(Hash)
        end

        hash
      end
    end
  end
end