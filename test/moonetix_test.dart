import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonetix_offerwall/moonetix_offerwall.dart';
import 'package:moonetix_offerwall/moonetix_offerwall_platform_interface.dart';
import 'package:moonetix_offerwall/src/validation.dart';

const String appId = 'eeee35416ef2e85e9b4d8203';
final String token = 'sst_${'aZ09-_'.padRight(43, 'x')}';
const MethodChannel channel = MethodChannel('com.moonetix/offerwall');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late List<MoonetixEvent> events;
  Object? Function(MethodCall call)? reply;

  setUp(() {
    calls = <MethodCall>[];
    reply = null;
    Moonetix.resetForTesting();
    MoonetixPlatform.instance = MethodChannelMoonetix();
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return reply?.call(call);
    });
    events = <MoonetixEvent>[];
    Moonetix.events.listen(events.add);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    Moonetix.resetForTesting();
  });

  Future<void> sendNative(Map<String, Object?> event) async {
    final ByteData data =
        const StandardMethodCodec().encodeMethodCall(MethodCall('event', event));
    await messenger.handlePlatformMessage(channel.name, data, (_) {});
    await pumpEventQueue();
  }

  MoonetixError onlyError() {
    expect(events, hasLength(1));
    final MoonetixEvent event = events.single;
    expect(event, isA<MoonetixErrorEvent>());
    return (event as MoonetixErrorEvent).error;
  }

  List<String> methods() => calls.map((MethodCall c) => c.method).toList();

  group('validation', () {
    test('app ID is 24 lowercase hex characters', () {
      expect(isValidAppId(appId), isTrue);
      expect(isValidAppId(null), isFalse);
      expect(isValidAppId(''), isFalse);
      expect(isValidAppId(appId.toUpperCase()), isFalse);
      expect(isValidAppId(appId.substring(1)), isFalse);
      expect(isValidAppId('${appId}0'), isFalse);
      expect(isValidAppId('geee35416ef2e85e9b4d8203'), isFalse);
    });

    test('token is sst_ and 43 base64url characters', () {
      expect(isValidToken(token), isTrue);
      expect(isValidToken(null), isFalse);
      expect(isValidToken(''), isFalse);
      expect(isValidToken(token.substring(0, token.length - 1)), isFalse);
      expect(isValidToken('${token}x'), isFalse);
      expect(isValidToken(token.replaceFirst('sst_', 'sst-')), isFalse);
      expect(isValidToken('sst_${'+'.padRight(43, 'x')}'), isFalse);
      expect(isValidToken('sst_${'/'.padRight(43, 'x')}'), isFalse);
      expect(isValidToken('sst_${'='.padRight(43, 'x')}'), isFalse);
    });
  });

  test('version matches pubspec.yaml', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('\nversion: ${Moonetix.version}\n'));
  });

  group('open', () {
    test('before init reports notInitialized and calls nothing native', () async {
      await Moonetix.open(token);
      await pumpEventQueue();
      final MoonetixError error = onlyError();
      expect(error.code, MoonetixErrorCode.notInitialized);
      expect(error.message, 'Call Moonetix.init(appId) before Moonetix.open().');
      expect(calls, isEmpty);
    });

    test('after an invalid app ID reports invalidAppId', () async {
      await Moonetix.init('NOT-AN-ID');
      await Moonetix.open(token);
      await pumpEventQueue();
      final MoonetixError error = onlyError();
      expect(error.code, MoonetixErrorCode.invalidAppId);
      expect(
        error.message,
        'The app ID passed to Moonetix.init() is invalid. It must be the 24-character lowercase hex ID from your Moonetix dashboard.',
      );
      expect(methods(), <String>['init']);
    });

    test('a later valid init replaces an invalid one', () async {
      await Moonetix.init('bad');
      await Moonetix.init(appId);
      await Moonetix.open(token);
      await pumpEventQueue();
      expect(events, isEmpty);
      expect(methods(), <String>['init', 'init', 'open']);
    });

    test('passes the trimmed app ID and token with default options', () async {
      await Moonetix.init('  $appId \n');
      await Moonetix.open(' $token\n');
      await pumpEventQueue();
      expect(events, isEmpty);
      expect(calls[0].arguments, <String, Object?>{'appId': appId});
      expect(calls[1].arguments, <String, Object?>{
        'token': token,
        'title': null,
        'toolbarColor': null,
        'showLogo': true,
      });
    });

    test('sends the options, with the color as 32-bit ARGB', () async {
      await Moonetix.init(appId);
      await Moonetix.open(
        token,
        options: const MoonetixOptions(
          title: 'Earn coins',
          toolbarColor: Color(0xFF0B5FFF),
          showLogo: false,
        ),
      );
      expect(calls.last.arguments, <String, Object?>{
        'token': token,
        'title': 'Earn coins',
        'toolbarColor': 0xFF0B5FFF,
        'showLogo': false,
      });
    });

    for (final String bad in <String>[
      '',
      'sst_',
      'sst_short',
      'tok_${'x' * 43}',
      'sst_${'x' * 42}+',
    ]) {
      test('rejects malformed token "$bad" without a native call', () async {
        await Moonetix.init(appId);
        await Moonetix.open(bad);
        await pumpEventQueue();
        final MoonetixError error = onlyError();
        expect(error.code, MoonetixErrorCode.invalidToken);
        expect(
          error.message,
          'The session token is malformed. Pass the "token" value returned by POST /v1/session.',
        );
        expect(methods(), <String>['init']);
      });
    }

    test('a native error reply becomes an error event (iOS stub)', () async {
      reply = (MethodCall call) => call.method == 'open'
          ? throw PlatformException(code: 'UNSUPPORTED', message: 'Not available here')
          : null;
      await Moonetix.init(appId);
      await Moonetix.open(token);
      await pumpEventQueue();
      final MoonetixError error = onlyError();
      expect(error.code, MoonetixErrorCode.unsupported);
      expect(error.message, 'Not available here');
    });

    test('an unknown native error code maps to unknown', () async {
      reply = (MethodCall call) => call.method == 'open'
          ? throw PlatformException(code: 'SOMETHING_NEW')
          : null;
      await Moonetix.init(appId);
      await Moonetix.open(token);
      await pumpEventQueue();
      final MoonetixError error = onlyError();
      expect(error.code, MoonetixErrorCode.unknown);
      expect(error.message, 'The offerwall could not be opened.');
    });

    test('a platform without the plugin reports unsupported', () async {
      messenger.setMockMethodCallHandler(channel, null);
      await Moonetix.init(appId);
      await Moonetix.open(token);
      await pumpEventQueue();
      final MoonetixError error = onlyError();
      expect(error.code, MoonetixErrorCode.unsupported);
      expect(error.message, 'The Moonetix offerwall is not available on this platform.');
    });

    test('never throws', () async {
      reply = (MethodCall call) => throw PlatformException(code: 'UNKNOWN', message: 'boom');
      await expectLater(Moonetix.init(appId), completes);
      await expectLater(Moonetix.open(token), completes);
      await expectLater(Moonetix.open('bad'), completes);
    });
  });

  group('native events', () {
    test('opened, closed and errors arrive in order', () async {
      await Moonetix.init(appId);
      await sendNative(<String, Object?>{'type': 'opened'});
      await sendNative(<String, Object?>{
        'type': 'error',
        'code': 'TOKEN_EXPIRED_OR_USED',
        'message': 'This session expired.',
      });
      await sendNative(<String, Object?>{'type': 'closed'});
      expect(events, <MoonetixEvent>[
        const MoonetixOpened(),
        const MoonetixErrorEvent(MoonetixError(
          MoonetixErrorCode.tokenExpiredOrUsed,
          'This session expired.',
        )),
        const MoonetixClosed(),
      ]);
    });

    test('every native error code is understood', () {
      for (final MoonetixErrorCode code in MoonetixErrorCode.values) {
        expect(
          MethodChannelMoonetix.parseEvent(<String, Object?>{
            'type': 'error',
            'code': code.wireName,
            'message': 'm',
          }),
          MoonetixErrorEvent(MoonetixError(code, 'm')),
        );
      }
    });

    test('unknown or broken events are ignored or made safe', () {
      expect(MethodChannelMoonetix.parseEvent(null), isNull);
      expect(MethodChannelMoonetix.parseEvent('opened'), isNull);
      expect(MethodChannelMoonetix.parseEvent(<String, Object?>{'type': 'new'}), isNull);
      expect(
        MethodChannelMoonetix.parseEvent(<String, Object?>{'type': 'error', 'code': 42}),
        const MoonetixErrorEvent(MoonetixError(
          MoonetixErrorCode.unknown,
          'The offerwall reported an error.',
        )),
      );
    });
  });

  group('listener', () {
    test('receives the same events as the stream', () async {
      final List<String> seen = <String>[];
      Moonetix.setListener(MoonetixListener(
        onOpened: () => seen.add('opened'),
        onClosed: () => seen.add('closed'),
        onError: (MoonetixError e) => seen.add('error ${e.code.name}'),
      ));
      await Moonetix.open(token);
      await sendNative(<String, Object?>{'type': 'opened'});
      await sendNative(<String, Object?>{'type': 'closed'});
      expect(seen, <String>['error notInitialized', 'opened', 'closed']);
    });

    test('null removes it and a new one replaces it', () async {
      final List<String> first = <String>[];
      final List<String> second = <String>[];
      Moonetix.setListener(MoonetixListener(onOpened: () => first.add('opened')));
      Moonetix.setListener(MoonetixListener(onOpened: () => second.add('opened')));
      await sendNative(<String, Object?>{'type': 'opened'});
      Moonetix.setListener(null);
      await sendNative(<String, Object?>{'type': 'opened'});
      expect(first, isEmpty);
      expect(second, <String>['opened']);
    });

    test('callbacks are optional', () async {
      Moonetix.setListener(const MoonetixListener());
      await sendNative(<String, Object?>{'type': 'opened'});
      await sendNative(<String, Object?>{'type': 'error', 'code': 'NETWORK', 'message': 'x'});
      expect(events, hasLength(2));
    });
  });

  test('options and errors compare by value', () {
    expect(
      const MoonetixOptions(title: 'a', toolbarColor: Color(0xFF000000)),
      const MoonetixOptions(title: 'a', toolbarColor: Color(0xFF000000)),
    );
    expect(const MoonetixOptions(), isNot(const MoonetixOptions(showLogo: false)));
    expect(
      const MoonetixError(MoonetixErrorCode.network, 'x').toString(),
      'MoonetixError(NETWORK): x',
    );
  });
}
