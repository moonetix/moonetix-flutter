import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel.dart';
import 'types.dart';

/// The interface each platform implementation of the Moonetix plugin
/// implements. App code uses [Moonetix] instead.
///
/// Platform implementations extend this class (not implement it), so new
/// methods can be added without breaking them.
abstract class MoonetixPlatform extends PlatformInterface {
  /// Constructs a MoonetixPlatform.
  MoonetixPlatform() : super(token: _token);

  static final Object _token = Object();

  static MoonetixPlatform _instance = MethodChannelMoonetix();

  /// The implementation in use. Defaults to [MethodChannelMoonetix].
  static MoonetixPlatform get instance => _instance;

  /// Sets the implementation, for platform packages and tests.
  static set instance(MoonetixPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Native events: opened, closed and errors reported by the native SDK.
  Stream<MoonetixEvent> get events;

  /// Stores the app ID in the native SDK. Validation already happened in
  /// Dart; the native SDK validates again.
  Future<void> init(String appId) {
    throw UnimplementedError('init() has not been implemented.');
  }

  /// Opens the offerwall with a validated session token. Errors that happen
  /// later (network, expired token) arrive on [events].
  ///
  /// Throws a `PlatformException` whose code is a [MoonetixErrorCode.wireName]
  /// when the offerwall cannot be opened at all.
  Future<void> open(String token, MoonetixOptions options) {
    throw UnimplementedError('open() has not been implemented.');
  }
}
