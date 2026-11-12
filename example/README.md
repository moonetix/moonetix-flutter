# Moonetix offerwall demo

A small app that opens the Moonetix offerwall with a session token.

1. Create a session on your server: `POST https://api.moonetix.com/v1/session` with your API key and a test `user_id`.
2. Run the app, enter your App ID, paste the `token`, and tap **Open offerwall**.

A link like `moonetix-flutter-demo://open?app=<APP_ID>&token=<TOKEN>` fills both fields and opens the offerwall right away.

Tokens work once and for 10 minutes. Create a new one for each open.
