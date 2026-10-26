#!/bin/bash
# WVC GitHub surumu.
#
# Kullanim (depo kokunde, gh oturumu acik):
#   ./release.sh module   <WVC-vX.Y.zip>
#   ./release.sh vanadium <VanadiumWebView-WVC-<etiket>-64_32.apk>
#   (imza denetimi icin: APKSIGNER=<apksigner yolu> ./release.sh vanadium ...)
#
# Denetimler: calisma agaci temiz ve HEAD GitHub'da; dosya adi ve surum tutarli;
# test notu var ve dosyanin SHA-256'sini iceriyor; modul zip'inin
# icerigi module/ ile ayni; update.json surumu tutuyor; depoda kisisel bilgisayar
# yolu yok. Sonra SHA256SUMS uretilir ve gh release create calisir.

set -o errexit -o nounset -o pipefail

die() { echo "!! $*" >&2; exit 1; }
say() { echo "== $*"; }

KIND=${1:-}
FILE=${2:-}
[ -n "$KIND" ] && [ -n "$FILE" ] || { sed -n '2,13p' "$0"; exit 1; }
[ -f "$FILE" ] || die "Dosya yok: $FILE"
FILE=$(readlink -f "$FILE")
cd "$(dirname "$0")"

command -v gh >/dev/null || die "gh gerekli"
[ -z "$(git status --porcelain)" ] || die "Calisma agaci temiz degil (git status)."
git fetch -q origin
HEAD=$(git rev-parse HEAD)
git branch -r --contains "$HEAD" | grep -q . || die "HEAD ($HEAD) GitHub'da yok; once git push."

# Kisisel yol denetimi (Windows surucu yollari, WSL /mnt/<surucu>, ev klasorleri)
if git grep -nIE '([A-Za-z]:\\+(Users|Mobil|kerem)|/mnt/[a-z]/|/home/[a-z][a-z0-9_-]*/)' -- . ':!LICENSE' ':!release.sh'; then
    die "Yukaridaki satirlarda kisisel bilgisayar yolu var."
fi

NAME=$(basename "$FILE")
SUM=$(sha256sum "$FILE" | cut -d' ' -f1)

check_notes() {
    local notes=$1
    [ -f "$notes" ] || die "Test notu yok: $notes"
    grep -q "$SUM" "$notes" || die "Test notu $NAME SHA-256'sini ($SUM) icermiyor."
}

OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

case "$KIND" in
module)
    VER=$(sed -n 's/^version=//p' module/module.prop)
    VC=$(sed -n 's/^versionCode=//p' module/module.prop)
    [ "$NAME" = "WVC-$VER.zip" ] || die "Dosya adi WVC-$VER.zip olmali (module.prop version=$VER)."
    grep -q "\"version\": \"$VER\"" update.json || die "update.json version $VER degil."
    grep -q "\"versionCode\": $VC" update.json || die "update.json versionCode $VC degil."
    grep -q "/download/$VER/$NAME" update.json || die "update.json zipUrl $VER/$NAME gostermiyor."
    grep -q "^## $VER " CHANGELOG.md || die "CHANGELOG.md'de $VER bolumu yok."
    # zip icerigi module/ ile ayni olmali
    while IFS= read -r f; do
        case "$f" in */) continue ;; esac
        [ -f "module/$f" ] || die "zip'teki $f module/ altinda yok."
        unzip -p "$FILE" "$f" | cmp -s - "module/$f" || die "zip'teki $f module/$f ile farkli."
    done < <(unzip -Z1 "$FILE")
    n_zip=$(unzip -Z1 "$FILE" | grep -vc '/$')
    n_mod=$(find module -type f | wc -l)
    [ "$n_zip" = "$n_mod" ] || die "zip $n_zip, module/ $n_mod dosya iceriyor."
    NOTES=test-notes/$VER.md
    check_notes "$NOTES"
    TAG=$VER
    TITLE="WVC $VER"
    cp "$FILE" "$OUT/"
    cp tools/wvc-tani.ps1 tools/wvc-tani.sh tools/anr-tani.sh "$OUT/"
    cp "$NOTES" "$OUT/TEST-NOTES.md"
    LATEST=--latest
    ;;
vanadium)
    case "$NAME" in
        VanadiumWebView-WVC-*-64_32.apk) VTAG=${NAME#VanadiumWebView-WVC-}; VTAG=${VTAG%-64_32.apk} ;;
        *) die "Dosya adi VanadiumWebView-WVC-<etiket>-64_32.apk olmali." ;;
    esac
    NOTES=test-notes/vanadium-$VTAG.md
    check_notes "$NOTES"
    # apksigner: PATH'te ya da APKSIGNER ortam degiskeninde (Chromium agacindaki
    # third_party/android_sdk/public/build-tools/<surum>/apksigner)
    APKSIGNER=${APKSIGNER:-$(command -v apksigner || true)}
    if [ -n "$APKSIGNER" ]; then
        "$APKSIGNER" verify --print-certs "$FILE" 2>/dev/null \
            | grep -q '40342a299f0c62287330134005e5d5df8901ec3cd6c1c1b2e884396ca6332a88' \
            || die "APK WVC anahtariyla imzali degil."
    else
        say "apksigner yok, imza denetimi atlandi (test notundaki sertifika degerine bakin)."
    fi
    TAG=vanadium-$VTAG
    TITLE="Vanadium WVC fork $VTAG"
    cp "$FILE" "$OUT/"
    cp "$NOTES" "$OUT/TEST-NOTES.md"
    LATEST=--latest=false
    ;;
*) die "Tur module ya da vanadium olmali." ;;
esac

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "Etiket zaten var: $TAG"

(cd "$OUT" && sha256sum -- * > SHA256SUMS)
say "Etiket $TAG, commit $HEAD"
cat "$OUT/SHA256SUMS"
read -r -p "Yayinlansin mi? (e/h) " ok
[ "$ok" = e ] || die "Vazgecildi."

gh release create "$TAG" --target "$HEAD" --title "$TITLE" --notes-file "$NOTES" "$LATEST" "$OUT"/*
say "Yayinlandi: $TAG"
