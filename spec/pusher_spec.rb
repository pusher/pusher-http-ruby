require File.expand_path('../spec_helper', __FILE__)

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

    it 'should raise exception if key and secret are missing' do
      lambda {
        Pusher['test-channel']
      }.should raise_error(ArgumentError)
    end

    it 'should raise exception if key is missing' do
      lambda {
        Pusher['test-channel']
      }.should raise_error(ArgumentError)
    end
  end

  describe 'configured' do
    before do
      Pusher.app_id = '20'
      Pusher.key    = '12345678900000001'
      Pusher.secret = '12345678900000001'
    end

    after do
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
    end

    describe 'Channel#trigger' do
      before :each do
        @http = mock('HTTP', :post => 'posting')
        Net::HTTP.stub!(:new).and_return @http
      end

      it 'should configure HTTP library to talk to pusher API' do
        Net::HTTP.should_receive(:new).
          with('api.pusherapp.com', 80).and_return @http
        Pusher['test_channel'].trigger('new_event', 'Some data')
      end

      it 'should POST JSON to pusher API' do
        @http.should_receive(:post) do |url, data, headers|
          path, query = url.split('?')
          path.should == '/app/20/channel/test_channel/event'

          query_hash = Hash[*query.split(/&|=/)]
          query_hash["name"].should == 'new_event'
          query_hash["auth_key"].should == Pusher.key
          query_hash["auth_timestamp"].should_not be_nil

          parsed = JSON.parse(data)
          parsed.should == {
            "name" => 'Pusher',
            "last_name" => 'App'
          }
          headers.should == {'Content-Type'=> 'application/json'}
        end
        Pusher['test_channel'].trigger('new_event', {
          :name => 'Pusher',
          :last_name => 'App'
        })
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
