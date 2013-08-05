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
    @channel = @client['test_channel']
  end

  let(:pusher_url_regexp) { %r{/apps/20/events} }

  def stub_post(status, body = nil)
    options = {:status => status}
    options.merge!({:body => body}) if body

    stub_request(:post, pusher_url_regexp).to_return(options)
  end

  def stub_post_to_raise(e)
    stub_request(:post, pusher_url_regexp).to_raise(e)
  end

  describe '#trigger!' do
    it "should use @client.trigger internally" do
      @client.should_receive(:trigger)
      @channel.trigger('new_event', 'Some data')
    end
  end

  describe '#trigger' do
    it "should log failure if error raised in http call" do
      stub_post_to_raise(HTTPClient::BadResponseError)

      Pusher.logger.should_receive(:error).with("Exception from WebMock (HTTPClient::BadResponseError) (Pusher::HTTPError)")
      Pusher.logger.should_receive(:debug) #backtrace
      channel = Pusher::Channel.new(@client.url, 'test_channel', @client)
      channel.trigger('new_event', 'Some data')
    end

    it "should log failure if Pusher returns an error response" do
      stub_post 401, "some signature info"
      Pusher.logger.should_receive(:error).with("some signature info (Pusher::AuthenticationError)")
      Pusher.logger.should_receive(:debug) #backtrace
      channel = Pusher::Channel.new(@client.url, 'test_channel', @client)
      channel.trigger('new_event', 'Some data')
    end
  end

  describe "#trigger_async" do
    it "should use @client.trigger_async internally" do
      @client.should_receive(:trigger_async)
      @channel.trigger_async('new_event', 'Some data')
    end
  end

  describe '#info' do
    it "should call the Client#channel_info" do
      @client.should_receive(:get).with("/channels/mychannel", anything)
      @channel = @client['mychannel']
      @channel.info
    end

    it "should assemble the requested attribes into the info option" do
      @client.should_receive(:get).with(anything, {
        :info => "user_count,connection_count"
      })
      @channel = @client['presence-foo']
      @channel.info(%w{user_count connection_count})
    end
  end

  describe "#authentication_string" do
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
        authentication_string('socketid', 123).should raise_error Pusher::Error
        authentication_string('socketid', {}).should raise_error Pusher::Error

        authentication_string('socketid', 'boom').should_not raise_error
        authentication_string('socketid', nil).should_not raise_error
      end

      it "should return an authentication string given a socket id and custom args" do
        auth = @channel.authentication_string('socketid', 'foobar')

        auth.should == "12345678900000001:#{hmac(@client.secret, "socketid:test_channel:foobar")}"
      end
    end
  end

  describe '#authenticate' do
    before :each do
      @custom_data = {:uid => 123, :info => {:name => 'Foo'}}
    end

    it 'should return a hash with signature including custom data and data as json string' do
      MultiJson.stub(:encode).with(@custom_data).and_return 'a json string'

      response = @channel.authenticate('socketid', @custom_data)

      response.should == {
        :auth => "12345678900000001:#{hmac(@client.secret, "socketid:test_channel:a json string")}",
        :channel_data => 'a json string'
      }
    end
  end
end
