import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_interface.dart';
import 'types.dart';
import 'validation.dart';

/// Entry point of the Moonetix offerwall plugin.
///
/// ```dart
/// await Moonetix.init('YOUR_APP_ID');
/// Moonetix.events.listen((event) { ... });
/// // token = fresh single-use session token fetched from YOUR server
/// await Moonetix.open(token);
/// ```
///
/// Problems (not initialized, malformed token, network, expired token,
/// unsupported platform) are delivered on [events] and to the
/// [MoonetixListener]. The methods never throw for them.
abstract final class Moonetix {
  /// Version of this plugin.
  static const String version = '2.0.1';

  static String? _appId;
  static bool _initRejected = false;

  static StreamController<MoonetixEvent>? _bus;
  static MoonetixPlatform? _wiredTo;
  static StreamSubscription<MoonetixEvent>? _nativeSub;
  static StreamSubscription<MoonetixEvent>? _listenerSub;

  /// Offerwall events: [MoonetixOpened], [MoonetixClosed] and
  /// [MoonetixErrorEvent]. A broadcast stream; events are not buffered, so
  /// listen before you call [open].
  ///
  /// Use the events for your UI only. Never credit rewards from them: credit
  /// rewards only from the signed postback on your server.
  static Stream<MoonetixEvent> get events => _wire().stream;

  /// Initializes the plugin with your Moonetix app ID (24 lowercase hex
  /// characters, shown in the Integration tab of your app). Call it once, for
  /// example in `main()`. You do not need to await it.
  ///
  /// An invalid value is not stored. Every following [open] call then reports
  /// [MoonetixErrorCode.invalidAppId] instead of opening.
  static Future<void> init(String appId) async {
    _wire();
    final String trimmed = appId.trim();
    if (isValidAppId(trimmed)) {
      _appId = trimmed;
      _initRejected = false;
    } else {
      _appId = null;
      _initRejected = true;
      developer.log(invalidAppIdMessage, name: 'Moonetix', level: 900);
    }
    try {
      await MoonetixPlatform.instance.init(trimmed);
    } on PlatformException catch (e) {
      developer.log('init failed: ${e.code}', name: 'Moonetix', level: 900);
    } on MissingPluginException {
      // Reported by open(), like every other problem.
    }
  }

  /// Opens the offerwall full screen.
  ///
  /// [token] is a fresh session token (`sst_...`) that your server got from
  /// `POST https://api.moonetix.com/v1/session`. Tokens are single-use and
  /// expire after 10 minutes, so request a new one for every [open] call.
  ///
  /// [options] overrides the top bar. By default it shows the Moonetix mark
  /// with the title and colors from the Design tab of your dashboard.
  ///
  /// The returned future completes once the request reached the native SDK.
  /// It never throws for offerwall problems: they arrive on [events].
  static Future<void> open(
    String token, {
    MoonetixOptions options = const MoonetixOptions(),
  }) async {
    _wire();
    if (_appId == null) {
      _emitError(
        _initRejected
            ? MoonetixErrorCode.invalidAppId
            : MoonetixErrorCode.notInitialized,
        _initRejected ? invalidAppIdMessage : notInitializedMessage,
      );
      return;
    }
    final String cleanToken = token.trim();
    if (!isValidToken(cleanToken)) {
      _emitError(MoonetixErrorCode.invalidToken, invalidTokenMessage);
      return;
    }
    try {
      await MoonetixPlatform.instance.open(cleanToken, options);
    } on PlatformException catch (e) {
      _emitError(
        MoonetixErrorCode.fromWireName(e.code),
        e.message ?? 'The offerwall could not be opened.',
      );
    } on MissingPluginException {
      _emitError(MoonetixErrorCode.unsupported, unsupportedPlatformMessage);
    }
  }

  /// Sets callbacks for the offerwall events, or `null` to remove them.
  /// The same events are also on [events]; use whichever you prefer.
  static void setListener(MoonetixListener? listener) {
    unawaited(_listenerSub?.cancel());
    _listenerSub = null;
    if (listener == null) {
      return;
    }
    _listenerSub = events.listen((MoonetixEvent event) {
      switch (event) {
        case MoonetixOpened():
          listener.onOpened?.call();
        case MoonetixClosed():
          listener.onClosed?.call();
        case MoonetixErrorEvent(:final MoonetixError error):
          listener.onError?.call(error);
      }
    });
  }

  /// Forgets the app ID and the listener. For tests only.
  @visibleForTesting
  static void resetForTesting() {
    unawaited(_listenerSub?.cancel());
    unawaited(_nativeSub?.cancel());
    unawaited(_bus?.close());
    _listenerSub = null;
    _nativeSub = null;
    _bus = null;
    _wiredTo = null;
    _appId = null;
    _initRejected = false;
  }

  static StreamController<MoonetixEvent> _wire() {
    final StreamController<MoonetixEvent> bus =
        _bus ??= StreamController<MoonetixEvent>.broadcast();
    final MoonetixPlatform platform = MoonetixPlatform.instance;
    if (!identical(_wiredTo, platform)) {
      unawaited(_nativeSub?.cancel());
      _nativeSub = platform.events.listen(bus.add);
      _wiredTo = platform;
    }
    return bus;
  }

  static void _emitError(MoonetixErrorCode code, String message) {
    _wire().add(MoonetixErrorEvent(MoonetixError(code, message)));
  }
}
