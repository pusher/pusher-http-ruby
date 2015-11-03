0.15.1 / 2015-11-03
==================

  * Fixed a bug where the `authenticate` method added in 0.15.0 wasn't exposed on the Pusher class.

0.15.0 / 2015-11-02
==================

  * Added `Pusher.authenticate` method for authenticating private and presence channels.
    This is prefered over the older `Pusher['a_channel'].authenticate(...)` style.

0.14.6 / 2015-09-29
==================
  * Updated to use the `pusher-signature` gem instead of `signature`.
    This resolves namespace related issues.

0.14.5 / 2015-05-11
==================

  * SECURITY: Prevent auth delegation trough crafted socket IDs

0.14.4 / 2015-01-20
==================

  * SECURITY: Prevent timing attack, update signature to v0.1.8
  * SECURITY: Prevent POODLE. Disable SSLv3, update httpclient to v2.5
  * Fix channel name character limit.
  * Adds support for listing users on a presence channel

0.14.3 / 2015-01-20
==================

Yanked, bad release

0.14.2 / 2014-10-16
==================

First release with a changelog !

  * Bump httpclient to v2.4. See #62 (POODLE SSL)
  * Fix limited channel count at README.md. Thanks @tricknotes

