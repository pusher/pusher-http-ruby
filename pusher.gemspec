# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "pusher"
  s.version     = "0.6.0"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["New Bamboo"]
  s.email       = ["support@pusherapp.com"]
  s.homepage    = "http://github.com/newbamboo/pusher-gem"
  s.summary     = %q{Pusherapp client}
  s.description = %q{Wrapper for pusherapp.com REST api}

  s.rubyforge_project = "foobar"
  
  s.add_dependency "json"
  s.add_dependency "crack"
  s.add_dependency "ruby-hmac"
  s.add_dependency 'signature'
  
  s.add_development_dependency "rspec", ">= 1.2.9"
  s.add_development_dependency "webmock"
  s.add_development_dependency "em-http-request", '0.2.7'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
