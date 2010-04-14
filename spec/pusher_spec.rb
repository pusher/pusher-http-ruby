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
    end

    it 'should raise exception if key and secret are missing' do
      lambda {
        Pusher['test-channel']
      }.should raise_error(Pusher::ArgumentError)
    end

    it 'should raise exception if key is missing' do
      lambda {
        Pusher['test-channel']
      }.should raise_error(Pusher::ArgumentError)
    end
  end

  describe 'configured' do
    before do
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
      before do
        @http = mock('HTTP', :post => 'posting')
        Net::HTTP.stub!(:new).and_return @http
      end

      it 'should configure HTTP library to talk to pusher API' do
        Net::HTTP.should_receive(:new).
          with('api.pusherapp.com', 80).and_return @http
        Pusher['test_channel'].trigger('new_event', 'Some data')
      end

      it 'should POST JSON to pusher API' do
        @http.should_receive(:post) do |path, data, headers|
          path.should == '/app/12345678900000001/channel/test_channel'
          parsed = JSON.parse(data)
          parsed['event'].should == 'new_event'
          parsed['data']['name'].should == 'Pusher'
          parsed['data']['last_name'].should == 'App'
          parsed['socket_id'].should == nil
          headers.should == {'Content-Type'=> 'application/json'}
        end
        Pusher['test_channel'].trigger('new_event', {
          :name => 'Pusher',
          :last_name => 'App'
        })
      end
    end
  end
end
