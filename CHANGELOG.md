# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [2.0.1] - 2026-11-11

### Changed

- Android: uses `com.moonetix:offerwall:2.0.1`. iOS: uses `MoonetixOfferwall` 2.0.1, bundled with the plugin.
- Only pages on `wall.moonetix.com` stay inside the offerwall screen. Every other host opens outside the app.
- The top bar logo loads only from `moonetix.com` and `wall.moonetix.com`.

## [2.0.0] - 2026-11-06

### Changed

- First release under the Moonetix name. The previous package stays published and keeps working.
- Package `moonetix_offerwall`, class `Moonetix`, types `MoonetixOptions`, `MoonetixListener` and `MoonetixError`.
- Android: uses `com.moonetix:offerwall:2.0.0` from https://moonetix.com/maven.
- iOS: uses `MoonetixOfferwall` 2.0.0, bundled with the plugin.
- The wall opens on `wall.moonetix.com`.
