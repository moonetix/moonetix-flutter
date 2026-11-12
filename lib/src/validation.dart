// Same formats and messages as the native SDKs.

final RegExp _appIdPattern = RegExp(r'^[a-f0-9]{24}$');
final RegExp _tokenPattern = RegExp(r'^sst_[A-Za-z0-9_-]{43}$');

/// Whether [appId] is a Moonetix app ID: 24 lowercase hex characters.
bool isValidAppId(String? appId) =>
    appId != null && _appIdPattern.hasMatch(appId);

/// Whether [token] is a session token: `sst_` and 43 base64url characters.
bool isValidToken(String? token) =>
    token != null && _tokenPattern.hasMatch(token);

/// Message for an app ID that failed validation in `Moonetix.init`.
const String invalidAppIdMessage =
    'The app ID passed to Moonetix.init() is invalid. It must be the 24-character lowercase hex ID from your Moonetix dashboard.';

/// Message for `Moonetix.open` before `Moonetix.init`.
const String notInitializedMessage =
    'Call Moonetix.init(appId) before Moonetix.open().';

/// Message for a malformed session token.
const String invalidTokenMessage =
    'The session token is malformed. Pass the "token" value returned by POST /v1/session.';

/// Message for a platform without a native implementation (web, desktop).
const String unsupportedPlatformMessage =
    'The Moonetix offerwall is not available on this platform.';
