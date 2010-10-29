require 'rubygems'

require 'rspec'
require 'rspec/autorun'
require 'em-http' # As of webmock 1.4.0, em-http must be loaded first
require 'webmock/rspec'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'pusher'
require 'eventmachine'

RSpec.configure do |config|
  config.include WebMock::API
end
