# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "pusher"
  s.version     = "0.8.4"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Pusher"]
  s.email       = ["support@pusher.com"]
  s.homepage    = "http://github.com/pusher/pusher-gem"
  s.summary     = %q{Pusher API client}
  s.description = %q{Wrapper for pusher.com REST api}

  s.add_dependency "multi_json", "~> 1.0"
  s.add_dependency "crack",     "~> 0.1.0"
  s.add_dependency "ruby-hmac", "~> 0.4.0"
  s.add_dependency 'signature', "~> 0.1.2"

  s.add_development_dependency "rspec", "~> 2.0"
  s.add_development_dependency "webmock"
  s.add_development_dependency "em-http-request", "~> 1.0.0"
  s.add_development_dependency "rake"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
