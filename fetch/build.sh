#!/bin/sh
# wvc-fetch.dex derlemesi: JDK (javac) ve dx (Ubuntu/Debian paketi dalvik-exchange) ya da d8.
# Kullanim: fetch/build.sh  ->  module/wvc-fetch.dex
set -eu
cd "$(dirname "$0")"
rm -rf out && mkdir -p out/classes
javac --release 8 -nowarn -d out/classes src/org/wvc/Fetch.java
if command -v dalvik-exchange >/dev/null 2>&1; then
    dalvik-exchange --dex --min-sdk-version=26 --output=out/wvc-fetch.dex out/classes
elif command -v d8 >/dev/null 2>&1; then
    d8 --release --min-api 26 --output out out/classes/org/wvc/Fetch.class && mv out/classes.dex out/wvc-fetch.dex
else
    echo "dx (dalvik-exchange) ya da d8 gerekli" >&2; exit 1
fi
cp out/wvc-fetch.dex ../module/wvc-fetch.dex
sha256sum ../module/wvc-fetch.dex
