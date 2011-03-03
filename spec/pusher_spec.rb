require 'spec_helper'

require 'em-http'

describe Pusher do
  describe 'configuration' do
    it 'should be preconfigured for api host' do
      Pusher.host.should == 'api.pusherapp.com'
    end

    it 'should be preconfigured for port 80' do
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

  describe "configuration using url" do
    after do
      Pusher.app_id = nil
      Pusher.key = nil
      Pusher.secret = nil
      Pusher.host = 'api.pusherapp.com'
      Pusher.port = 80
    end

    it "should be possible to configure everything by setting the url" do
      Pusher.url = "http://somekey:somesecret@api.staging.pusherapp.com:8080/apps/87"

      Pusher.host.should == 'api.staging.pusherapp.com'
      Pusher.port.should == 8080
      Pusher.key.should == 'somekey'
      Pusher.secret.should == 'somesecret'
      Pusher.app_id.should == '87'
    end
  end

  describe 'when configured' do
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

      it 'should return a channel' do
        @channel.should be_kind_of(Pusher::Channel)
      end

      it "should reuse the same channel objects" do
        channel1, channel2 = Pusher['test_channel'], Pusher['test_channel']

        channel1.object_id.should == channel2.object_id
      end

      %w{app_id key secret}.each do |config|
        it "should raise exception if #{config} not configured" do
          Pusher.send("#{config}=", nil)
          lambda {
            Pusher['test_channel']
          }.should raise_error(Pusher::ConfigurationError)
        end
      end
    end
  end
end
