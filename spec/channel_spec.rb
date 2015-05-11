# -*- coding: utf-8 -*-
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

  describe "#initialization" do
    it "should not be too long" do
      lambda { @client['b'*201] }.should raise_error(Pusher::Error)
    end

    it "should not use bad characters" do
      lambda { @client['*^!±`/""'] }.should raise_error(Pusher::Error)
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

    it "should assemble the requested attributes into the info option" do
      @client.should_receive(:get).with(anything, {
        :info => "user_count,connection_count"
      })
      @channel = @client['presence-foo']
      @channel.info(%w{user_count connection_count})
    end
  end

  describe '#users' do
    it "should call the Client#channel_users" do
      @client.should_receive(:get).with("/channels/presence-mychannel/users").and_return({:users => {'id' => '4'}})
      @channel = @client['presence-mychannel']
      @channel.users
    end
  end

  describe "#authentication_string" do
    def authentication_string(*data)
      lambda { @channel.authentication_string(*data) }
    end

    it "should return an authentication string given a socket id" do
      auth = @channel.authentication_string('1.1')

      auth.should == '12345678900000001:02259dff9a2a3f71ea8ab29ac0c0c0ef7996c8f3fd3702be5533f30da7d7fed4'
    end

    it "should raise error if authentication is invalid" do
      [nil, ''].each do |invalid|
        authentication_string(invalid).should raise_error Pusher::Error
      end
    end

    describe 'with extra string argument' do
      it 'should be a string or nil' do
        authentication_string('1.1', 123).should raise_error Pusher::Error
        authentication_string('1.1', {}).should raise_error Pusher::Error

        authentication_string('1.1', 'boom').should_not raise_error
        authentication_string('1.1', nil).should_not raise_error
      end

      it "should return an authentication string given a socket id and custom args" do
        auth = @channel.authentication_string('1.1', 'foobar')

        auth.should == "12345678900000001:#{hmac(@client.secret, "1.1:test_channel:foobar")}"
      end
    end
  end

  describe '#authenticate' do
    before :each do
      @custom_data = {:uid => 123, :info => {:name => 'Foo'}}
    end

    it 'should return a hash with signature including custom data and data as json string' do
      MultiJson.stub(:encode).with(@custom_data).and_return 'a json string'

      response = @channel.authenticate('1.1', @custom_data)

      response.should == {
        :auth => "12345678900000001:#{hmac(@client.secret, "1.1:test_channel:a json string")}",
        :channel_data => 'a json string'
      }
    end

    it 'should fail on invalid socket_ids' do
      lambda {
        @channel.authenticate('1.1:')
      }.should raise_error Pusher::Error

      lambda {
        @channel.authenticate('1.1foo', 'channel')
      }.should raise_error Pusher::Error

      lambda {
        @channel.authenticate(':1.1')
      }.should raise_error Pusher::Error

      lambda {
        @channel.authenticate('foo1.1', 'channel')
      }.should raise_error Pusher::Error

      lambda {
        @channel.authenticate('foo', 'channel')
      }.should raise_error Pusher::Error
    end
  end
end
