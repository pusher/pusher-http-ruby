require 'json'

module Pusher
  module JSON
    
    def self.generate(data)
      if Object.const_defined?('ActiveSupport')
        ActiveSupport::JSON.encode(data)
      else
        ::JSON.generate(data)
      end
    end
    
  end
end