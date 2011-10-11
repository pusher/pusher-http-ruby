Pusher gem
==========

Getting started
---------------

After registering at <http://pusher.com> configure your app with the security credentials

    Pusher.app_id = 'your-pusher-app-id'
    Pusher.key = 'your-pusher-key'
    Pusher.secret = 'your-pusher-secret'

Trigger an event with {Pusher::Channel#trigger!}

    Pusher['a_channel'].trigger!('an_event', {:some => 'data'})

Handle errors by rescuing `Pusher::Error` (all Pusher errors are descendants of this error)

    begin
      Pusher['a_channel'].trigger!('an_event', {:some => 'data'})
    rescue Pusher::Error => e
      # (Pusher::AuthenticationError, Pusher::HTTPError, or Pusher::Error)
    end

Optionally a socket id may be provided. This will exclude the event from being triggered on this socket id (see <http://pusher.com/docs/publisher_api_guide/publisher_excluding_recipients> for more info).

    Pusher['a_channel'].trigger!('an_event', {:some => 'data'}, socket_id)

If you don't need to handle failure cases, then you can simply use the {Pusher::Channel#trigger} method, which will rescue and log any errors for you

    Pusher['a_channel'].trigger('an_event', {:some => 'data'})

Logging
-------

Errors are logged to `Pusher.logger`. It will by default use `Logger` from stdlib, however you can assign any logger:

    Pusher.logger = Rails.logger

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

Private channels
----------------

The Pusher Gem also deals with signing requests for authenticated private channels. A quick Rails controller example:

    reponse = Pusher['private-my_channel'].authenticate(params[:socket_id])
    render :json => response
    
Read more about private channels in [the docs](http://pusher.com/docs/client_api_guide/client_channels#subscribe-private-channels) and under {Pusher::Channel#authenticate}.

Developing
----------

Use bundler in order to run specs with the correct dependencies.

    bundle
    bundle exec rspec spec/*_spec.rb

Copyright
---------

Copyright (c) 2010 New Bamboo. See LICENSE for details.
