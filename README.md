Pusher gem
==========

[![Build Status](https://secure.travis-ci.org/pusher/pusher-gem.png?branch=master)](http://travis-ci.org/pusher/pusher-gem)

## Configuration


After registering at <http://pusher.com> configure your app with the security credentials.

### Global

The most standard way of configuring Pusher is to do it globally on the Pusher class. 

    Pusher.app_id = 'your-pusher-app-id'
    Pusher.key = 'your-pusher-key'
    Pusher.secret = 'your-pusher-secret'


TODO: what are all the configuration options?

TODO: should we mention that Heroku apps are automatically configured?

If you need to request over HTTP proxy, then you can configure the {Pusher#http_proxy}.

    Pusher.http_proxy = 'http://(user):(password)@(host):(port)'

### Instantiating a Pusher client

Sometime you may have multiple sets of API keys, or want different configuration in different parts of your application. In these scenarios, a pusher `client` can be configured:

    pusher_client = Pusher.new({
      app_id: 'your-pusher-app-id',
      key: 'your-pusher-key',
      secret: 'your
    })

This `client` will have all the functionality listed on the main Pusher class (which proxies to a client internally).

## Interacting with the Pusher service

The Pusher gem contains a number of helpers for interacting with the service. As a general rule, the library adheres to a set of conventions that we have aimed to make universal.

### Raising errors 

By default, requests to our service that could return an error code, do not raise an exception, but do log. To rescue and inspect these errors, a separate version with an exclamation point exists, eg `trigger!`.

Handle errors by rescuing `Pusher::Error` (all Pusher errors are descendants of this error)

    begin
      Pusher['a_channel'].trigger!('an_event', {:some => 'data'})
    rescue Pusher::Error => e
      # (Pusher::AuthenticationError, Pusher::HTTPError, or Pusher::Error)
    end

### Logging

Errors are logged to `Pusher.logger`. It will by default use `Logger` from stdlib, however you can assign any logger:

    Pusher.logger = Rails.logger

### Asyncronous requests

The default method of interaction is synchronous. If you are running your application in an evented environment, you may want to use the asynchronous versions of the Pusher API methods to avoid blocking. The convention for this is to add the suffix `_async` to the method, eg `trigger_async`.

When using an asyncronous version of a method, it will return a deferrable. An example of this is included towards the bottom of this document.

TODO: does this mean that you can combine to form `trigger_async!`?

## Publishing events

An event can be sent to Pusher in in the following ways:

    # on the Pusher class
    Pusher.trigger(['your_channels'], 'your_event_name', {some: 'data'})
    
    # or on a pusher_client
    pusher_client.trigger(['your_channels'], 'your_event_name', {some: 'data'})

Note: the first `channels` argument can contain multiple channels you'd like your event and data payload to go to. There is a limit of 100 on the number of channels this can contain.

An optional fourth argument of this method can specify a `socket_id` that will be excluded from receiving the event (generally the user where the event originated -- see <http://pusher.com/docs/publisher_api_guide/publisher_excluding_recipients> for more info).

### Original publisher API 

Most examples and documentation will refer to the following syntax for triggering an event:

    Pusher['a_channel'].trigger('an_event', {:some => 'data'})
    
This will continue to work, but will be replaced as the canonical version by the first method that supports multiple channels.

## Generic requests to the Pusher REST API

Aside from triggering events, our REST API also supports a number of operations for querying the state of the system. A reference of the available methods is available here <http://pusher.com/docs/rest_api>.

All requests must be signed by your secret key. Luckily, the Pusher gem provides a wrapper to this which makes requests much simpler. Examples are included below:

    # using the Pusher class
    Pusher.get('url_without_app_id', params)
    
    # using a client
    pusher_client.post('url_without_app_id', params)

Note that you don't need to specify your app_id in the URL, as this is inferred from your credentials. As with the trigger method above, `_async` can be suffixed to the method name to return a deferrable.

## Generating authentication responses

The Pusher Gem also deals with signing requests to authenticate private or presence channels. The `authenticate` method is available on a channel object for this purpose and returns a JSON object that can be returned to the client that made the request. More information on this authentication scheme can be found in the docs on <http://pusher.com>

### Private channels

    Pusher['private-my_channel'].authenticate(params[:socket_id])

### Presence channels

These work in a very similar way, but require a unique identifier for the user being authenticated, and optionally some attributes that describe that allowed them to be identified in a more human friendly way (eg their name or gravatar):

    Pusher['presence-my_channel'].authenticate(params[:socket_id], {
      user_id: 'user_id',
      user_info: {} # optional
    })


## Receiving WebHooks

See {Pusher::WebHook}

TODO: I don't know why this doesn't have inline docs...

Asynchronous triggering
-----------------------

To avoid blocking in a typical web application, you may wish to use the {Pusher::Channel#trigger_async} method which makes asynchronous API requests. `trigger_async` returns a deferrable which you can optionally bind to with success and failure callbacks.

You need to be running eventmachine to make use of this functionality. This is already the case if, for example, you're deploying to Heroku or using the Thin web server. You will also need to add `em-http-request` to your Gemfile.

    $ gem install em-http-request

    deferrable = Pusher['a_channel'].trigger_async('an_event', {
      :some => 'data'
    }, socket_id)
    deferrable.callback {
      # Do something on success
    }
    deferrable.errback { |error|
      # error is a instance of Pusher::Error
    }




