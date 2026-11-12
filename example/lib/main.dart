import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonetix_offerwall/moonetix_offerwall.dart';

// Demo app: paste your App ID and a fresh session token from your server,
// then open the offerwall. A link like
// moonetix-flutter-demo://open?app=<APP_ID>&token=<TOKEN> fills both and opens
// the offerwall right away.
//
// In a real app the token comes from your own server, which calls
// POST https://api.moonetix.com/v1/session with your API key. Never put the
// API key in the app.

void main() {
  runApp(const DemoApp());
}

/// App ID and token taken from a demo link or from pasted text.
class DemoLink {
  const DemoLink({this.appId, this.token});

  final String? appId;
  final String? token;

  static final RegExp _appId = RegExp(r'^[a-f0-9]{24}$');
  static final RegExp _token = RegExp(r'sst_[A-Za-z0-9_-]{43}');

  /// Reads `app` and `token` from a route or a full demo link. Returns null
  /// when the text carries neither.
  static DemoLink? parse(String? text) {
    if (text == null || !text.contains('?')) {
      return null;
    }
    final Uri? uri = Uri.tryParse(text.trim());
    if (uri == null) {
      return null;
    }
    final String? app = uri.queryParameters['app'];
    final String? token = uri.queryParameters['token'];
    final DemoLink link = DemoLink(
      appId: app != null && _appId.hasMatch(app) ? app : null,
      token: token != null && _token.hasMatch(token) ? token : null,
    );
    return link.appId == null && link.token == null ? null : link;
  }

  /// Finds a token (and an App ID, if it is a demo link) in pasted text.
  static DemoLink? fromClipboard(String text) {
    final DemoLink? link = parse(text);
    if (link != null) {
      return link;
    }
    final Match? match = _token.firstMatch(text);
    return match == null ? null : DemoLink(token: match.group(0));
  }
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  static const Color _brand = Color(0xFF0B5FFF);

  Route<void> _route(String? name) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: name == null || name.contains('?') ? '/' : name),
      builder: (BuildContext context) => DemoPage(link: DemoLink.parse(name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moonetix demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _brand, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: _brand,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      onGenerateInitialRoutes: (String initialRoute) => <Route<void>>[_route(initialRoute)],
      onGenerateRoute: (RouteSettings settings) => _route(settings.name),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key, this.link});

  final DemoLink? link;

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final TextEditingController _appId = TextEditingController();
  final TextEditingController _token = TextEditingController();
  final List<String> _log = <String>[];
  StreamSubscription<MoonetixEvent>? _events;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _events = Moonetix.events.listen(_onEvent);
    _add('Plugin ${Moonetix.version} ready');
    final DemoLink? link = widget.link;
    if (link != null) {
      _apply(link, source: 'link');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _started = true;
      if (link != null) {
        _openFromLink();
      }
    });
  }

  void _openFromLink() {
    if (!mounted) {
      return;
    }
    // A link that arrives while the app is open pushes a new page; keep only this one.
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    final NavigatorState navigator = Navigator.of(context);
    if (route != null && navigator.canPop()) {
      navigator.removeRouteBelow(route);
    }
    if (_appId.text.isNotEmpty && _token.text.isNotEmpty) {
      unawaited(_open());
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _appId.dispose();
    _token.dispose();
    super.dispose();
  }

  void _onEvent(MoonetixEvent event) {
    switch (event) {
      case MoonetixOpened():
        _add('Opened');
      case MoonetixClosed():
        _add('Closed. Now reload the balance from your server.');
      case MoonetixErrorEvent(:final MoonetixError error):
        _add('Error ${error.code.wireName}: ${error.message}');
    }
  }

  void _apply(DemoLink link, {required String source}) {
    if (link.appId != null) {
      _appId.text = link.appId!;
    }
    if (link.token != null) {
      _token.text = link.token!;
    }
    _add('Filled from $source');
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final DemoLink? link = DemoLink.fromClipboard(data?.text ?? '');
    if (!mounted) {
      return;
    }
    if (link == null) {
      _add('No token found in the clipboard');
      return;
    }
    _apply(link, source: 'clipboard');
  }

  Future<void> _open() async {
    await Moonetix.init(_appId.text);
    await Moonetix.open(_token.text);
    // Tokens work once: clear the field so the same one is not reused by accident.
    _token.clear();
  }

  void _add(String line) {
    final TimeOfDay now = TimeOfDay.now();
    final String time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    void insert() {
      _log.insert(0, '$time  $line');
      if (_log.length > 50) {
        _log.removeLast();
      }
    }

    // initState runs before the first build, so it may not call setState.
    if (_started && mounted) {
      setState(insert);
    } else {
      insert();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Moonetix offerwall demo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Your server creates a session token with POST /v1/session. '
              'Paste it here, or open a demo link, then open the offerwall.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _appId,
              decoration: const InputDecoration(
                labelText: 'App ID',
                hintText: '24 characters, from the Integration tab',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _token,
              decoration: InputDecoration(
                labelText: 'Session token',
                hintText: 'sst_...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste),
                  onPressed: _paste,
                ),
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _open,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open offerwall'),
            ),
            const SizedBox(height: 24),
            Text('Events', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final String line in _log)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  line,
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
