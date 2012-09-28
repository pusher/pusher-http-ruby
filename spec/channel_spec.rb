require 'spec_helper'

describe Pusher::Channel do
  before do
    @client = Pusher::Client.new({
      :app_id => '20',
      :key => '12345678900000001',
      :secret => '12345678900000001',
      :host => 'api.pusherapp.com',
      :port => 80,
    })
    @client.encrypted = false

    WebMock.reset!
    WebMock.disable_net_connect!

  end

  let(:pusher_url_regexp) { %r{/apps/20/channels/test_channel/events} }

  def stub_post(status, body = nil)
    options = {:status => status}
    options.merge!({:body => body}) if body

    WebMock.stub_request(:post, pusher_url_regexp).to_return(options)
  end

  def stub_post_to_raise(e)
    WebMock.stub_request(:post, pusher_url_regexp).to_raise(e)
  end

  describe 'trigger!' do
    before :each do
      stub_post 202
      @channel = @client['test_channel']
    end

    it 'should configure HTTP library to talk to pusher API' do
      @channel.trigger!('new_event', 'Some data')
      WebMock.should have_requested(:post, %r{http://api.pusherapp.com})
    end

    it "should POST to https api if ssl enabled" do
      @client.encrypted = true
      encrypted_channel = Pusher::Channel.new(@client.url, 'test_channel', @client)
      encrypted_channel.trigger('new_event', 'Some data')
      WebMock.should have_requested(:post, %r{https://api.pusherapp.com})
    end

    it 'should POST hashes by encoding as JSON in the request body' do
      @channel.trigger!('new_event', {
        :name => 'Pusher',
        :last_name => 'App'
      })
      WebMock.should have_requested(:post, pusher_url_regexp).with { |req|
        query_hash = req.uri.query_values
        query_hash["name"].should == 'new_event'
        query_hash["auth_key"].should == @client.key
        query_hash["auth_timestamp"].should_not be_nil

        parsed = MultiJson.decode(req.body)
        parsed.should == {
          "name" => 'Pusher',
          "last_name" => 'App'
        }

        req.headers['Content-Type'].should == 'application/json'
      }
    end

    it "should POST string data unmodified in request body" do
      string = "foo\nbar\""
      @channel.trigger!('new_event', string)
      WebMock.should have_requested(:post, pusher_url_regexp).with { |req| req.body.should == "foo\nbar\"" }
    end

    def trigger
      lambda { @client['test_channel'].trigger!('new_event', 'Some data') }
    end

    it "should catch all Net::HTTP exceptions and raise a Pusher::HTTPError, exposing the original error if required" do
      stub_post_to_raise Timeout::Error
      error_raised = nil

      begin
        trigger.call
      rescue => e
        error_raised = e
      end

      error_raised.class.should == Pusher::HTTPError
      error_raised.message.should == 'Exception from WebMock (Timeout::Error)'
      error_raised.original_error.class.should == Timeout::Error
    end


    it "should raise Pusher::Error if pusher returns 400" do
      stub_post 400
      trigger.should raise_error(Pusher::Error)
    end

    it "should raise AuthenticationError if pusher returns 401" do
      stub_post 401
      trigger.should raise_error(Pusher::AuthenticationError)
    end

    it "should raise Pusher::Error if pusher returns 404" do
      stub_post 404
      trigger.should raise_error(Pusher::Error, 'Resource not found: app_id is probably invalid')
    end

    it "should raise Pusher::Error if pusher returns 500" do
      stub_post 500, "some error"
      trigger.should raise_error(Pusher::Error, 'Unknown error (status code 500): some error')
    end
  end

  describe 'trigger' do
    it "should log failure if error raised in Net::HTTP call" do
      stub_post_to_raise(Net::HTTPBadResponse)

      Pusher.logger.should_receive(:error).with("Exception from WebMock (Net::HTTPBadResponse) (Pusher::HTTPError)")
      Pusher.logger.should_receive(:debug) #backtrace
      channel = Pusher::Channel.new(@client.url, 'test_channel', @client)
      channel.trigger('new_event', 'Some data')
    end

    it "should log failure if Pusher returns an error response" do
      stub_post 401
      # @http.should_receive(:post).and_raise(Net::HTTPBadResponse)
      Pusher.logger.should_receive(:error).with("Pusher::AuthenticationError (Pusher::AuthenticationError)")
      Pusher.logger.should_receive(:debug) #backtrace
      channel = Pusher::Channel.new(@client.url, 'test_channel', @client)
      channel.trigger('new_event', 'Some data')
    end
  end

  describe "trigger_async" do
    it "should by default POST to http api" do
      EM.run {
        stub_post 202
        channel = Pusher::Channel.new(@client.url, 'test_channel', @client)
        channel.trigger_async('new_event', 'Some data').callback {
          WebMock.should have_requested(:post, %r{http://api.pusherapp.com})
          EM.stop
        }
      }
    end

    it "should POST to https api if ssl enabled" do
      @client.encrypted = true
      EM.run {
        stub_post 202
        channel = Pusher::Channel.new(@client.url, 'test_channel', @client)
        channel.trigger_async('new_event', 'Some data').callback {
          WebMock.should have_requested(:post, %r{https://api.pusherapp.com})
          EM.stop
        }
      }
    end

    it "should return a deferrable which succeeds in success case" do
      stub_post 202

      EM.run {
        d = @client['test_channel'].trigger_async('new_event', 'Some data')
        d.callback {
          WebMock.should have_requested(:post, pusher_url_regexp)
          EM.stop
        }
        d.errback {
          fail
          EM.stop
        }
      }
    end

    it "should return a deferrable which fails (with exception) in fail case" do
      stub_post 401

      EM.run {
        d = @client['test_channel'].trigger_async('new_event', 'Some data')
        d.callback {
          fail
        }
        d.errback { |error|
          WebMock.should have_requested(:post, pusher_url_regexp)
          error.should be_kind_of(Pusher::AuthenticationError)
          EM.stop
        }
      }
    end
  end

  describe '#info' do
    it "should call the Client#channel_info" do
      @client.should_receive(:channel_info).with('mychannel', anything)
      @channel = @client['mychannel']
      @channel.info
    end

    it "should assemble the requested attribes into the info option" do
      @client.should_receive(:channel_info).with(anything, {
        :info => "user_count,connection_count"
      })
      @channel = @client['presence-foo']
      @channel.info(%w{user_count connection_count})
    end
  end

  describe "authentication_string" do
    before :each do
      @channel = @client['test_channel']
    end

    def authentication_string(*data)
      lambda { @channel.authentication_string(*data) }
    end

    it "should return an authentication string given a socket id" do
      auth = @channel.authentication_string('socketid')

      auth.should == '12345678900000001:827076f551e22451357939e4c7bb1200de29f921d5bf80b40d71668f9cd61c40'
    end

    it "should raise error if authentication is invalid" do
      [nil, ''].each do |invalid|
        authentication_string(invalid).should raise_error Pusher::Error
      end
    end

    describe 'with extra string argument' do

      it 'should be a string or nil' do
        authentication_string('socketid', 123)   .should     raise_error Pusher::Error
        authentication_string('socketid', {})    .should     raise_error Pusher::Error

        authentication_string('socketid', 'boom').should_not raise_error
        authentication_string('socketid', nil)   .should_not raise_error
      end

      it "should return an authentication string given a socket id and custom args" do
        auth = @channel.authentication_string('socketid', 'foobar')

        auth.should == "12345678900000001:#{hmac(@client.secret, "socketid:test_channel:foobar")}"
      end

    end
  end

  describe '#authenticate' do

    before :each do
      @channel = @client['test_channel']
      @custom_data = {:uid => 123, :info => {:name => 'Foo'}}
    end

    it 'should return a hash with signature including custom data and data as json string' do
      MultiJson.stub!(:encode).with(@custom_data).and_return 'a json string'

      response = @channel.authenticate('socketid', @custom_data)

      response.should == {
        :auth => "12345678900000001:#{hmac(@client.secret, "socketid:test_channel:a json string")}",
        :channel_data => 'a json string'
      }
    end
  end
end
