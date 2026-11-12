import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// Appearance options for the offerwall screen.
///
/// By default the top bar shows the Moonetix mark with the title and colors
/// from the Design tab of your Moonetix dashboard, loaded automatically.
/// Set an option here only to override it.
@immutable
class MoonetixOptions {
  /// Creates appearance options. Every value is optional.
  const MoonetixOptions({this.title, this.toolbarColor, this.showLogo = true});

  /// Text shown in the top bar. `null` (default) uses the title from your
  /// Design tab, or "Earn rewards" when none is set.
  final String? title;

  /// Color of the top bar. `null` (default) uses the background color from
  /// your Design tab, or a neutral light or dark bar that follows the system
  /// theme. The title and close icon always keep a readable contrast.
  final Color? toolbarColor;

  /// Whether to show the Moonetix mark next to the title.
  final bool showLogo;

  /// The options as sent to the native SDK. The color is a 32-bit ARGB value.
  Map<String, Object?> toMap() => <String, Object?>{
        'title': title,
        'toolbarColor': toolbarColor?.toARGB32(),
        'showLogo': showLogo,
      };

  @override
  bool operator ==(Object other) =>
      other is MoonetixOptions &&
      other.title == title &&
      other.toolbarColor == toolbarColor &&
      other.showLogo == showLogo;

  @override
  int get hashCode => Object.hash(title, toolbarColor, showLogo);

  @override
  String toString() =>
      'MoonetixOptions(title: $title, toolbarColor: $toolbarColor, showLogo: $showLogo)';
}

/// Error categories reported in [MoonetixError.code].
enum MoonetixErrorCode {
  /// [Moonetix.open] was called before [Moonetix.init].
  notInitialized('NOT_INITIALIZED'),

  /// The app ID passed to [Moonetix.init] is not a 24-character lowercase hex
  /// string.
  invalidAppId('INVALID_APP_ID'),

  /// The token is malformed, or the server does not know it (HTTP 404).
  invalidToken('INVALID_TOKEN'),

  /// The token expired (10 minutes) or was already used (HTTP 410). Request a
  /// new one from your server.
  tokenExpiredOrUsed('TOKEN_EXPIRED_OR_USED'),

  /// The offerwall could not be reached. The screen shows a retry button.
  network('NETWORK'),

  /// The offerwall is not available on this platform (web and desktop).
  unsupported('UNSUPPORTED'),

  /// Anything else, for example no WebView available on the device.
  unknown('UNKNOWN');

  const MoonetixErrorCode(this.wireName);

  /// The code as sent by the native SDKs, for example `TOKEN_EXPIRED_OR_USED`.
  final String wireName;

  /// Maps a native code to a [MoonetixErrorCode]. Unknown values map to
  /// [MoonetixErrorCode.unknown].
  static MoonetixErrorCode fromWireName(String? name) {
    for (final MoonetixErrorCode code in values) {
      if (code.wireName == name) {
        return code;
      }
    }
    return unknown;
  }
}

/// An error reported through [Moonetix.events] and [MoonetixListener.onError].
///
/// The message is meant for logs. It never contains the session token.
@immutable
class MoonetixError implements Exception {
  /// Creates an error.
  const MoonetixError(this.code, this.message);

  /// Machine-readable category of the error.
  final MoonetixErrorCode code;

  /// Human-readable description for logs.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is MoonetixError && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'MoonetixError(${code.wireName}): $message';
}

/// An offerwall lifecycle event, delivered on [Moonetix.events].
///
/// These events are for UI purposes only. Never credit rewards from them:
/// rewards must be credited only from the signed server-to-server postback.
@immutable
sealed class MoonetixEvent {
  const MoonetixEvent();
}

/// The offerwall finished loading its first page.
final class MoonetixOpened extends MoonetixEvent {
  /// Creates the event.
  const MoonetixOpened();

  @override
  bool operator ==(Object other) => other is MoonetixOpened;

  @override
  int get hashCode => (MoonetixOpened).hashCode;

  @override
  String toString() => 'MoonetixOpened()';
}

/// The offerwall screen was closed (close button, back, or the system).
/// Fired once per [Moonetix.open] that showed the screen.
final class MoonetixClosed extends MoonetixEvent {
  /// Creates the event.
  const MoonetixClosed();

  @override
  bool operator ==(Object other) => other is MoonetixClosed;

  @override
  int get hashCode => (MoonetixClosed).hashCode;

  @override
  String toString() => 'MoonetixClosed()';
}

/// Something went wrong. See [MoonetixError.code].
final class MoonetixErrorEvent extends MoonetixEvent {
  /// Creates the event.
  const MoonetixErrorEvent(this.error);

  /// What went wrong.
  final MoonetixError error;

  @override
  bool operator ==(Object other) =>
      other is MoonetixErrorEvent && other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'MoonetixErrorEvent($error)';
}

/// Callbacks for offerwall events, an alternative to listening to
/// [Moonetix.events]. Set it with [Moonetix.setListener]. Every callback is
/// optional and runs on the main isolate.
@immutable
class MoonetixListener {
  /// Creates a listener with the callbacks you need.
  const MoonetixListener({this.onOpened, this.onClosed, this.onError});

  /// The offerwall finished loading its first page.
  final VoidCallback? onOpened;

  /// The offerwall screen was closed. A good moment to load the user's
  /// balance from your server.
  final VoidCallback? onClosed;

  /// Something went wrong. The plugin never throws for these cases.
  final void Function(MoonetixError error)? onError;
}
