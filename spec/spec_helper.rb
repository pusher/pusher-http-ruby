$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'pusher'
require 'webmock/rspec'
require 'spec'
require 'spec/autorun'

include WebMock
Spec::Runner.configure do |config|
  
end
