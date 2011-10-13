require 'spec_helper'

describe Pusher::Channel do
  before do
    Pusher.app_id = '20'
    Pusher.key    = '12345678900000001'
    Pusher.secret = '12345678900000001'
    Pusher.host = 'api.pusherapp.com'
    Pusher.port = 80
    Pusher.encrypted = false

    WebMock.reset!
    WebMock.disable_net_connect!

    @pusher_url_regexp = %r{/apps/20/channels/test_channel/events}
  end

  after do
    Pusher.app_id = nil
    Pusher.key = nil
    Pusher.secret = nil
  end

  describe 'trigger!' do
    before :each do
      WebMock.stub_request(:post, @pusher_url_regexp).
        to_return(:status => 202)
      @channel = Pusher['test_channel']
    end

    it 'should configure HTTP library to talk to pusher API' do
      @channel.trigger!('new_event', 'Some data')
      WebMock.should have_requested(:post, %r{http://api.pusherapp.com})
    end

    it "should POST to https api if ssl enabled" do
      Pusher.encrypted = true
      Pusher::Channel.new(Pusher.url, 'test_channel').trigger('new_event', 'Some data')
      WebMock.should have_requested(:post, %r{https://api.pusherapp.com})
    end

    it 'should POST hashes by encoding as JSON in the request body' do
      @channel.trigger!('new_event', {
        :name => 'Pusher',
        :last_name => 'App'
      })
      WebMock.should have_requested(:post, %r{/apps/20/channels/test_channel/events}).with do |req|
        query_hash = req.uri.query_values
        query_hash["name"].should == 'new_event'
        query_hash["auth_key"].should == Pusher.key
        query_hash["auth_timestamp"].should_not be_nil

        parsed = MultiJson.decode(req.body)
        parsed.should == {
          "name" => 'Pusher',
          "last_name" => 'App'
        }

        req.headers['Content-Type'].should == 'application/json'
      end
    end

    it "should POST string data unmodified in request body" do
      string = "foo\nbar\""
      @channel.trigger!('new_event', string)
      WebMock.should have_requested(:post, %r{/apps/20/channels/test_channel/events}).with do |req|
        req.body.should == "foo\nbar\""
      end
    end

    it "should catch all Net::HTTP exceptions and raise a Pusher::HTTPError, exposing the original error if required" do
      WebMock.stub_request(
        :post, %r{/apps/20/channels/test_channel/events}
      ).to_raise(Timeout::Error)

      error_raised = nil
      begin
        Pusher['test_channel'].trigger!('new_event', 'Some data')
      rescue => e
        error_raised = e
      end
      error_raised.class.should == Pusher::HTTPError
      error_raised.message.should == 'Exception from WebMock (Timeout::Error)'
      error_raised.original_error.class.should == Timeout::Error
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
      }.should raise_error(Pusher::Error, 'Unknown error (status code 500): some error')
    end
  end

  describe 'trigger' do
    it "should log failure if error raised in Net::HTTP call" do
      stub_request(:post, @pusher_url_regexp).to_raise(Net::HTTPBadResponse)
      Pusher.logger.should_receive(:error).with("Exception from WebMock (Net::HTTPBadResponse) (Pusher::HTTPError)")
      Pusher.logger.should_receive(:debug) #backtrace
      Pusher::Channel.new(Pusher.url, 'test_channel').trigger('new_event', 'Some data')
    end

    it "should log failure if Pusher returns an error response" do
      stub_request(:post, @pusher_url_regexp).to_return(:status => 401)
      # @http.should_receive(:post).and_raise(Net::HTTPBadResponse)
      Pusher.logger.should_receive(:error).with(" (Pusher::AuthenticationError)")
      Pusher.logger.should_receive(:debug) #backtrace
      Pusher::Channel.new(Pusher.url, 'test_channel').trigger('new_event', 'Some data')
    end
  end

  describe "trigger_async" do
    it "should by default POST to http api" do
      EM.run {
        stub_request(:post, @pusher_url_regexp).to_return(:status => 202)
        channel = Pusher::Channel.new(Pusher.url, 'test_channel')
        channel.trigger_async('new_event', 'Some data').callback {
          WebMock.should have_requested(:post, %r{http://api.pusherapp.com})
          EM.stop
        }
      }
    end

    it "should POST to https api if ssl enabled" do
      Pusher.encrypted = true
      EM.run {
        stub_request(:post, @pusher_url_regexp).to_return(:status => 202)
        channel = Pusher::Channel.new(Pusher.url, 'test_channel')
        channel.trigger_async('new_event', 'Some data').callback {
          WebMock.should have_requested(:post, %r{https://api.pusherapp.com})
          EM.stop
        }
      }
    end

    it "should return a deferrable which succeeds in success case" do
      stub_request(:post, @pusher_url_regexp).to_return(:status => 202)

      EM.run {
        d = Pusher['test_channel'].trigger_async('new_event', 'Some data')
        d.callback {
          WebMock.should have_requested(:post, @pusher_url_regexp)
          EM.stop
        }
        d.errback {
          fail
          EM.stop
        }
      }
    end

    it "should return a deferrable which fails (with exception) in fail case" do
      stub_request(:post, @pusher_url_regexp).to_return(:status => 401)

      EM.run {
        d = Pusher['test_channel'].trigger_async('new_event', 'Some data')
        d.callback {
          fail
        }
        d.errback { |error|
          WebMock.should have_requested(:post, @pusher_url_regexp)
          error.should be_kind_of(Pusher::AuthenticationError)
          EM.stop
        }
      }
    end
  end

  describe "stats" do
    before :each do
      @api_path = %r{/apps/20/channels/presence-test_channel/stats}
    end

    it "should call the user_count api" do
      WebMock.stub_request(:get, @api_path).to_return({
        :status => 200,
        :body => JSON.generate(:user_count => 1)
      })
      @channel = Pusher['presence-test_channel']

      @channel.stats.should == {
        :user_count => 1
      }
    end
  end

  describe "socket_auth" do
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

    describe 'with extra string argument' do

      it 'should be a string or nil' do
        lambda {
          @channel.socket_auth('socketid', 'boom')
        }.should_not raise_error

        lambda {
          @channel.socket_auth('socketid', 123)
        }.should raise_error

        lambda {
          @channel.socket_auth('socketid', nil)
        }.should_not raise_error

        lambda {
          @channel.socket_auth('socketid', {})
        }.should raise_error
      end

      it "should return an authentication string given a socket id and custom args" do
        auth = @channel.socket_auth('socketid', 'foobar')

        auth.should == "12345678900000001:#{HMAC::SHA256.hexdigest(Pusher.secret, "socketid:test_channel:foobar")}"
      end

    end
  end

  describe '#authenticate' do

    before :each do
      @channel = Pusher['test_channel']
      @custom_data = {:uid => 123, :info => {:name => 'Foo'}}
    end

    it 'should return a hash with signature including custom data and data as json string' do
      MultiJson.stub!(:encode).with(@custom_data).and_return 'a json string'

      response = @channel.authenticate('socketid', @custom_data)

      response.should == {
        :auth => "12345678900000001:#{HMAC::SHA256.hexdigest(Pusher.secret, "socketid:test_channel:a json string")}",
        :channel_data => 'a json string'
      }
    end
  end
end
