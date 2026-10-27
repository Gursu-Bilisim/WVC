# WVC guncelleme denetimi (v9.2). service.sh ve action.sh, wvc-lib.sh'den sonra okur.
# Yalniz cihazda kurulu paketler denetlenir: Vanadium (WVC catali), AOSmium,
# Cromite (com.android.webview, Cromite imzasiyla) ve AnyWebView.
# Indirme wvc-fetch.dex ile (app_process, Android'in HttpsURLConnection'i): sunucu
# sertifikasi sistem CA deposuna gore dogrulanir, yalniz https kabul edilir.
# busybox wget sertifika dogrulamadigi icin kullanilmiyor ("TLS certificate
# validation not implemented", tucana ve jackpotlte, 2026-10-26). Indirilen APK
# ayrica GitHub'in verdigi SHA-256 ya da AOSmium'un .sha512 dosyasiyla denetlenir;
# Android da guncellemede imza eslesmesi ister.

WVC_FETCH_DEX=${MODDIR:-$WVC_LIVE}/wvc-fetch.dex
# Cromite imza sertifikasi: SHA-256 633fa41d8211d6d0916a819b89668c6de92e64232da67f9d16fd81c3b7e923ff,
# dumpsys package "signatures:[b841f909]" (Signature.hashCode). arm64_SystemWebView.apk
# v153.0.8010.37 ile hesaplandi; jackpotlte'deki Cromite ayni degeri gosteriyor (2026-10-27).
WVC_CROMITE_SIG=b841f909
WVC_DL=/data/local/tmp/wvc-dl

# wvc_fetch <https-adres> <dosya|-> [accept]; cikis 0 tamam, 3 HTTP hatasi
wvc_fetch() {
    CLASSPATH=$WVC_FETCH_DEX app_process /system/bin org.wvc.Fetch "$@"
}

wvc_bb() {
    for _b in /data/adb/magisk/busybox /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox; do
        [ -x "$_b" ] && { echo "$_b"; return 0; }
    done
    command -v busybox
}

# Paket -> "api-adresi etiket-deseni dosya-deseni"; desenler awk duzenli ifadesi
wvc_src() {
    case "$1" in
        org.wvc.vanadium_wv)
            echo "https://api.github.com/repos/Gursu-Bilisim/WVC/releases?per_page=20 ^vanadium- ^VanadiumWebView-WVC-.*-64_32[.]apk\$" ;;
        org.axpos.aosmium_wv)
            if [ -n "$(getprop ro.product.cpu.abilist64)" ]; then _f=webview64-signed; else _f=webview32-signed; fi
            echo "https://codeberg.org/api/v1/repos/AXP-OS/app_aosmium/releases?limit=5 . ^$_f[.]apk\$" ;;
        com.android.webview)
            case "$(getprop ro.product.cpu.abi)" in
                arm64-v8a) _f=arm64 ;; armeabi-v7a) _f=arm ;; x86_64) _f=x64 ;; *) return 1 ;;
            esac
            echo "https://api.github.com/repos/uazo/cromite/releases/latest . ^${_f}_SystemWebView[.]apk\$" ;;
        "$WVC_ANYWEBVIEW")
            echo "https://api.github.com/repos/neoblackxt/AnyWebView/releases/latest . ^AnyWebView-.*[.]apk\$" ;;
        *) return 1 ;;
    esac
}

wvc_uname() { if [ "$1" = "$WVC_ANYWEBVIEW" ]; then echo AnyWebView; else wvc_name "$1"; fi; }

# Denetlenecek, cihazda kurulu paketler
wvc_update_pkgs() {
    for _p in org.wvc.vanadium_wv org.axpos.aosmium_wv com.android.webview "$WVC_ANYWEBVIEW"; do
        _d=$(dumpsys package "$_p" 2>/dev/null)
        echo "$_d" | grep -q 'versionName=' || continue
        if [ "$_p" = com.android.webview ]; then
            echo "$_d" | grep -q "signatures:\[$WVC_CROMITE_SIG\]" || continue
        fi
        echo "$_p"
    done
}

# Surum API yaniti (stdin) -> "etiket|dosya|bayt|ozet|adres" satirlari.
# JSON virgulle bolunur; GitHub ve Gitea'da her dosya nesnesi "name" ile
# baslar, sonraki "name" ya da "tag_name" onceki dosyayi kapatir.
wvc_assets() {
    tr ',' '\n' | awk '
        function val(s, k,  i) { i = index(s, "\"" k "\":"); s = substr(s, i + length(k) + 3)
            sub(/^ +/, "", s); sub(/[]}]+$/, "", s); gsub(/^"|"$/, "", s); return s }
        function flush() { if (url != "") print tag "|" nm "|" sz "|" dg "|" url
            url = ""; sz = ""; dg = "" }
        /"tag_name":/ { flush(); tag = val($0, "tag_name"); next }
        /"name":/ { flush(); nm = val($0, "name"); next }
        /"size":/ { sz = val($0, "size"); next }
        /"digest":/ { dg = val($0, "digest"); next }
        /"browser_download_url":/ { url = val($0, "browser_download_url"); next }
        END { flush() }'
}

# "a b": b, a'dan yeni ise 0
wvc_newer() {
    awk -v a="$1" -v b="$2" 'BEGIN { n = split(a, x, "."); k = split(b, y, "."); if (k > n) n = k
        for (i = 1; i <= n; i++) { if (y[i] + 0 > x[i] + 0) exit 0; if (y[i] + 0 < x[i] + 0) exit 1 }
        exit 1 }'
}

# Etiketten surum: vanadium-156.0.8078.47.0, v153.0.8010.37-<hash>, v1.4.5
wvc_tag_ver() { echo "$1" | sed -e 's/^vanadium-//' -e 's/^v//' -e 's/-.*//'; }

# Denetim: $1 modul klasoru. updates.txt'yi yazar: "paket surum adres bayt ozet dosya".
# Rapor stdout'a. En az bir kaynak yanit verdiyse 0.
wvc_update_check() {
    _md=$1
    _tmp=$_md/updates.tmp
    : > "$_tmp"
    _ok=0
    _pkgs=$(wvc_update_pkgs)
    if [ -z "$_pkgs" ]; then
        m "Güncelleme denetimi: denetlenecek paket yok." "Update check: no package to check."
        mv -f "$_tmp" "$_md/updates.txt"
        return 0
    fi
    for _p in $_pkgs; do
        _src=$(wvc_src "$_p") || continue
        set -- $_src
        _api=$1 _tre=$2 _fre=$3
        _n=$(wvc_uname "$_p")
        _cur=$(wvc_version "$_p")
        _err=$_md/fetch.err
        _js=$(wvc_fetch "$_api" - application/json 2>"$_err")
        if [ -z "$_js" ]; then
            m "$_n: kaynağa ulaşılamadı ($(head -1 "$_err"))" "$_n: source unreachable ($(head -1 "$_err"))"
            rm -f "$_err"; continue
        fi
        rm -f "$_err"
        _ok=1
        _rec=$(echo "$_js" | wvc_assets | awk -F'|' -v t="$_tre" -v f="$_fre" '$1 ~ t && $2 ~ f { print; exit }')
        if [ -z "$_rec" ]; then
            m "$_n: uygun dosya bulunamadı" "$_n: no matching file"; continue
        fi
        _tag=$(echo "$_rec" | cut -d'|' -f1)
        _new=$(wvc_tag_ver "$_tag")
        if wvc_newer "$_cur" "$_new"; then
            m "$_n: $_cur -> $_new" "$_n: $_cur -> $_new"
            echo "$_rec" | awk -F'|' -v p="$_p" -v v="$_new" '{
                d = $4; sub(/^sha256:/, "", d); if (d == "" || d == "null") d = "-"
                print p, v, $5, ($3 == "" ? 0 : $3), d, $2 }' >> "$_tmp"
        else
            m "$_n: $_cur güncel (son: $_new)" "$_n: $_cur is up to date (latest: $_new)"
        fi
    done
    [ "$_ok" = 1 ] || { rm -f "$_tmp"; return 1; }
    mv -f "$_tmp" "$_md/updates.txt"
    date +%s > "$_md/update-last"
    return 0
}

# Modul aciklamasi: summary.txt + guncellemeler
wvc_desc() {
    _md=$1
    _sum=$(cat "$_md/summary.txt" 2>/dev/null)
    [ -n "$_sum" ] || _sum=$(m "WVC paketi kayıtlı değil" "No WVC package recorded")
    _up=""
    if [ -s "$_md/updates.txt" ]; then
        _l=$(while read -r _p _v _r; do printf '%s %s, ' "$(wvc_uname "$_p")" "$_v"; done < "$_md/updates.txt" | sed 's/, $//')
        _up=" $(m "Güncelleme var: $_l (Eylem ile kurulur)." "Updates available: $_l (install with Action).")"
    fi
    _tail=$(m "Ayrıntı: Eylem düğmesi ya da status.txt. Lordify WebView Changer'dan esinlenildi." "Details: Action button or status.txt. Inspired by Lordify's WebView Changer.")
    _t=$_md/module.prop.tmp
    grep -v '^description=' "$_md/module.prop" > "$_t"
    echo "description=$_sum.$_up $_tail" >> "$_t"
    cat "$_t" > "$_md/module.prop"
    rm -f "$_t"
}

# Bildirim: Kabuk (uid 2000) adina. Kok olarak gonderilen bildirim sessizce
# dusuyor, uid 1000 reddediliyor, dokunma eylemi uid 2000'de izin hatasi veriyor
# (tucana APatch, jackpotlte Magisk, 2026-10-27). Yalniz bilgi verir.
wvc_notify() {
    _t=$(echo "$1" | tr -d "'")
    _x=$(echo "$2" | tr -d "'")
    _c="cmd notification post -S bigtext -t '$_t' wvc_update '$_x'"
    for _s in su /data/adb/ap/bin/su /data/adb/ksu/bin/su; do
        command -v "$_s" >/dev/null 2>&1 || continue
        "$_s" 2000 -c "$_c" >/dev/null 2>&1 && return 0
    done
    command -v magisk >/dev/null 2>&1 && magisk su 2000 -c "$_c" >/dev/null 2>&1
}

# Yeni bir guncelleme kumesi icin bir kez bildirir
wvc_update_notify() {
    _md=$1
    [ -s "$_md/updates.txt" ] || { rm -f "$_md/update-notified"; return 0; }
    _key=$(cut -d' ' -f1,2 "$_md/updates.txt")
    [ "$_key" = "$(cat "$_md/update-notified" 2>/dev/null)" ] && return 0
    _l=$(while read -r _p _v _r; do printf '%s %s, ' "$(wvc_uname "$_p")" "$_v"; done < "$_md/updates.txt" | sed 's/, $//')
    wvc_notify "$(m "WVC: güncelleme var" "WVC: updates available")" \
        "$(m "$_l. Kurmak için kök yöneticisinde WVC modülünün Eylem düğmesine basın." \
             "$_l. To install, tap the Action button of the WVC module in the root manager.")" \
        && echo "$_key" > "$_md/update-notified"
}

# service.sh dongusu: saatte bir bakar, son basarili denetimden 24 saat gectiyse denetler.
# sleep askida gecen sureyi saymadigi icin duvar saatiyle karsilastirilir.
wvc_update_loop() {
    _md=$1
    while :; do
        if [ ! -f "$_md/disable_update_check" ]; then
            _now=$(date +%s)
            _last=$(cat "$_md/update-last" 2>/dev/null)
            case "$_last" in ''|*[!0-9]*) _last=0 ;; esac
            if [ $((_now - _last)) -ge 86400 ] || [ "$_now" -lt "$_last" ]; then
                if wvc_update_check "$_md" > "$_md/update.log" 2>&1; then
                    wvc_desc "$_md"
                    wvc_update_notify "$_md"
                fi
            fi
        fi
        sleep 3600
    done
}

# Eylem: updates.txt'deki paketleri indirip kurar
wvc_update_install() {
    _md=$1
    _bb=$(wvc_bb) || return 1
    [ -s "$_md/updates.txt" ] || return 0
    mkdir -p "$WVC_DL"
    _awv=0
    _left=$_md/updates.left
    : > "$_left"
    while read -r _p _v _url _size _dg _file; do
        [ -n "$_p" ] || continue
        _n=$(wvc_uname "$_p")
        _f=$WVC_DL/$_file
        _kb=$("$_bb" df -k /data 2>/dev/null | awk 'NR==2 { print $4 }')
        case "$_kb" in ''|*[!0-9]*) _kb=0 ;; esac
        if [ "$_size" -gt 0 ] && [ "$_kb" -gt 0 ] && [ $((_kb * 1024)) -lt $((_size * 2)) ]; then
            m "! $_n: /data'da yer yetersiz." "! $_n: not enough space on /data."
            echo "$_p $_v $_url $_size $_dg $_file" >> "$_left"; continue
        fi
        m "$_n $_v indiriliyor ($((_size / 1048576)) MB)..." "Downloading $_n $_v ($((_size / 1048576)) MB)..."
        rm -f "$_f"
        if ! _e=$(wvc_fetch "$_url" "$_f" 2>&1); then
            m "! $_n indirilemedi: $_e" "! Could not download $_n: $_e"
            echo "$_p $_v $_url $_size $_dg $_file" >> "$_left"; rm -f "$_f"; continue
        fi
        _bad=""
        if [ "$_size" -gt 0 ] && [ "$(stat -c %s "$_f")" != "$_size" ]; then
            _bad=$(m "boyut tutmuyor" "size mismatch")
        elif [ "$_dg" != "-" ]; then
            [ "$("$_bb" sha256sum "$_f" | cut -d' ' -f1)" = "$_dg" ] || _bad="SHA-256"
        elif [ "$_p" = org.axpos.aosmium_wv ]; then
            _want=$(wvc_fetch "$_url.sha512" - 2>/dev/null | awk '{ print $1; exit }')
            if [ -z "$_want" ]; then _bad=$(m ".sha512 alınamadı" "could not fetch .sha512")
            elif [ "$("$_bb" sha512sum "$_f" | cut -d' ' -f1)" != "$_want" ]; then _bad="SHA-512"; fi
        fi
        if [ -z "$_bad" ]; then
            if [ "$_p" = "$WVC_ANYWEBVIEW" ]; then
                unzip -p "$_f" AndroidManifest.xml 2>/dev/null | tr -d '\000' | grep -aqF "$_p" \
                    || _bad=$(m "paket adı tutmuyor" "package name mismatch")
            else
                [ "$(wvc_apk_pkg "$_f")" = "$_p" ] || _bad=$(m "paket adı tutmuyor" "package name mismatch")
                [ -z "$_bad" ] && _miss=$(wvc_abi_missing "$_f") && [ -n "$_miss" ] \
                    && _bad=$(m "eksik ABI:$_miss" "missing ABI:$_miss")
            fi
        fi
        if [ -n "$_bad" ]; then
            m "! $_n: denetim başarısız ($_bad), kurulmadı." "! $_n: check failed ($_bad), not installed."
            echo "$_p $_v $_url $_size $_dg $_file" >> "$_left"; rm -f "$_f"; continue
        fi
        _out=$(wvc_pm_install "$_f")
        rm -f "$_f"
        if echo "$_out" | grep -q '^Success'; then
            wvc_all_users "$_p"
            m "$_n $_v kuruldu." "$_n $_v installed."
            [ "$_p" = "$WVC_ANYWEBVIEW" ] && _awv=1
        else
            m "! $_n kurulamadı: $_out" "! $_n install failed: $_out"
            echo "$_p $_v $_url $_size $_dg $_file" >> "$_left"
        fi
    done < "$_md/updates.txt"
    mv -f "$_left" "$_md/updates.txt"
    [ -s "$_md/updates.txt" ] || rm -f "$_md/update-notified"
    rmdir "$WVC_DL" 2>/dev/null
    if [ "$_awv" = 1 ]; then
        m "AnyWebView güncellendi; LSPosed modülü olduğu için yeniden başlatın." \
          "AnyWebView was updated; reboot, as it is an LSPosed module."
    fi
}
