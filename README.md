# Gem for Pusher Channels

This Gem provides a Ruby interface to [the Pusher HTTP API for Pusher Channels](https://pusher.com/docs/rest_api).

[![Build Status](https://secure.travis-ci.org/pusher/pusher-http-ruby.svg?branch=master)](http://travis-ci.org/pusher/pusher-http-ruby)

## Installation and Configuration

Add `pusher` to your Gemfile, and then run `bundle install`

``` ruby
gem 'pusher'
```

or install via gem

``` bash
gem install pusher
```

After registering at <https://dashboard.pusher.com/>, configure your Channels app with the security credentials.

### Instantiating a Pusher Channels client

Creating a new Pusher Channels `client` can be done as follows.

``` ruby
require 'pusher'

channels_client = Pusher::Client.new(
  app_id: 'your-app-id',
  key: 'your-app-key',
  secret: 'your-app-secret',
  cluster: 'your-app-cluster',
  use_tls: true
)
```

The `cluster` value will set the `host` to `api-<cluster>.pusher.com`. The `use_tls` value is optional and defaults to `false`. It will set the `scheme` and `port`. Custom `scheme` and `port` values take precendence over `use_tls`.

If you want to set a custom `host` value for your client then you can do so when instantiating a Pusher Channels client like so:

``` ruby
require 'pusher'

channels_client = Pusher::Client.new(
  app_id: 'your-app-id',
  key: 'your-app-key',
  secret: 'your-app-secret',
  host: 'your-app-host'
)
```

If you pass both `host` and `cluster` options, the `host` will take precendence and `cluster` will be ignored.

Finally, if you have the configuration set in an `PUSHER_URL` environment
variable, you can use:

``` ruby
channels_client = Pusher::Client.from_env
```

### Global configuration

The library can also be configured globally on the `Pusher` class.

``` ruby
Pusher.app_id = 'your-app-id'
Pusher.key = 'your-app-key'
Pusher.secret = 'your-app-secret'
Pusher.cluster = 'your-app-cluster'
```

Global configuration will automatically be set from the `PUSHER_URL` environment variable if it exists. This should be in the form  `http://KEY:SECRET@HOST/apps/APP_ID`. On Heroku this environment variable will already be set.

If you need to make requests via a HTTP proxy then it can be configured

``` ruby
Pusher.http_proxy = 'http://(user):(password)@(host):(port)'
```

By default API requests are made over HTTP. HTTPS can be used by setting `encrypted` to `true`.
Issuing this command is going to reset `port` value if it was previously specified.

``` ruby
Pusher.encrypted = true
```

As of version 0.12, SSL certificates are verified when using the synchronous http client. If you need to disable this behaviour for any reason use:

``` ruby
Pusher.default_client.sync_http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
```

## Interacting with the Channels HTTP API

The `pusher` gem contains a number of helpers for interacting with the API. As a general rule, the library adheres to a set of conventions that we have aimed to make universal.

### Handling errors

Handle errors by rescuing `Pusher::Error` (all errors are descendants of this error)

``` ruby
begin
  channels_client.trigger('a_channel', 'an_event', :some => 'data')
rescue Pusher::Error => e
  # (Pusher::AuthenticationError, Pusher::HTTPError, or Pusher::Error)
end
```

### Logging

Errors are logged to `Pusher.logger`. It will by default log at info level to STDOUT using `Logger` from the standard library, however you can assign any logger:

``` ruby
Pusher.logger = Rails.logger
```

### Publishing events

An event can be published to one or more channels (limited to 10) in one API call:

``` ruby
channels_client.trigger('channel', 'event', foo: 'bar')
channels_client.trigger(['channel_1', 'channel_2'], 'event_name', foo: 'bar')
```

An optional fourth argument may be used to send additional parameters to the API, for example to [exclude a single connection from receiving the event](http://pusher.com/docs/publisher_api_guide/publisher_excluding_recipients).

``` ruby
channels_client.trigger('channel', 'event', {foo: 'bar'}, {socket_id: '123.456'})
```

#### Batches

It's also possible to send multiple events with a single API call (max 10
events per call on multi-tenant clusters):

``` ruby
channels_client.trigger_batch([
  {channel: 'channel_1', name: 'event_name', data: { foo: 'bar' }},
  {channel: 'channel_1', name: 'event_name', data: { hello: 'world' }}
])
```

#### Deprecated publisher API

Most examples and documentation will refer to the following syntax for triggering an event:

``` ruby
Pusher['a_channel'].trigger('an_event', :some => 'data')
```

This will continue to work, but has been replaced by `channels_client.trigger` which supports one or multiple channels.

### Getting information about the channels in your Pusher Channels app

This gem provides methods for accessing information from the [Channels HTTP API](https://pusher.com/docs/rest_api). The documentation also shows an example of the responses from each of the API endpoints.

The following methods are provided by the gem.

- `channels_client.channel_info('channel_name')` returns information about that channel.

- `channels_client.channel_users('channel_name')` returns a list of all the users subscribed to the channel.

- `channels_client.channels` returns information about all the channels in your Channels application.

### Asynchronous requests

There are two main reasons for using the `_async` methods:

* In a web application where the response from the Channels HTTP API is not used, but you'd like to avoid a blocking call in the request-response cycle
* Your application is running in an event loop and you need to avoid blocking the reactor

Asynchronous calls are supported either by using an event loop (eventmachine, preferred), or via a thread.

The following methods are available (in each case the calling interface matches the non-async version):

* `channels_client.get_async`
* `channels_client.post_async`
* `channels_client.trigger_async`

It is of course also possible to make calls to the Channels HTTP API via a job queue. This approach is recommended if you're sending a large number of events.

#### With EventMachine

* Add the `em-http-request` gem to your Gemfile (it's not a gem dependency).
* Run the EventMachine reactor (either using `EM.run` or by running inside an evented server such as Thin).

The `_async` methods return an `EM::Deferrable` which you can bind callbacks to:

``` ruby
channels_client.get_async("/channels").callback { |response|
  # use reponse[:channels]
}.errback { |error|
  # error is an instance of Pusher::Error
}
```

A HTTP error or an error response from Channels will cause the errback to be called with an appropriate error object.

#### Without EventMachine

If the EventMachine reactor is not running, async requests will be made using threads (managed by the httpclient gem).

An `HTTPClient::Connection` object is returned immediately which can be [interrogated](http://rubydoc.info/gems/httpclient/HTTPClient/Connection) to discover the status of the request. The usual response checking and processing is not done when the request completes, and frankly this method is most useful when you're not interested in waiting for the response.


## Authenticating subscription requests

It's possible to use the gem to authenticate subscription requests to private or presence channels. The `authenticate` method is available on a channel object for this purpose and returns a JSON object that can be returned to the client that made the request. More information on this authentication scheme can be found in the docs on <https://pusher.com/docs/channels/server_api/authenticating-users>

### Private channels

``` ruby
channels_client.authenticate('private-my_channel', params[:socket_id])
```

### Presence channels

These work in a very similar way, but require a unique identifier for the user being authenticated, and optionally some attributes that are provided to clients via presence events:

``` ruby
channels_client.authenticate('presence-my_channel', params[:socket_id],
  user_id: 'user_id',
  user_info: {} # optional
)
```

## Receiving WebHooks

A WebHook object may be created to validate received WebHooks against your app credentials, and to extract events. It should be created with the `Rack::Request` object (available as `request` in Rails controllers or Sinatra handlers for example).

``` ruby
webhook = channels_client.webhook(request)
if webhook.valid?
  webhook.events.each do |event|
    case event["name"]
    when 'channel_occupied'
      puts "Channel occupied: #{event["channel"]}"
    when 'channel_vacated'
      puts "Channel vacated: #{event["channel"]}"
    end
  end
  render text: 'ok'
else
  render text: 'invalid', status: 401
end
```
