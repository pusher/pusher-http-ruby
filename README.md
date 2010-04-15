Pusher gem
==========

Getting started
---------------

After registering at <http://pusherapp.com> configure your app with the security credentials

    Pusher.app_id = 'your-pusher-app-id'
    Pusher.key = 'your-pusher-key'
    Pusher.secret = 'your-pusher-secret'

Trigger an event

    Pusher['arbitrary-channel-name'].trigger({:some => 'data'})
    
Logging
-------

Errors are logged to `Pusher.logger`. It will by default use `Logger` from stdlib, however you can assign any logger:

    Pusher.logger = Rails.logger

Copyright
---------

Copyright (c) 2010 New Bamboo. See LICENSE for details.
