# -*- encoding: utf-8 -*-

require File.expand_path('../lib/pusher/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = "pusher"
  s.version     = Pusher::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Pusher"]
  s.email       = ["support@pusher.com"]
  s.homepage    = "http://github.com/pusher/pusher-http-ruby"
  s.summary     = %q{Pusher Channels API client}
  s.description = %q{Wrapper for Pusher Channels REST api: : https://pusher.com/channels}
  s.license     = "MIT"

  s.add_dependency "multi_json", "~> 1.15"
  s.add_dependency 'pusher-signature', "~> 0.1.8"
  s.add_dependency "httpclient", "~> 2.8"
  s.add_dependency "jruby-openssl" if defined?(JRUBY_VERSION)
  s.add_dependency "rbnacl", "~> 7.1"

  s.add_development_dependency "rspec", "~> 3.9"
  s.add_development_dependency "webmock", "~> 3.9"
  s.add_development_dependency "em-http-request", "~> 1.1"
  s.add_development_dependency "addressable", "~> 2.7"
  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rack", "~> 2.2"
  s.add_development_dependency "json", "~> 2.3"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
