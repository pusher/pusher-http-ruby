require 'spec_helper'

require 'rack'
require 'stringio'

describe Pusher::WebHook do
  before :each do
    @hook_data = {
      "time_ms" => 123456,
      "events" => [
        {"name" => 'foo'}
      ]
    }
  end

  describe "initialization" do
    it "can be initialized with Rack::Request" do
      request = Rack::Request.new({
        'HTTP_X_PUSHER_KEY' => '1234',
        'HTTP_X_PUSHER_SIGNATURE' => 'asdf',
        'CONTENT_TYPE' => 'application/json',
        'rack.input' => StringIO.new(MultiJson.encode(@hook_data))
      })
      wh = Pusher::WebHook.new(request)
      wh.key.should == '1234'
      wh.signature.should == 'asdf'
      wh.data.should == @hook_data
    end

    it "can be initialized with a hash" do
      request = {
        :key => '1234',
        :signature => 'asdf',
        :content_type => 'application/json',
        :body => MultiJson.encode(@hook_data),
      }
      wh = Pusher::WebHook.new(request)
      wh.key.should == '1234'
      wh.signature.should == 'asdf'
      wh.data.should == @hook_data
    end
  end

  describe "after initialization" do
    before :each do
      @body = MultiJson.encode(@hook_data)
      request = {
        :key => '1234',
        :signature => hmac('asdf', @body),
        :content_type => 'application/json',
        :body => @body
      }

      @client = Pusher::Client.new
      @wh = Pusher::WebHook.new(request, @client)
    end

    it "should validate" do
      @client.key = '1234'
      @client.secret = 'asdf'
      @wh.should be_valid
    end

    it "should not validate if key is wrong" do
      @client.key = '12345'
      @client.secret = 'asdf'
      Pusher.logger.should_receive(:warn).with("Received webhook with unknown key: 1234")
      @wh.should_not be_valid
    end

    it "should not validate if secret is wrong" do
      @client.key = '1234'
      @client.secret = 'asdfxxx'
      digest = OpenSSL::Digest::SHA256.new
      expected = OpenSSL::HMAC.hexdigest(digest, @client.secret, @body)
      Pusher.logger.should_receive(:warn).with("Received WebHook with invalid signature: got #{@wh.signature}, expected #{expected}")
      @wh.should_not be_valid
    end

    it "should validate with an extra token" do
      @client.key = '12345'
      @client.secret = 'xxx'
      @wh.valid?({:key => '1234', :secret => 'asdf'}).should be_true
    end

    it "should validate with an array of extra tokens" do
      @client.key = '123456'
      @client.secret = 'xxx'
      @wh.valid?([
        {:key => '12345', :secret => 'wtf'},
        {:key => '1234', :secret => 'asdf'}
      ]).should be_true
    end

    it "should not validate if all keys are wrong with extra tokens" do
      @client.key = '123456'
      @client.secret = 'asdf'
      Pusher.logger.should_receive(:warn).with("Received webhook with unknown key: 1234")
      @wh.valid?({:key => '12345', :secret => 'asdf'}).should be_false
    end

    it "should not validate if secret is wrong with extra tokens" do
      @client.key = '123456'
      @client.secret = 'asdfxxx'
      Pusher.logger.should_receive(:warn).with(/Received WebHook with invalid signature/)
      @wh.valid?({:key => '1234', :secret => 'wtf'}).should be_false
    end

    it "should expose events" do
      @wh.events.should == @hook_data["events"]
    end

    it "should expose time" do
      @wh.time.should == Time.at(123.456)
    end
  end
end
