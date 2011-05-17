module Pusher
  module HashExt#:nodoc:
    # @return <String> This hash as a query string
    #
    # @example
    #   { :name => "Bob",
    #     :address => {
    #       :street => '111 Ruby Ave.',
    #       :city => 'Ruby Central',
    #       :phones => ['111-111-1111', '222-222-2222']
    #     }
    #   }.to_params
    #     #=> "name=Bob&address[city]=Ruby Central&address[phones][]=111-111-1111&address[phones][]=222-222-2222&address[street]=111 Ruby Ave."
    def to_params
      params = self.map { |k,v| normalize_param(k,v) }.join
      params.chop! # trailing &
      params
    end

    # @param key<Object> The key for the param.
    # @param value<Object> The value for the param.
    #
    # @return <String> This key value pair as a param
    #
    # @example normalize_param(:name, "Bob Jones") #=> "name=Bob%20Jones&"
    def normalize_param(key, value)
      param = ''
      stack = []

      if value.is_a?(Array)
        param << value.map { |element| normalize_param("#{key}[]", element) }.join
      elsif value.is_a?(Hash)
        stack << [key,value]
      else
        param << "#{key}=#{URI.encode(value.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&"
      end

      stack.each do |parent, hash|
        hash.each do |key, value|
          if value.is_a?(Hash)
            stack << ["#{parent}[#{key}]", value]
          else
            param << normalize_param("#{parent}[#{key}]", value)
          end
        end
      end

      param
    end

    # @return <String> The hash as attributes for an XML tag.
    #
    # @example
    #   { :one => 1, "two"=>"TWO" }.to_xml_attributes
    #     #=> 'one="1" two="TWO"'
    def to_xml_attributes
      map do |k,v|
        %{#{k.to_s.snake_case.sub(/^(.{1,1})/) { |m| m.downcase }}="#{v}"}
      end.join(' ')
    end
  end
end

Hash.send :include, Pusher::HashExt