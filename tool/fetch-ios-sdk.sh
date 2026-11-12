#!/bin/sh
# Downloads the released Moonetix iOS SDK binary, checks its SHA-256 and unpacks it to DEST.
# Only needed to build from this source. Installs from the registry already include it.
set -eu

VERSION="2.0.1"
SHA256="03cd07f6d72c2e30722bcc950286207c3dfd494c39a9a6546389f87cb8da42fd"
URL="https://moonetix.com/ios/MoonetixOfferwall-${VERSION}.xcframework.zip"
DEST="${1:-ios/moonetix_offerwall/Frameworks}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL --retry 3 -o "$tmp/sdk.zip" "$URL"
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "$tmp/sdk.zip" | cut -d' ' -f1)"
else
  actual="$(shasum -a 256 "$tmp/sdk.zip" | cut -d' ' -f1)"
fi
if [ "$actual" != "$SHA256" ]; then
  echo "Checksum mismatch: expected $SHA256, got $actual" >&2
  exit 1
fi

unzip -q "$tmp/sdk.zip" -d "$tmp/out"
mkdir -p "$DEST"
rm -rf "$DEST/MoonetixOfferwall.xcframework"
mv "$tmp/out/MoonetixOfferwall.xcframework" "$DEST/"
echo "MoonetixOfferwall.xcframework ${VERSION} is in $DEST"
