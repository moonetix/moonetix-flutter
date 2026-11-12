import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_interface.dart';
import 'types.dart';

/// [MoonetixPlatform] implementation that talks to the native SDK over a
/// method channel. Native code calls back with `event` for lifecycle events.
class MethodChannelMoonetix extends MoonetixPlatform {
  /// The channel shared with the Android and iOS plugin classes.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('com.moonetix/offerwall');

  StreamController<MoonetixEvent>? _events;

  @override
  Stream<MoonetixEvent> get events {
    final StreamController<MoonetixEvent> controller =
        _events ??= StreamController<MoonetixEvent>.broadcast();
    channel.setMethodCallHandler(_onNativeCall);
    return controller.stream;
  }

  @override
  Future<void> init(String appId) {
    return channel.invokeMethod<void>('init', <String, Object?>{'appId': appId});
  }

  @override
  Future<void> open(String token, MoonetixOptions options) {
    return channel.invokeMethod<void>(
      'open',
      <String, Object?>{'token': token, ...options.toMap()},
    );
  }

  Future<Object?> _onNativeCall(MethodCall call) async {
    if (call.method != 'event') {
      throw MissingPluginException('Unknown method ${call.method}');
    }
    final MoonetixEvent? event = parseEvent(call.arguments);
    if (event != null) {
      _events?.add(event);
    }
    return null;
  }

  /// Turns a native event map (`type`, and `code` and `message` for errors)
  /// into a [MoonetixEvent]. Returns null for anything it does not know.
  @visibleForTesting
  static MoonetixEvent? parseEvent(Object? arguments) {
    if (arguments is! Map) {
      return null;
    }
    switch (arguments['type']) {
      case 'opened':
        return const MoonetixOpened();
      case 'closed':
        return const MoonetixClosed();
      case 'error':
        final Object? code = arguments['code'];
        final Object? message = arguments['message'];
        return MoonetixErrorEvent(MoonetixError(
          MoonetixErrorCode.fromWireName(code is String ? code : null),
          message is String && message.isNotEmpty
              ? message
              : 'The offerwall reported an error.',
        ));
    }
    return null;
  }
}
