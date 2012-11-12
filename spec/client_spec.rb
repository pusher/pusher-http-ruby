require 'spec_helper'

require 'em-http'

describe Pusher do
  describe 'using multiple Client objects' do
    before :each do
      @client1 = Pusher::Client.new
      @client2 = Pusher::Client.new

      @client1.scheme = 'ws'
      @client2.scheme = 'wss'
      @client1.host = 'one'
      @client2.host = 'two'
      @client1.port = 81
      @client2.port = 82
      @client1.app_id = '1111'
      @client2.app_id = '2222'
      @client1.key = 'AAAA'
      @client2.key = 'BBBB'
      @client1.secret = 'aaaaaaaa'
      @client2.secret = 'bbbbbbbb'
    end

    it "should send scheme messages to different objects" do
      @client1.scheme.should_not == @client2.scheme
    end

    it "should send host messages to different objects" do
      @client1.host.should_not == @client2.host
    end

    it "should send port messages to different objects" do
      @client1.port.should_not == @client2.port
    end

    it "should send app_id messages to different objects" do
      @client1.app_id.should_not == @client2.app_id
    end

    it "should send app_id messages to different objects" do
      @client1.key.should_not == @client2.key
    end

    it "should send app_id messages to different objects" do
      @client1.secret.should_not == @client2.secret
    end

    it "should send app_id messages to different objects" do
      @client1.authentication_token.key.should_not == @client2.authentication_token.key
      @client1.authentication_token.secret.should_not == @client2.authentication_token.secret
    end

    it "should send url messages to different objects" do
      @client1.url.to_s.should_not == @client2.url.to_s
      @client1.url = 'ws://one/apps/111'
      @client2.url = 'wss://two/apps/222'
      @client1.scheme.should_not == @client2.scheme
      @client1.host.should_not == @client2.host
      @client1.app_id.should_not == @client2.app_id
    end

    it "should send encrypted messages to different objects" do
      @client1.encrypted = false
      @client2.encrypted = true
      @client1.scheme.should_not == @client2.scheme
      @client1.port.should_not == @client2.port
    end

    it "should send [] messages to different objects" do
      @client1['test'].should_not == @client2['test']
    end

    it "should send http_proxy messages to different objects" do
      @client1.http_proxy = 'http://oneuser:onepassword@onehost:8080'
      @client2.http_proxy = 'http://twouser:twopassword@twohost:8880'
      @client1.http_proxy.should_not == @client2.http_proxy
    end
  end

  # The behaviour should be the same when using the Client object, or the
  # 'global' client delegated through the Pusher class
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
        Pusher.logger.debug('foo')
        Pusher.logger.should be_kind_of(Logger)
      end
    end

    describe 'logging configuration' do
      it "can be configured to use any logger" do
        logger = mock("ALogger")
        logger.should_receive(:debug).with('foo')
        Pusher.logger = logger
        Pusher.logger.debug('foo')
        Pusher.logger = nil
      end
    end

    describe "configuration using url" do
      it "should be possible to configure everything by setting the url" do
        @client.url = "test://somekey:somesecret@api.staging.pusherapp.com:8080/apps/87"

        @client.scheme.should == 'test'
        @client.host.should == 'api.staging.pusherapp.com'
        @client.port.should == 8080
        @client.key.should == 'somekey'
        @client.secret.should == 'somesecret'
        @client.app_id.should == '87'
      end

      it "should override scheme and port when setting encrypted=true after url" do
        @client.url = "http://somekey:somesecret@api.staging.pusherapp.com:8080/apps/87"
        @client.encrypted = true

        @client.scheme.should == 'https'
        @client.port.should == 443
      end
    end

    describe 'configuration using http_proxy' do
      it "should be possible to configure everything by setting the http_proxy" do
        @client.http_proxy = 'http://someuser:somepassword@proxy.host.com:8080'

        @client.proxy.should == {:scheme => 'http', :host => 'proxy.host.com', :port => 8080, :user => 'someuser', :password => 'somepassword'}
      end
    end

    describe 'when configured' do
      before :each do
        @client.app_id = '20'
        @client.key    = '12345678900000001'
        @client.secret = '12345678900000001'
      end

      describe '#[]' do
        before do
          @channel = @client['test_channel']
        end

        it 'should return a channel' do
          @channel.should be_kind_of(Pusher::Channel)
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

      describe '#channels' do
        it "should call the correct URL and symbolise response correctly" do
          api_path = %r{/apps/20/channels}
          WebMock.stub_request(:get, api_path).to_return({
            :status => 200,
            :body => MultiJson.encode('channels' => {
              "channel1" => {},
              "channel2" => {}
            })
          })
          @client.channels.should == {
            :channels => {
              "channel1" => {},
              "channel2" => {}
            }
          }
        end
      end

      describe '#channel_info' do
        it "should call correct URL and symbolise response" do
          api_path = %r{/apps/20/channels/mychannel}
          WebMock.stub_request(:get, api_path).to_return({
            :status => 200,
            :body => MultiJson.encode({
              'occupied' => false,
            })
          })
          @client.channel_info('mychannel').should == {
            :occupied => false,
          }
        end
      end

      describe '#trigger' do
        before :each do
          @api_path = %r{/apps/20/events}
          WebMock.stub_request(:post, @api_path).to_return({
            :status => 200,
            :body => MultiJson.encode({})
          })
        end

        it "should call correct URL" do
          @client.trigger('mychannel', 'event', {'some' => 'data'}).
            should == {}
        end

        it "should pass any parameters in the body of the request" do
          @client.trigger('mychannel', 'event', {'some' => 'data'}, {
            :socket_id => "1234"
          })
          WebMock.should have_requested(:post, @api_path).with { |req|
            MultiJson.decode(req.body)["socket_id"].should == '1234'
          }
        end

        it "should convert non string data to JSON before posting" do
          @client.trigger('mychannel', 'event', {'some' => 'data'})
          WebMock.should have_requested(:post, @api_path).with { |req|
            MultiJson.decode(req.body)["data"].should == '{"some":"data"}'
          }
        end
      end

      [:get, :post].each do |verb|
        describe "##{verb}" do
          before :each do
            WebMock.stub_request(verb, %r{api.pusherapp.com}).
              to_return(:status => 200, :body => "{}")
          end

          it "should use http by default" do
            @client.send(verb, '/path')
            WebMock.should have_requested(verb, %r{http://api.pusherapp.com/apps/20/path})
          end

          it "should use https if configured" do
            @client.encrypted = true
            @client.send(verb, '/path')
            WebMock.should have_requested(verb, %r{https://api.pusherapp.com})
          end

          it "should format the respose hash with symbols at first level" do
            WebMock.stub_request(verb, %r{api.pusherapp.com}).to_return({
              :status => 200,
              :body => MultiJson.encode({'something' => {'a' => 'hash'}})
            })
            response = @client.send(verb, '/path')
            response.should == {
              :something => {'a' => 'hash'}
            }
          end
        end
      end

      [[:get, :get_async]].each do |verb, method|
        describe "##{method}" do
          before :each do
            WebMock.stub_request(verb, %r{api.pusherapp.com}).
              to_return(:status => 200, :body => "{}")
          end

          it "should use http by default" do
            EM.run {
              @client.send(method, '/path').callback {
                WebMock.should have_requested(verb, %r{http://api.pusherapp.com/apps/20/path})
                EM.stop
              }
            }
          end

          it "should use https if configured" do
            EM.run {
              @client.encrypted = true
              @client.send(method, '/path').callback {
                WebMock.should have_requested(verb, %r{https://api.pusherapp.com})
                EM.stop
              }
            }
          end

          it "should format the respose hash with symbols at first level" do
            EM.run {
              WebMock.stub_request(verb, %r{api.pusherapp.com}).to_return({
                :status => 200,
                :body => MultiJson.encode({'something' => {'a' => 'hash'}})
              })
              @client.send(method, '/path').callback { |response|
                response.should == {
                  :something => {'a' => 'hash'}
                }
                EM.stop
              }
            }
          end
        end
      end
    end
  end
end
