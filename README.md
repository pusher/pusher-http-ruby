# Gem for Pusher Channels

This Gem provides a Ruby interface to [the Pusher HTTP API for Pusher Channels](https://pusher.com/docs/channels/library_auth_reference/rest-api).

[![Build Status](https://github.com/pusher/pusher-http-ruby/workflows/Tests/badge.svg)](https://github.com/pusher/pusher-http-ruby/actions?query=workflow%3ATests+branch%3Amaster) [![Gem Version](https://badge.fury.io/rb/pusher.svg)](https://badge.fury.io/rb/pusher)

## Supported Platforms

* Ruby - supports **Ruby 2.6 or greater**.

## Installation and Configuration

Add `pusher` to your Gemfile, and then run `bundle install`

``` ruby
gem 'pusher'
```

or install via gem

``` bash
gem install pusher
```

After registering at [Pusher](https://dashboard.pusher.com/accounts/sign_up), configure your Channels app with the security credentials.

### Instantiating a Pusher Channels client

Creating a new Pusher Channels `client` can be done as follows.

``` ruby
require 'pusher'

pusher = Pusher::Client.new(
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

pusher = Pusher::Client.new(
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
pusher = Pusher::Client.from_env
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
  pusher.trigger('a_channel', 'an_event', :some => 'data')
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
pusher.trigger('channel', 'event', foo: 'bar')
pusher.trigger(['channel_1', 'channel_2'], 'event_name', foo: 'bar')
```

An optional fourth argument may be used to send additional parameters to the API, for example to [exclude a single connection from receiving the event](https://pusher.com/docs/channels/server_api/excluding-event-recipients).

``` ruby
pusher.trigger('channel', 'event', {foo: 'bar'}, {socket_id: '123.456'})
```

#### Batches

It's also possible to send multiple events with a single API call (max 10
events per call on multi-tenant clusters):

``` ruby
pusher.trigger_batch([
  {channel: 'channel_1', name: 'event_name', data: { foo: 'bar' }},
  {channel: 'channel_1', name: 'event_name', data: { hello: 'world' }}
])
```

#### Deprecated publisher API

Most examples and documentation will refer to the following syntax for triggering an event:

``` ruby
Pusher['a_channel'].trigger('an_event', :some => 'data')
```

This will continue to work, but has been replaced by `pusher.trigger` which supports one or multiple channels.

### Getting information about the channels in your Pusher Channels app

This gem provides methods for accessing information from the [Channels HTTP API](https://pusher.com/docs/channels/library_auth_reference/rest-api). The documentation also shows an example of the responses from each of the API endpoints.

The following methods are provided by the gem.

- `pusher.channel_info('channel_name', {info:"user_count,subscription_count"})` returns a hash describing the state of the channel([docs](https://pusher.com/docs/channels/library_auth_reference/rest-api#get-channels-fetch-info-for-multiple-channels-)).

- `pusher.channel_users('presence-channel_name')` returns a list of all the users subscribed to the channel (only for Presence Channels) ([docs](https://pusher.com/docs/channels/library_auth_reference/rest-api#get-channels-fetch-info-for-multiple-channels-)).

- `pusher.channels({filter_by_prefix: 'presence-', info: 'user_count'})` returns a hash of occupied channels (optionally filtered by prefix, f.i. `presence-`), and optionally attributes for these channels ([docs](https://pusher.com/docs/channels/library_auth_reference/rest-api#get-channels-fetch-info-for-multiple-channels-)).

### Asynchronous requests

There are two main reasons for using the `_async` methods:

* In a web application where the response from the Channels HTTP API is not used, but you'd like to avoid a blocking call in the request-response cycle
* Your application is running in an event loop and you need to avoid blocking the reactor

Asynchronous calls are supported either by using an event loop (eventmachine, preferred), or via a thread.

The following methods are available (in each case the calling interface matches the non-async version):

* `pusher.get_async`
* `pusher.post_async`
* `pusher.trigger_async`

It is of course also possible to make calls to the Channels HTTP API via a job queue. This approach is recommended if you're sending a large number of events.

#### With EventMachine

* Add the `em-http-request` gem to your Gemfile (it's not a gem dependency).
* Run the EventMachine reactor (either using `EM.run` or by running inside an evented server such as Thin).

The `_async` methods return an `EM::Deferrable` which you can bind callbacks to:

``` ruby
pusher.get_async("/channels").callback { |response|
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
pusher.authenticate('private-my_channel', params[:socket_id])
```

### Presence channels

These work in a very similar way, but require a unique identifier for the user being authenticated, and optionally some attributes that are provided to clients via presence events:

``` ruby
pusher.authenticate('presence-my_channel', params[:socket_id],
  user_id: 'user_id',
  user_info: {} # optional
)
```

## Receiving WebHooks

A WebHook object may be created to validate received WebHooks against your app credentials, and to extract events. It should be created with the `Rack::Request` object (available as `request` in Rails controllers or Sinatra handlers for example).

``` ruby
webhook = pusher.webhook(request)
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

### End-to-end encryption

This library supports [end-to-end encrypted channels](https://pusher.com/docs/channels/using_channels/encrypted-channels). This means that only you and your connected clients will be able to read your messages. Pusher cannot decrypt them. You can enable this feature by following these steps:

1. Add the `rbnacl` gem to your Gemfile (it's not a gem dependency).

2. Install [Libsodium](https://github.com/jedisct1/libsodium), which we rely on to do the heavy lifting. [Follow the installation instructions for your platform.](https://github.com/RubyCrypto/rbnacl/wiki/Installing-libsodium)

3. Encrypted channel subscriptions must be authenticated in the exact same way as private channels. You should therefore [create an authentication endpoint on your server](https://pusher.com/docs/authenticating_users).

4. Next, generate your 32 byte master encryption key, encode it as base64 and pass it to the Pusher constructor.

   This is secret and you should never share this with anyone.
   Not even Pusher.

   ```bash
   openssl rand -base64 32
   ```

   ```rb
   pusher = new Pusher::Client.new({
     app_id: 'your-app-id',
     key: 'your-app-key',
     secret: 'your-app-secret',
     cluster: 'your-app-cluster',
     use_tls: true
     encryption_master_key_base64: '<KEY GENERATED BY PREVIOUS COMMAND>',
   });
   ```

5. Channels where you wish to use end-to-end encryption should be prefixed with `private-encrypted-`.

6. Subscribe to these channels in your client, and you're done! You can verify it is working by checking out the debug console on the [https://dashboard.pusher.com/](dashboard) and seeing the scrambled ciphertext.

**Important note: This will __not__ encrypt messages on channels that are not prefixed by `private-encrypted-`.**

**Limitation**: you cannot trigger a single event on multiple channels in a call to `trigger`, e.g.

```rb
pusher.trigger(
  ['channel-1', 'private-encrypted-channel-2'],
  'test_event',
  { message: 'hello world' },
)
```

Rationale: the methods in this library map directly to individual Channels HTTP API requests. If we allowed triggering a single event on multiple channels (some encrypted, some unencrypted), then it would require two API requests: one where the event is encrypted to the encrypted channels, and one where the event is unencrypted for unencrypted channels.
