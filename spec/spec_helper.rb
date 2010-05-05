require 'rubygems'

require 'spec'
require 'spec/autorun'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'pusher'
require 'eventmachine'

Spec::Runner.configure do |config|
  
end
