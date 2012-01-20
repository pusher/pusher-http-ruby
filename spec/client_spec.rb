require 'spec_helper'

require 'em-http'

describe Pusher do
  [lambda { Pusher }, lambda { Pusher::Client.new }].each do |client_gen|
    before :each do
      @client = client_gen.call
    end

    describe 'default configuration' do
      it 'should be preconfigured for api host' do
        @client.host.should == 'api.pusherapp.com'
      end

      it 'should be preconfigured for port 80' do
        @client.port.should == 80
      end

      it 'should use standard logger if no other logger if defined' do
        @client.logger.debug('foo')
        @client.logger.should be_kind_of(Logger)
      end
    end

    describe 'logging configuration' do
      it "can be configured to use any logger" do
        logger = mock("ALogger")
        logger.should_receive(:debug).with('foo')
        @client.logger = logger
        @client.logger.debug('foo')
        @client.logger = nil
      end
    end

    describe "configuration using url" do
      it "should be possible to configure everything by setting the url" do
        @client.url = "http://somekey:somesecret@api.staging.pusherapp.com:8080/apps/87"

        @client.host.should == 'api.staging.pusherapp.com'
        @client.port.should == 8080
        @client.key.should == 'somekey'
        @client.secret.should == 'somesecret'
        @client.app_id.should == '87'
      end
    end

    describe 'when configured' do
      before :each do
        @client.app_id = '20'
        @client.key    = '12345678900000001'
        @client.secret = '12345678900000001'
      end

      describe '.[]' do
        before do
          @channel = @client['test_channel']
        end

        it 'should return a channel' do
          @channel.should be_kind_of(Pusher::Channel)
        end

        it "should reuse the same channel objects" do
          channel1, channel2 = @client['test_channel'], @client['test_channel']

          channel1.object_id.should == channel2.object_id
        end

        %w{app_id key secret}.each do |config|
          it "should raise exception if #{config} not configured" do
            @client.send("#{config}=", nil)
            lambda {
              @client['test_channel']
            }.should raise_error(Pusher::ConfigurationError)
          end
        end
      end
    end
  end
end
