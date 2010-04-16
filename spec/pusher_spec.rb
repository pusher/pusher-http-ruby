require File.expand_path('../spec_helper', __FILE__)

require 'webmock/rspec'

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
        WebMock.stub_request(:post, %r{/app/20/channel/test_channel/event})
      end

      it 'should configure HTTP library to talk to pusher API' do
        Pusher['test_channel'].trigger('new_event', 'Some data')
        WebMock.request(:post, %r{api.pusherapp.com}).should have_been_made
      end

      it 'should POST JSON to pusher API' do
        Pusher['test_channel'].trigger('new_event', {
                                         :name => 'Pusher',
                                         :last_name => 'App'
        })
        WebMock.request(:post, %r{/app/20/channel/test_channel/event}).
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

      it "should propagate exception if exception raised" do
        WebMock.stub_request(:post, %r{/app/20/channel/test_channel/event}).
          to_raise(RuntimeError)
        lambda {
          Pusher['test_channel'].trigger!('new_event', 'Some data')
        }.should raise_error(RuntimeError)
      end

      it "should raise AuthenticationError if pusher returns 401" do
        WebMock.stub_request(:post, %r{/app/20/channel/test_channel/event}).
          to_return(:status => 401)
        lambda {
          Pusher['test_channel'].trigger!('new_event', 'Some data')
        }.should raise_error(Pusher::AuthenticationError)
      end

      it "should raise Pusher::Error if pusher returns 404" do
        WebMock.stub_request(:post, %r{/app/20/channel/test_channel/event}).
          to_return(:status => 404)
        lambda {
          Pusher['test_channel'].trigger!('new_event', 'Some data')
        }.should raise_error(Pusher::Error, 'Resource not found: app_id is probably invalid')
      end

      it "should raise Pusher::Error if pusher returns 500" do
        WebMock.stub_request(:post, %r{/app/20/channel/test_channel/event}).
          to_return(:status => 500, :body => "some error")
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
    end
  end
end
