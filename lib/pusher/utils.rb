module Pusher
  module Utils
    def validate_socket_id(socket_id)
      unless socket_id && /\A\d+\.\d+\z/.match(socket_id)
        raise Pusher::Error, "Invalid socket ID #{socket_id.inspect}"
      end
    end
  end
end
