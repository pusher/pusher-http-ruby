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

Copyright
---------

Copyright (c) 2010 New Bamboo. See LICENSE for details.
