Pusher gem
==========

Getting started
---------------

After registering at <http://pusherapp.com> configure your app with the security credentials

    Pusher.app_id = 'your-pusher-app-id'
    Pusher.key = 'your-pusher-key'
    Pusher.secret = 'your-pusher-secret'

Trigger an event. Channel and event names may only contain alphanumeric characters, '-' and '_'.

    Pusher['a_channel'].trigger('an_event', {:some => 'data'})

Optionally a socket id may be provided. This will prevent the event from being triggered on this specific socket id (see <http://pusherapp.com/docs/duplicates> for more info).

    Pusher['a_channel'].trigger('an_event', {:some => 'data'}, socket_id)

Logging
-------

Errors are logged to `Pusher.logger`. It will by default use `Logger` from stdlib, however you can assign any logger:

    Pusher.logger = Rails.logger

Asynchronous triggering
-----------------------

To avoid blocking in a typical web application, if you are running inside eventmachine (for example if you use the thin server), you may wish to use the `trigger_async` method which uses the em-http-request gem to make api requests to pusher. It returns a deferrable which you can optionally bind to with success and failure callbacks. This is not a gem dependency, so you will need to install it manually.

    d = Pusher['a_channel'].trigger_async('an_event', {:some => 'data'}, socket_id)
    d.callback {
      # Do something on success
    }
    d.errback { |error|
      # error is a pusher exception
    }

Private channels
-----------------------
The Pusher Gem also deals with signing requests for authenticated private channels. A quick Rails controller example:

    reponse = Pusher['private-my_channel'].authenticate(params[:socket_id])
    render :json => response
    
Read more about private channels in [the docs](http://pusherapp.com/docs/private_channels).

Developing
----------

Use bundler in order to run specs with the correct dependencies.

    bundle
    bundle exec spec spec/*_spec.rb

Copyright
---------

Copyright (c) 2010 New Bamboo. See LICENSE for details.
