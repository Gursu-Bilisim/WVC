# WVC ortak islevler. customize.sh, service.sh ve action.sh tarafindan okunur.
# POSIX sh (Magisk/KernelSU/APatch busybox ash).

WVC_ID=WVC
WVC_LIVE=/data/adb/modules/$WVC_ID
WVC_ANYWEBVIEW=com.thinkdifferent.anywebview

# Dil: sistem dili Turkce ise Turkce, degilse Ingilizce.
# Ayarlar'da secilen dil "system_locales" ayarinda (virgulle ayrilmis liste, ilki
# gecerli). persist.sys.locale her ROM'da yazilmiyor: SM-T970'te bos,
# ro.product.locale en-US, system_locales tr-TR (2026-10-27). Sira: system_locales,
# persist.sys.locale, ro.product.locale.
wvc_locale() {
    _l=$(settings get system system_locales 2>/dev/null)
    case "$_l" in ''|null) _l=$(getprop persist.sys.locale) ;; esac
    [ -n "$_l" ] || _l=$(getprop ro.product.locale)
    echo "${_l%%,*}"
}
# settings ayar saglayicisi acilis tamamlanmadan yanit vermez; service.sh dili
# boot_completed'den sonra wvc_set_lang ile yeniden belirler (v9.3 test 1,
# SM-T970: acilista okunan dil Ingilizce kaldi).
wvc_set_lang() {
    case "$(wvc_locale)" in
        tr*) WVC_LANG="tr" ;;
        *) WVC_LANG="en" ;;
    esac
}
wvc_set_lang
# m "Turkce metin" "English text"
m() { if [ "$WVC_LANG" = tr ]; then printf '%s\n' "$1"; else printf '%s\n' "$2"; fi; }

# Paket -> gorunen ad
wvc_name() {
    case "$1" in
        org.axpos.aosmium_wv) echo "AOSmium" ;;
        org.wvc.vanadium_wv) echo "Vanadium" ;;
        com.android.webview) echo "Cromite" ;;
        app.vanadium.webview) echo "Vanadium (GrapheneOS)" ;;
        com.google.android.webview) echo "Google WebView" ;;
        *) echo "$1" ;;
    esac
}

# Paket -> sistem kurulumu klasor adi
wvc_dir() {
    case "$1" in
        org.axpos.aosmium_wv) echo "AOSmiumWebView" ;;
        org.wvc.vanadium_wv) echo "VanadiumWebViewWVC" ;;
        com.android.webview) echo "CromiteWebView" ;;
        *) echo "" ;;
    esac
}

# APK -> paket adi. aapt cihazda yok; ikili manifestteki dizgilerden okunur.
# Dizgi havuzunda uzunluk baytlari bazen yazilabilir karakter oldugu icin
# (ornek "...aosmium_wv1org...") tam sozcuk eslemesi guvenilir degil; ayirt
# edici adlar sirayla alt dizgi olarak aranir. Her WebView manifesti
# "com.android.webview.WebViewLibrary" tasidigi icin com.android.webview en son,
# digerleri bulunamazsa secilir.
wvc_apk_pkg() {
    _m=$(unzip -p "$1" AndroidManifest.xml 2>/dev/null | tr -d '\000')
    [ -n "$_m" ] || return 1
    for _p in org.axpos.aosmium_wv org.wvc.vanadium_wv app.vanadium.webview \
              com.google.android.webview; do
        if echo "$_m" | grep -aqF "$_p"; then
            echo "$_p"
            return 0
        fi
    done
    if echo "$_m" | grep -aqF "com.android.webview.WebViewLibrary"; then
        echo "com.android.webview"
        return 0
    fi
    return 1
}

# APK'da eksik olan, cihazin destekledigi ABI'ler (bos ise tamam).
# WebView manifesti multiArch; cihazin her ABI'si icin kutuphane gerekir.
wvc_abi_missing() {
    # busybox unzip -l dosya suzgecinde eslesme olmasa da 0 donuyor (tucana,
    # 2026-10-26); liste grep ile aranir.
    _miss=""
    _ls=$(unzip -l "$1" 2>/dev/null)
    for _a in $(getprop ro.product.cpu.abilist | tr ',' ' '); do
        case "$_a" in
            arm64-v8a|armeabi-v7a)
                echo "$_ls" | grep -q "lib/$_a/libwebviewchromium.so" \
                    || _miss="$_miss $_a" ;;
        esac
    done
    echo "$_miss"
}

# APK'yi stdin uzerinden kurar (/sdcard yolunu system_server okuyamayabilir).
wvc_pm_install() {
    _size=$(stat -c %s "$1")
    cat "$1" | pm install -r -S "$_size" 2>&1
}

# Her kullanici/profil icin kurulu oldugundan emin ol (kapi 6).
wvc_all_users() {
    for _u in $(pm list users 2>/dev/null | sed -n 's/.*UserInfo{\([0-9]*\):.*/\1/p'); do
        pm install-existing --user "$_u" "$1" >/dev/null 2>&1
    done
}

wvc_version() {
    dumpsys package "$1" 2>/dev/null | grep -m1 'versionName=' | sed 's/.*versionName=//'
}

# Modulun etkin olup olmadigi (disable/remove dosyasi yok)
wvc_mod_on() {
    [ -d "/data/adb/modules/$1" ] && [ ! -f "/data/adb/modules/$1/disable" ] \
        && [ ! -f "/data/adb/modules/$1/remove" ]
}

wvc_root() {
    if [ "$KSU" = true ]; then echo KernelSU
    elif [ "$APATCH" = true ] || [ -d /data/adb/ap ]; then echo APatch
    elif [ -d /data/adb/magisk ]; then echo Magisk
    else m "bilinmiyor" "unknown"; fi
}

# Zygisk saglayicisi etkin mi: Magisk yerlesik ya da modul (Zygisk Next, ReZygisk, NeoZygisk)
wvc_zygisk() {
    for _m in zygisksu rezygisk neozygisk; do
        if wvc_mod_on "$_m"; then echo "$_m"; return 0; fi
    done
    if command -v magisk >/dev/null 2>&1; then
        if magisk --sqlite "SELECT value FROM settings WHERE key='zygisk'" 2>/dev/null \
            | grep -q 'value=1'; then
            echo "Magisk"; return 0
        fi
    fi
    for _m in zygisksu rezygisk neozygisk; do
        if [ -d "/data/adb/modules/$_m" ]; then m "$_m (kapalı)" "$_m (disabled)"; return 1; fi
    done
    m "yok" "none"
    return 1
}

wvc_lsposed() {
    for _m in zygisk_lsposed lsposed zygisk_lsposed_npatch; do
        if wvc_mod_on "$_m"; then
            echo "$_m $(grep -m1 '^version=' "/data/adb/modules/$_m/module.prop" | cut -d= -f2)"
            return 0
        fi
    done
    m "yok" "none"
    return 1
}

# KernelSU/APatch'te sistem kurulumu icin metamodul (bagla isi onda)
wvc_metamodule() {
    for _d in /data/adb/modules/*; do
        [ -d "$_d" ] || continue
        _n=${_d##*/}
        wvc_mod_on "$_n" || continue
        if [ -f "$_d/metamount.sh" ] || grep -q '^metamodule=' "$_d/module.prop" 2>/dev/null; then
            echo "$_n"; return 0
        fi
    done
    # Hybrid Mount 6.2.x ile sistem kurulumu dogrulandi (beryllium, 2026-10-23)
    if wvc_mod_on hybrid_mount; then echo hybrid_mount; return 0; fi
    return 1
}

# AnyWebView kanca satirlari: LSPosed dosya gunlugu, yoksa logcat
wvc_hook_log() {
    _f=$(ls -t /data/adb/lspd/log/modules_*.log 2>/dev/null | head -1)
    {
        [ -n "$_f" ] && grep -a 'anywebview' "$_f"
        logcat -d -b all 2>/dev/null | grep -a 'LSPosedFramework' | grep -a 'anywebview'
    } | grep -aE 'entry point loaded|getWebViewPackages missing|hooking getWebViewPackages|failed to hook|stock providers|adding provider|appended' \
      | sed 's/.*libxposed: //' | awk '!seen[$0]++' | tail -12
}

# dumpsys satirindan durum: gecerli | gecersiz: <neden> | listede yok
wvc_state() {
    _l=$(echo "$WVC_DS" | grep -E "package $1 \(|^ *$1 is NOT" | head -1)
    if [ -z "$_l" ]; then m "listede yok" "not in list"
    elif echo "$_l" | grep -q "^ *$1 is NOT installed"; then m "kurulu değil" "not installed"
    elif echo "$_l" | grep -q '^ *Valid package'; then
        if echo "$_l" | grep -q 'NOT installed'; then m "tüm kullanıcılarda kurulu değil" "not installed for all users"
        else m "geçerli" "valid"; fi
    elif echo "$_l" | grep -q 'reason: '; then m "geçersiz: ${_l##*reason: }" "invalid: ${_l##*reason: }"
    else echo "$_l" | sed 's/^ *//'; fi
}

# Durum raporu: stdout'a yazar. WVC_SUMMARY ve WVC_LOW (surum kodu dusuk paketler) doldurulur.
wvc_status() {
    _list=$1
    WVC_DS=$(dumpsys webviewupdate 2>/dev/null)
    WVC_SUMMARY=""
    WVC_LOW=""
    m "WVC durum: $(date '+%Y-%m-%d %H:%M')" "WVC status: $(date '+%Y-%m-%d %H:%M')"
    m "Kök yöneticisi: $(wvc_root)" "Root manager: $(wvc_root)"
    echo "Zygisk: $(wvc_zygisk)"
    echo "LSPosed: $(wvc_lsposed)"
    _awv=$(wvc_version "$WVC_ANYWEBVIEW")
    echo "AnyWebView: ${_awv:-$(m "kurulu değil" "not installed")}"
    echo "$WVC_DS" | grep -E 'Current WebView package|Minimum WebView version code' | sed 's/^ *//'
    m "-- Kanca günlüğü" "-- Hook log"
    _hl=$(wvc_hook_log)
    if [ -n "$_hl" ]; then echo "$_hl"; else m "(AnyWebView satırı yok)" "(no AnyWebView lines)"; fi
    m "-- Listedeki sağlayıcılar" "-- Providers in the list"
    echo "$WVC_DS" | grep -E 'Valid package|Invalid package' \
        | sed -e 's/^ *//' -e 's/ (versionName: \([^,]*\),.*reason: /, \1: /' \
              -e 's/ (versionName: \([^,]*\),.*/ \1/'
    m "-- WVC paketleri" "-- WVC packages"
    if [ -f "$_list" ]; then
        while read -r _p _m; do
            [ -n "$_p" ] || continue
            _s=$(wvc_state "$_p")
            echo "$(wvc_name "$_p") ($_p, $_m, $(wvc_version "$_p")): $_s"
            case "$_s" in
                *"Version code too low"*) WVC_LOW="$WVC_LOW $_p"
                    _short=$(m "sürüm kodu düşük, Eylem ile sisteme taşıyın" "version code too low, move to system with Action") ;;
                *) _short=$_s ;;
            esac
            WVC_SUMMARY="${WVC_SUMMARY}$(wvc_name "$_p"): $_short | "
        done < "$_list"
    fi
    # Kancayla ilgili ipuclari
    if [ -z "$_awv" ]; then
        WVC_SUMMARY="${WVC_SUMMARY}$(m "AnyWebView kurulu değil" "AnyWebView not installed") | "
    elif ! echo "$_hl" | grep -q 'entry point loaded'; then
        if ! wvc_zygisk >/dev/null; then
            WVC_SUMMARY="${WVC_SUMMARY}$(m "Zygisk kapalı" "Zygisk disabled") | "
        else
            WVC_SUMMARY="${WVC_SUMMARY}$(m "AnyWebView kancası yüklenmedi (LSPosed kapsamı: Sistem Çerçevesi)" "AnyWebView hook not loaded (LSPosed scope: System Framework)") | "
        fi
    elif echo "$_hl" | grep -q 'failed to hook'; then
        WVC_SUMMARY="${WVC_SUMMARY}$(m "AnyWebView kancası tutunmadı (AnyWebView'ı güncelleyin)" "AnyWebView hook failed (update AnyWebView)") | "
    fi
}
