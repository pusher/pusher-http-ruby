module Pusher
  # Query string encoding extracted with thanks from em-http-request
  module QueryEncoder
    def encode_query(uri, query)
      encoded_query = if query.kind_of?(Hash)
        query.map { |k, v| encode_param(k, v) }.join('&')
      else
        query.to_s
      end

      if uri && !uri.query.to_s.empty?
        encoded_query = [encoded_query, uri.query].reject {|part| part.empty?}.join("&")
      end
      encoded_query.to_s.empty? ? uri.path : "#{uri.path}?#{encoded_query}"
    end

    # URL encodes query parameters:
    # single k=v, or a URL encoded array, if v is an array of values
    def encode_param(k, v)
      if v.is_a?(Array)
        v.map { |e| escape(k) + "[]=" + escape(e) }.join("&")
      else
        escape(k) + "=" + escape(v)
      end
    end

    def escape(s)
      if defined?(EscapeUtils)
        EscapeUtils.escape_url(s.to_s)
      else
        s.to_s.gsub(/([^a-zA-Z0-9_.-]+)/n) {
          '%'+$1.unpack('H2'*bytesize($1)).join('%').upcase
        }
      end
    end

    if ''.respond_to?(:bytesize)
      def bytesize(string)
        string.bytesize
      end
    else
      def bytesize(string)
        string.size
      end
    end
  end
end
