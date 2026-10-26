#!/bin/bash
# Vanadium WebView catali (WVC): kaynak hazirlama, derleme, imzalama.
#
# Kullanim (WSL2 Ubuntu, sirayla; her adim ayri calistirilir):
#   ./vanadium-wvc.sh hazirla            # kaynak, yamalar, bagimliliklar (uzun)
#   ./vanadium-wvc.sh derle              # args.gn, gn gen, autoninja (uzun)
#   ./vanadium-wvc.sh imzala <keystore> [takma ad]
#
# Ortam degiskenleri (istege bagli):
#   WVC_WORK   calisma klasoru (varsayilan: $HOME/vanadium-wvc)
#   WVC_TAG    Vanadium etiketi (varsayilan: 156.0.8078.47.0)
#   WVC_PKG    WebView paket adi (varsayilan: org.wvc.vanadium_wv)
#   WVC_ABI    64_32 (arm64 + armeabi-v7a, varsayilan) ya da 64 (yalniz arm64)
#
# Kaynak: https://github.com/GrapheneOS/Vanadium (GPL-2.0, ayrinti LICENSE*).
# Hedef: vanadium_webview_64_32_apk ya da vanadium_webview_64_apk (yama 0302), min SDK 34.
# WebView manifesti multiArch; 32 bit ABI'leri de destekleyen cihazlarda (tucana,
# beryllium, bramble, SM-T970, jackpotlte) yalniz arm64 APK kurulmuyor:
# "The multiArch app's native libs don't support all the natively supported ABIs".

set -o errexit -o nounset -o pipefail

WORK=${WVC_WORK:-$HOME/vanadium-wvc}
TAG=${WVC_TAG:-156.0.8078.47.0}
PKG=${WVC_PKG:-org.wvc.vanadium_wv}
ABI=${WVC_ABI:-64_32}
case "$ABI" in
    64_32) TARGET=vanadium_webview_64_32_apk; APK_NAME=VanadiumWebView6432 ;;
    64)    TARGET=vanadium_webview_64_apk;    APK_NAME=VanadiumWebView64 ;;
    *) echo "!! WVC_ABI 64_32 ya da 64 olmali: $ABI" >&2; exit 1 ;;
esac
CHROMIUM_URL=https://chromium.googlesource.com/chromium/src.git
VANADIUM_URL=https://github.com/GrapheneOS/Vanadium.git
DEPOT_URL=https://chromium.googlesource.com/chromium/tools/depot_tools.git
MIN_FREE_GB=100   # Chromium docs/android_build_instructions.md: "At least 100GB of free disk space"

say() { echo "== $*"; }
die() { echo "!! $*" >&2; exit 1; }

use_depot() { export PATH="$WORK/depot_tools:$PATH"; }

chromium_version() {
    grep -m1 -o 'android_default_version_name = "[0-9.]*"' "$WORK/vanadium/args.gn" \
        | grep -o '[0-9][0-9.]*'
}

check_host() {
    [ "$(uname -s)" = Linux ] || die "Linux gerekli (WSL2 Ubuntu)."
    [ "$(uname -m)" = x86_64 ] || die "x86-64 gerekli."
    case "$WORK" in
        /mnt/*) die "WVC_WORK Windows surucusunde ($WORK). WSL'in kendi diskinde bir klasor secin." ;;
    esac
    mkdir -p "$WORK"
    local free_gb
    free_gb=$(df -BG --output=avail "$WORK" | tail -1 | tr -dc 0-9)
    say "Bos alan: ${free_gb} GB ($WORK)"
    [ "$free_gb" -ge "$MIN_FREE_GB" ] || die "En az ${MIN_FREE_GB} GB bos alan gerekli."
    say "RAM: $(free -g | awk '/^Mem:/{print $2}') GB"
}

cmd_hazirla() {
    check_host
    sudo apt-get update
    sudo apt-get install -y git python3 curl lsb-release file

    cd "$WORK"
    if [ ! -d depot_tools ]; then
        say "depot_tools"
        git clone --depth 1 "$DEPOT_URL" depot_tools
    fi
    use_depot

    if [ ! -d vanadium ]; then
        say "Vanadium $TAG"
        git clone --depth 1 --branch "$TAG" "$VANADIUM_URL" vanadium
        echo "$TAG" > vanadium/.wvc-tag
    fi
    local have
    have=$(cat vanadium/.wvc-tag 2>/dev/null || true)
    [ "$have" = "$TAG" ] || die "vanadium klasoru $TAG degil (${have:-bilinmiyor}). Klasoru silip yeniden calistirin."

    local ver
    ver=$(chromium_version)
    [ -n "$ver" ] || die "args.gn icinde surum bulunamadi."
    say "Chromium $ver"

    mkdir -p chromium
    cat > chromium/.gclient <<'EOF'
solutions = [
  {
    'name': 'src',
    'url': 'https://chromium.googlesource.com/chromium/src.git',
    'managed': False,
    'custom_deps': {
      'src/third_party/angle/third_party/VK-GL-CTS/src': None,
    },
    'custom_vars': {
      'checkout_pgo_profiles': True,
      'checkout_telemetry_dependencies': False,
    },
  },
]
hooks = [
  {
    'name': 'apply_subprojects_patches',
    'condition': 'checkout_android',
    'action': ['python3',
               '../vanadium/tools/common/apply_subprojects_patches.py',
               '--base_patch_dir', '../vanadium/subprojects_patches',
               '--src_dir', 'src'],
  },
]
target_os = ['android']
EOF

    if [ ! -d chromium/src/.git ]; then
        say "Chromium kaynagi ($ver, gecmissiz)"
        mkdir -p chromium/src
        git -C chromium/src init -q
        git -C chromium/src remote add origin "$CHROMIUM_URL"
        git -C chromium/src fetch --depth 1 origin "+refs/tags/$ver:refs/tags/$ver"
        git -C chromium/src checkout -q "$ver"
    fi

    cd chromium/src
    if [ ! -f vanadium/BUILD.gn ]; then
        say "Vanadium yamalari ($(ls "$WORK"/vanadium/patches/*.patch | wc -l) adet)"
        GIT_COMMITTER_NAME=wvc GIT_COMMITTER_EMAIL=wvc@localhost \
            git am --whitespace=nowarn --keep-non-patch "$WORK"/vanadium/patches/*.patch \
            || die "git am durdu. 'git -C $WORK/chromium/src am --abort' ile geri alip bildirin."
    else
        say "Yamalar zaten uygulanmis (vanadium/BUILD.gn var)."
    fi

    # Uzun gclient sync'ten once: apt'nin kuracagi/kaldiracagi paketler ekranda
    # gosterilir ve onay istenir (ayni dagitimda baska derleme ortami olabilir).
    say "install-build-deps (sudo parolasi ve apt onayi istenir)"
    ./build/install-build-deps.sh
    say "gclient sync (uzun surer)"
    gclient sync -D --no-history --nohooks
    say "gclient runhooks"
    gclient runhooks
    say "Hazirlama tamam. Sonraki adim: $0 derle"
}

cmd_derle() {
    use_depot
    cd "$WORK/chromium/src"
    [ -f vanadium/BUILD.gn ] || die "Once: $0 hazirla"
    mkdir -p out/Default
    {
        cat "$WORK/vanadium/args.gn"
        echo
        echo "# WVC"
        echo "system_webview_package_name = \"$PKG\""
        if [ "$ABI" = 64_32 ]; then echo "enable_android_secondary_abi = true"; fi
    } > out/Default/args.gn
    # Vanadium args.gn icindeki ayni anahtari son satir ezer; gn yinelenen atamada
    # hata verdigi icin ozgun satiri yorum yap.
    sed -i "0,/^system_webview_package_name = \"app.vanadium.webview\"/s//# &/" out/Default/args.gn
    if [ "$ABI" = 64_32 ]; then
        sed -i "0,/^enable_android_secondary_abi = false/s//# &/" out/Default/args.gn
    fi
    grep -nE 'system_webview_package_name|enable_android_secondary_abi' out/Default/args.gn
    gn gen out/Default
    say "autoninja $TARGET (uzun surer)"
    autoninja -C out/Default "$TARGET"
    ls -la "out/Default/apks/$APK_NAME.apk"
    say "Derleme tamam. Sonraki adim: $0 imzala <keystore>"
}

cmd_imzala() {
    local ks=${1:-} alias=${2:-wvc}
    [ -n "$ks" ] || die "Kullanim: $0 imzala <keystore yolu> [takma ad]"
    [ -f "$ks" ] || die "Keystore yok: $ks"
    cd "$WORK/chromium/src"
    local bt in out
    bt=$(ls -d third_party/android_sdk/public/build-tools/* | sort -V | tail -1)
    in="out/Default/apks/$APK_NAME.apk"
    [ -f "$in" ] || die "Yok: $in (WVC_ABI=$ABI ile derlendi mi?)"
    out="$WORK/VanadiumWebView-WVC-${TAG}-${ABI}.apk"
    export PATH="$PWD/third_party/jdk/current/bin:$PATH"
    "$bt/apksigner" sign --ks "$ks" --ks-key-alias "$alias" --in "$in" --out "$out"
    "$bt/apksigner" verify --print-certs "$out" | grep -E 'Signer #|DN:|SHA-256'
    "$bt/aapt2" dump badging "$out" | grep -E "^package:|^(min)?[sS]dkVersion|^targetSdkVersion|native-code" || true
    "$bt/aapt2" dump xmltree --file AndroidManifest.xml "$out" | grep -A2 'WebViewLibrary' | head -6 || true
    sha256sum "$out"
    say "Imzali APK: $out"
}

case "${1:-}" in
    hazirla) cmd_hazirla ;;
    derle)   cmd_derle ;;
    imzala)  shift; cmd_imzala "$@" ;;
    *) sed -n '2,15p' "$0"; exit 1 ;;
esac
