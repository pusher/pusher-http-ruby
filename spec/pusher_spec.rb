require File.expand_path('../spec_helper', __FILE__)

require 'webmock/rspec'
require 'em-http'
require 'em-http/mock'

describe Pusher do
  describe 'configuration' do
    it 'should be preconfigured for api host' do
      Pusher.host.should == 'api.pusherapp.com'
    end

    it 'should be preconfigured for pi port 80' do
      Pusher.port.should == 80
    end

    it 'should use standard logger if no other logger if defined' do
      Pusher.logger.debug('foo')
      Pusher.logger.should be_kind_of(Logger)
    end

    it "can be configured to use any logger" do
      logger = mock("ALogger")
      logger.should_receive(:debug).with('foo')
      Pusher.logger = logger
      Pusher.logger.debug('foo')
      Pusher.logger = nil
    end
  end

  describe 'configured' do
    before do
      Pusher.app_id = '20'
      Pusher.key    = '12345678900000001'
      Pusher.secret = '12345678900000001'
    end

    after do
      Pusher.app_id = nil
      Pusher.key = nil
      Pusher.secret = nil
    end

    describe '.[]' do
      before do
        @channel = Pusher['test_channel']
      end

      it 'should return a new channel' do
        @channel.should be_kind_of(Pusher::Channel)
      end

      %w{app_id key secret}.each do |config|
        it "should raise exception if #{config} not configured" do
          Pusher.send("#{config}=", nil)
          lambda {
            Pusher['test_channel']
          }.should raise_error(ArgumentError)
        end
      end
    end

    describe 'Channel#trigger!' do
      before :each do
        WebMock.stub_request(
          :post, %r{/apps/20/channels/test_channel/events}
        ).to_return(:status => 202)
        @channel = Pusher['test_channel']
      end

      it 'should configure HTTP library to talk to pusher API' do
        @channel.trigger!('new_event', 'Some data')
        WebMock.request(:post, %r{api.pusherapp.com}).should have_been_made
      end

      it 'should POST with the correct parameters and convert data to JSON' do
        @channel.trigger!('new_event', {
          :name => 'Pusher',
          :last_name => 'App'
        })
        WebMock.request(:post, %r{/apps/20/channels/test_channel/events}).
        with do |req|

          query_hash = req.uri.query_values
          query_hash["name"].should == 'new_event'
          query_hash["auth_key"].should == Pusher.key
          query_hash["auth_timestamp"].should_not be_nil

          parsed = JSON.parse(req.body)
          parsed.should == {
            "name" => 'Pusher',
            "last_name" => 'App'
          }

          req.headers['Content-Type'].should == 'application/json'
        end.should have_been_made
      end

      it "should handle string data by sending unmodified in body" do
        string = "foo\nbar\""
        @channel.trigger!('new_event', string)
        WebMock.request(:post, %r{/apps/20/channels/test_channel/events}).with do |req|
          req.body.should == "foo\nbar\""
        end.should have_been_made
      end

      it "should raise error if an object sent which canot be JSONified" do
        lambda {
          @channel.trigger!('new_event', Object.new)
        }.should raise_error(JSON::GeneratorError)
      end

      it "should propagate exception if exception raised" do
        WebMock.stub_request(
          :post, %r{/apps/20/channels/test_channel/events}
        ).to_raise(RuntimeError)
        lambda {
          Pusher['test_channel'].trigger!('new_event', 'Some data')
        }.should raise_error(RuntimeError)
      end

      it "should raise AuthenticationError if pusher returns 401" do
        WebMock.stub_request(
          :post, 
          %r{/apps/20/channels/test_channel/events}
        ).to_return(:status => 401)
        lambda {
          Pusher['test_channel'].trigger!('new_event', 'Some data')
        }.should raise_error(Pusher::AuthenticationError)
      end

      it "should raise Pusher::Error if pusher returns 404" do
        WebMock.stub_request(
          :post, %r{/apps/20/channels/test_channel/events}
        ).to_return(:status => 404)
        lambda {
          Pusher['test_channel'].trigger!('new_event', 'Some data')
        }.should raise_error(Pusher::Error, 'Resource not found: app_id is probably invalid')
      end

      it "should raise Pusher::Error if pusher returns 500" do
        WebMock.stub_request(
          :post, %r{/apps/20/channels/test_channel/events}
        ).to_return(:status => 500, :body => "some error")
        lambda {
          Pusher['test_channel'].trigger!('new_event', 'Some data')
        }.should raise_error(Pusher::Error, 'Unknown error in Pusher: some error')
      end
    end

    describe 'Channel#trigger' do
      before :each do
        @http = mock('HTTP', :post => 'posting')
        Net::HTTP.stub!(:new).and_return @http
      end

      it "should log failure if exception raised" do
        @http.should_receive(:post).and_raise("Fail")
        Pusher.logger.should_receive(:error).with("Fail (RuntimeError)")
        Pusher.logger.should_receive(:debug) #backtrace
        Pusher['test_channel'].trigger('new_event', 'Some data')
      end

      it "should log failure if exception raised" do
        @http.should_receive(:post).and_raise("Fail")
        Pusher.logger.should_receive(:error).with("Fail (RuntimeError)")
        Pusher.logger.should_receive(:debug) #backtrace
        Pusher['test_channel'].trigger('new_event', 'Some data')
      end
    end

    describe "Channel#trigger_async" do
      #in order to match URLs when testing http requests
      #override the method that converts query hash to string
      #to include a sort so URL is consistent
      module EventMachine
        module HttpEncoding
                  def encode_query(path, query, uri_query)
            encoded_query = if query.kind_of?(Hash)
              query.sort{|a, b| a.to_s <=> b.to_s}.
              map { |k, v| encode_param(k, v) }.
              join('&')
            else
              query.to_s
            end
            if !uri_query.to_s.empty?
              encoded_query = [encoded_query, uri_query].reject {|part| part.empty?}.join("&")
            end
            return path if encoded_query.to_s.empty?
            "#{path}?#{encoded_query}"
          end
        end
      end
      
      before :each do
        EM::HttpRequest = EM::MockHttpRequest
        EM::HttpRequest.reset_registry!
        EM::HttpRequest.reset_counts!
        EM::HttpRequest.pass_through_requests = false
      end

      it "should return a deferrable which succeeds in success case" do
        # Yeah, mocking EM::MockHttpRequest isn't that feature rich :)
        Time.stub(:now).and_return(123)

        url = 'http://api.pusherapp.com:80/apps/20/channels/test_channel/events?auth_key=12345678900000001&auth_signature=0ffe2a3749f886ca69c3f516a30c7bc9a12d2ebd8bda5b718b90ad58507c8261&auth_timestamp=123&auth_version=1.0&body_md5=5b82f8bf4df2bfb0e66ccaa7306fd024&name=new_event'

        data = <<-RESPONSE.gsub(/^ +/, '')
          HTTP/1.1 202 Accepted
          Content-Type: text/html
          Content-Length: 13
          Connection: keep-alive
          Server: thin 1.2.7 codename No Hup

          202 ACCEPTED
        RESPONSE

        EM::HttpRequest.register(url, :post, data)

        EM.run {
          d = Pusher['test_channel'].trigger_async('new_event', 'Some data')
          d.callback {
            EM::HttpRequest.count(url, :post).should == 1
            EM.stop
          }
          d.errback {
            fail
            EM.stop
          }
        }
      end

      it "should return a deferrable which fails (with exception) in fail case" do
        # Yeah, mocking EM::MockHttpRequest isn't that feature rich :)
        Time.stub(:now).and_return(123)

        url = 'http://api.pusherapp.com:80/apps/20/channels/test_channel/events?auth_key=12345678900000001&auth_signature=0ffe2a3749f886ca69c3f516a30c7bc9a12d2ebd8bda5b718b90ad58507c8261&auth_timestamp=123&auth_version=1.0&body_md5=5b82f8bf4df2bfb0e66ccaa7306fd024&name=new_event'

        data = <<-RESPONSE.gsub(/^ +/, '')
          HTTP/1.1 401 Unauthorized
          Content-Type: text/html
          Content-Length: 130
          Connection: keep-alive
          Server: thin 1.2.7 codename No Hup

          401 UNAUTHORIZED: Timestamp expired: Given timestamp (2010-05-05T11:24:42Z) not within 600s of server time (2010-05-05T11:51:42Z)
        RESPONSE

        EM::HttpRequest.register(url, :post, data)

        EM.run {
          d = Pusher['test_channel'].trigger_async('new_event', 'Some data')
          d.callback {
            fail
          }
          d.errback { |error|
            EM::HttpRequest.count(url, :post).should == 1
            error.should be_kind_of(Pusher::AuthenticationError)
            EM.stop
          }
        }
      end
    end

    describe "Channel#socket_auth" do
      before :each do
        @channel = Pusher['test_channel']
      end

      it "should return an authentication string given a socket id" do
        auth = @channel.socket_auth('socketid')

        auth.should == '12345678900000001:827076f551e22451357939e4c7bb1200de29f921d5bf80b40d71668f9cd61c40'
      end

      it "should raise error if authentication is invalid" do
        [nil, ''].each do |invalid|
          lambda {
            @channel.socket_auth(invalid)
          }.should raise_error
        end
      end
    end
  end
end
