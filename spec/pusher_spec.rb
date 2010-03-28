require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Pusher do
  
  describe 'configuration' do
    it 'should be preconfigured for api host' do
      Pusher.host.should == 'api.pusherapp.com'
    end
    
    it 'should be preconfigured for pi port 80' do
      Pusher.port.should == 80
    end
  end
  
  describe 'unconfigured' do
    describe 'with missing key and secret' do
      it 'should raise exception' do
        lambda {
          Pusher['test-channel']
        }.should raise_error(Pusher::ArgumentError)
      end
    end

    describe 'with missing key' do
      before {Pusher.secret = '1234567890'}
      it 'should raise exception' do
        lambda {
          Pusher['test-channel']
        }.should raise_error(Pusher::ArgumentError)
      end
    end

    describe 'with missing secret' do
      before {Pusher.key = '1234567890'}
      it 'should raise exception' do
        lambda {
          Pusher['test-channel']
        }.should raise_error(Pusher::ArgumentError)
      end
    end
  end
  
  
  describe 'configured' do
    before do
      Pusher.key    = '12345678900000001'
      Pusher.secret = '12345678900000001'
    end
    
    describe '.[]' do
      before do
        @channel = Pusher['test_channel']
      end
      
      it 'should return a new channel' do
        @channel.should be_kind_of(Pusher::Channel)
      end
    end
    
    describe 'calling Channel#trigger' do

      before do
        @http = mock('HTTP', :post => 'posting')
        Net::HTTP.stub!(:new).and_return @http
      end

      it 'should configure HTTP library to talk to pusher API' do
        Net::HTTP.should_receive(:new).with('api.pusherapp.com', 80).and_return @http
        Pusher['test_channel'].trigger(
          'new_event',
          'Some data'
        )
      end
      
      describe 'POSTing to api.pusherapp.com' do
        
        it 'should POST JSON to p# usher API' do
          @http.should_receive(:post) do |*args|
            args[0].should == '/app/12345678900000001/channel/test_channel'
            parsed = JSON.parse(args[1])
            parsed['event'].should == 'new_event' 
            parsed['data']['name'].should == 'Pusher'
            parsed['data']['last_name'].should == 'App'
            parsed['socket_id'].should == nil
            args[2].should == {'Content-Type'=> 'application/json'}
          end
          Pusher['test_channel'].trigger(
            'new_event',
            :name => 'Pusher',
            :last_name => 'App'
          )
        end
      end
    end
    
  end
  
  after do
    Pusher.key = nil
    Pusher.secret = nil
  end
end
