Pusher gem
==========

[![Build Status](https://secure.travis-ci.org/pusher/pusher-gem.png?branch=master)](http://travis-ci.org/pusher/pusher-gem)

## Installation & Configuration

Add pusher to your Gemfile, and then run `bundle install`

    gem 'pusher'
    
or install via gem

    gem install pusher

After registering at <http://pusher.com> configure your app with the security credentials.

### Global

The most standard way of configuring Pusher is to do it globally on the Pusher class. 

    Pusher.app_id = 'your-pusher-app-id'
    Pusher.key = 'your-pusher-key'
    Pusher.secret = 'your-pusher-secret'

Global configuration will automatically be set from the `PUSHER_URL` environment variable if it exists. This should be in the form  `http://KEY:SECRET@api.pusherapp.com/apps/APP_ID`. On Heroku this environment variable will already be set.

If you need to make requests via a HTTP proxy then it can be configured

    Pusher.http_proxy = 'http://(user):(password)@(host):(port)'

By default API requests are made over HTTP. HTTPS can be used by setting

    Pusher.encrypted = true

As of version 0.12, SSL certificates are verified when using the synchronous http client. If you need to disable this behaviour for any reason use:

    Pusher.default_client.sync_http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

### Instantiating a Pusher client

Sometimes you may have multiple sets of API keys, or want different configuration in different parts of your application. In these scenarios, a pusher `client` may be configured:

    pusher_client = Pusher::Client.new({
      app_id: 'your-pusher-app-id',
      key: 'your-pusher-key',
      secret: 'your-pusher-secret'
    })

This `client` will have all the functionality listed on the main Pusher class (which proxies to a client internally).



## Interacting with the Pusher service

The Pusher gem contains a number of helpers for interacting with the service. As a general rule, the library adheres to a set of conventions that we have aimed to make universal.

### Handling errors

Handle errors by rescuing `Pusher::Error` (all errors are descendants of this error)

    begin
      Pusher.trigger('a_channel', 'an_event', {:some => 'data'})
    rescue Pusher::Error => e
      # (Pusher::AuthenticationError, Pusher::HTTPError, or Pusher::Error)
    end

### Logging

Errors are logged to `Pusher.logger`. It will by default log at info level to STDOUT using `Logger` from the standard library, however you can assign any logger:

    Pusher.logger = Rails.logger

### Publishing events

An event can be sent to Pusher in in the following ways:

    # on the Pusher class
    Pusher.trigger('channel_name', 'event_name', {some: 'data'})
    Pusher.trigger(['channel_1', 'channel_2'], 'event_name', {some: 'data'})
    
    # or on a pusher_client
    pusher_client.trigger(['your_channels'], 'your_event_name', {some: 'data'})

Note: the first `channels` argument can contain multiple channels you'd like your event and data payload to go to. There is a limit of 100 on the number of channels this can contain.

An optional fourth argument of this method can specify a `socket_id` that will be excluded from receiving the event (generally the user where the event originated -- see <http://pusher.com/docs/publisher_api_guide/publisher_excluding_recipients> for more info).

#### Original publisher API

Most examples and documentation will refer to the following syntax for triggering an event:

    Pusher['a_channel'].trigger('an_event', {:some => 'data'})

This will continue to work, but will be replaced as the canonical version by `Pusher.trigger` which supports multiple channels.

### Generic requests to the Pusher REST API

Aside from triggering events, the REST API also supports a number of operations for querying the state of the system. A reference of the available methods is available at <http://pusher.com/docs/rest_api>.

All requests must be signed by using your secret key, which is handled automatically using these methods:

    # using the Pusher class
    Pusher.get('url_without_app_id', params)
    
    # using a client
    pusher_client.post('url_without_app_id', params)

Note that you don't need to specify your app_id in the URL, as this is inferred from your credentials.

### Asynchronous requests

There are two main reasons for using the `_async` methods:

* In a web application where the response from Pusher is not used, but you'd like to avoid a blocking call in the request-response cycle
* Your application is running in an event loop and you need to avoid blocking the reactor

Asynchronous calls are supported either by using an event loop (eventmachine, preferred), or via a thread.

The following methods are available (in each case the calling iterface matches the non-async version):

* `Pusher.get_async`
* `Pusher.post_async`
* `Pusher.trigger_async`

It is of course also possible to make calls to pusher via a job queue. This approach is recommended if you're sending a large number of events to pusher.

#### With eventmachine

* Add the `em-http-request` gem to your Gemfile (it's not a gem dependency).
* Run the eventmachine reactor (either using `EM.run` or by running inside an evented server such as Thin).

The `_async` methods return an `EM::Deferrable` which you can bind callbacks to:

    Pusher.get_async("/channels").callback { |response|
      # use reponse[:channels]
    }.errback { |error|
      # error is an instance of Pusher::Error
    }

A HTTP error or an error response from pusher will cause the errback to be called with an appropriate error object.

#### Without eventmachine

If the eventmachine reactor is not running, async requests will be make using threads (managed by the httpclient gem).

An `HTTPClient::Connection` object is returned immediately which can be [interrogated](http://rubydoc.info/gems/httpclient/HTTPClient/Connection) to discover the status of the request. The usual response checking and processing is not done when the request completes, and frankly this method is most useful when you're not interested in waiting for the response.


## Authenticating subscription requests

It's possible to use the gem to authenticate subscription requests to private or presence channels. The `authenticate` method is available on a channel object for this purpose and returns a JSON object that can be returned to the client that made the request. More information on this authentication scheme can be found in the docs on <http://pusher.com>

### Private channels

    Pusher['private-my_channel'].authenticate(params[:socket_id])

### Presence channels

These work in a very similar way, but require a unique identifier for the user being authenticated, and optionally some attributes that are provided to clients via presence events:

    Pusher['presence-my_channel'].authenticate(params[:socket_id], {
      user_id: 'user_id',
      user_info: {} # optional
    })



## Receiving WebHooks

A WebHook object may be created to validate received WebHooks against your app credentials, and to extract events. It should be created with the `Rack::Request` object (available as `request` in Rails controllers or Sinatra handlers for example).

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
