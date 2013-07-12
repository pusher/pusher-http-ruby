Pusher gem
==========

[![Build Status](https://secure.travis-ci.org/pusher/pusher-gem.png?branch=master)](http://travis-ci.org/pusher/pusher-gem)

## Installation & Configuration

Add pusher to your Gemfile, and then run `bundle install`

```ruby
gem 'pusher'
```
    
or install via gem

```console
gem install pusher
```
After registering at <http://pusher.com> configure your app with the security credentials.

### Global

The most standard way of configuring Pusher is to do it globally on the Pusher class. 

```ruby
Pusher.app_id = 'your-pusher-app-id'
Pusher.key = 'your-pusher-key'
Pusher.secret = 'your-pusher-secret'
```

Global configuration will automatically be set from the `PUSHER_URL` environment variable if it exists. This should be in the form  `http://KEY:SECRET@api.pusherapp.com/apps/APP_ID`. On Heroku this environment variable will already be set.

If you need to make requests via a HTTP proxy then it can be configured

```ruby
Pusher.http_proxy = 'http://(user):(password)@(host):(port)'
```

By default API requests are made over HTTP. HTTPS can be used by setting

```ruby
Pusher.encrypted = true
```

### Instantiating a Pusher client

Sometimes you may have multiple sets of API keys, or want different configuration in different parts of your application. In these scenarios, a pusher `client` may be configured:

```ruby
pusher_client = Pusher::Client.new({
  app_id: 'your-pusher-app-id',
  key: 'your-pusher-key',
  secret: 'your-pusher-secret'
})
```

This `client` will have all the functionality listed on the main Pusher class (which proxies to a client internally).



## Interacting with the Pusher service

The Pusher gem contains a number of helpers for interacting with the service. As a general rule, the library adheres to a set of conventions that we have aimed to make universal.

### Handling errors

Handle errors by rescuing `Pusher::Error` (all errors are descendants of this error)

```ruby
begin
  Pusher.trigger('a_channel', 'an_event', {:some => 'data'})
rescue Pusher::Error => e
  # (Pusher::AuthenticationError, Pusher::HTTPError, or Pusher::Error)
end
```

### Logging

Errors are logged to `Pusher.logger`. It will by default log at info level to STDOUT using `Logger` from the standard library, however you can assign any logger:

```ruby
Pusher.logger = Rails.logger
```

### Publishing events

An event can be sent to Pusher in in the following ways:

```ruby
# on the Pusher class
Pusher.trigger('channel_name', 'event_name', {some: 'data'})
Pusher.trigger(['channel_1', 'channel_2'], 'event_name', {some: 'data'})

# or on a pusher_client
pusher_client.trigger(['your_channels'], 'your_event_name', {some: 'data'})
```

Note: the first `channels` argument can contain multiple channels you'd like your event and data payload to go to. There is a limit of 100 on the number of channels this can contain.

An optional fourth argument of this method can specify a `socket_id` that will be excluded from receiving the event (generally the user where the event originated -- see <http://pusher.com/docs/publisher_api_guide/publisher_excluding_recipients> for more info).

#### Original publisher API

Most examples and documentation will refer to the following syntax for triggering an event:

```ruby
Pusher['a_channel'].trigger('an_event', {:some => 'data'})
```

This will continue to work, but will be replaced as the canonical version by `Pusher.trigger` which supports multiple channels.

### Generic requests to the Pusher REST API

Aside from triggering events, the REST API also supports a number of operations for querying the state of the system. A reference of the available methods is available at <http://pusher.com/docs/rest_api>.

All requests must be signed by using your secret key, which is handled automatically using these methods:

```ruby
# using the Pusher class
Pusher.get('url_without_app_id', params)

# using a client
pusher_client.post('url_without_app_id', params)
```

Note that you don't need to specify your app_id in the URL, as this is inferred from your credentials. As with the trigger method above, `_async` can be suffixed to the method name to return a deferrable.

### Asynchronous requests

If you are running your application in an evented environment, you may want to use the asynchronous versions of the Pusher API methods to avoid blocking. The convention for this is to add the suffix `_async` to the method, e.g. `trigger_async` or `post_async`.

You need to be running eventmachine to make use of this functionality. This is already the case if, for example, you're deploying to Heroku or using the Thin web server. You will also need to add `em-http-request` to your Gemfile.

When using an asynchronous version of a method, it will return a deferrable.

```ruby
Pusher.trigger_async(['a_channel'], 'an_event', {
  :some => 'data'
}, socket_id).callback {
  # Do something on success
}.errback { |error|
  # error is a instance of Pusher::Error
}
```


## Authenticating subscription requests

It's possible to use the gem to authenticate subscription requests to private or presence channels. The `authenticate` method is available on a channel object for this purpose and returns a JSON object that can be returned to the client that made the request. More information on this authentication scheme can be found in the docs on <http://pusher.com>

### Private channels

```ruby
Pusher['private-my_channel'].authenticate(params[:socket_id])
```

### Presence channels

These work in a very similar way, but require a unique identifier for the user being authenticated, and optionally some attributes that are provided to clients via presence events:

```ruby
Pusher['presence-my_channel'].authenticate(params[:socket_id], {
  user_id: 'user_id',
  user_info: {} # optional
})
```


## Receiving WebHooks

A WebHook object may be created to validate received WebHooks against your app credentials, and to extract events. It should be created with the `Rack::Request` object (available as `request` in Rails controllers or Sinatra handlers for example).

```ruby
webhook = Pusher.webhook(request)
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
