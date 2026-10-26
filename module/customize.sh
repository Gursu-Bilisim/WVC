# WVC kurulumu: /sdcard/WVC ve SD kartta WVC klasorundeki WebView APK'larini
# stok WebView'in yanina kurar. Hangi APK klasordeyse o kurulur.
# Mesajlar sistem dili Turkce ise Turkce, degilse Ingilizce (wvc-lib.sh: m).

. "$MODPATH/wvc-lib.sh"

ui_print " "
ui_print "WebView Changer (WVC) v9.1"
ui_print "kgursu (Gursu-Bilisim @ GitHub)"
ui_print "$(m "Lordify WebView Changer'dan esinlenildi" "Inspired by Lordify's WebView Changer")"
ui_print " "
ui_print "$(m "Güncellemeler GitHub'dan:" "Updates on GitHub:") https://github.com/Gursu-Bilisim/WVC/releases"
ui_print "$(m "(Kök yöneticisi yeni sürümü modül listesinde de bildirir.)" "(Your root manager also shows new versions in the module list.)")"
ui_print " "

[ "$BOOTMODE" = true ] || abort "$(m "! Kök yöneticisinin uygulamasından kurun (recovery desteklenmiyor)." "! Install from the root manager app (recovery is not supported).")"
[ "$API" -ge 29 ] || abort "$(m "! Android 10 (API 29) ve üstü gerekli. Bu cihaz: API $API" "! Android 10 (API 29) or newer required. This device: API $API")"
case "$ARCH" in
    arm|arm64) ;;
    *) abort "$(m "! Desteklenmeyen mimari: $ARCH" "! Unsupported architecture: $ARCH")" ;;
esac

LIST=$MODPATH/wvc.list
: > "$LIST"

# Baska kimlikle kurulu bir WebView Changer (Lordify ya da turevi) stok WebView'i
# gizleyip listeyi kendi overlay'iyle degistirir; WVC ile birlikte calismaz.
for d in /data/adb/modules/*; do
    [ -f "$d/module.prop" ] || continue
    [ "${d##*/}" = "$WVC_ID" ] && continue
    [ -f "$d/remove" ] && continue
    if grep -qiE '^(name|author)=.*(WebView Changer|Lordify)' "$d/module.prop"; then
        abort "$(m "! Başka bir WebView Changer modülü kurulu: ${d##*/}. Önce onu kaldırıp yeniden başlatın." "! Another WebView Changer module is installed: ${d##*/}. Remove it and reboot first.")"
    fi
done

# Ayni kimlikle (WVC) kurulu eski Lordify tabanli surum: wvc.list yok, debloat.sh ya da
# config.sh var. Bu kurulum onun yerini alir.
if [ -d "$WVC_LIVE" ] && [ ! -f "$WVC_LIVE/wvc.list" ] \
    && { [ -f "$WVC_LIVE/debloat.sh" ] || [ -f "$WVC_LIVE/config.sh" ]; }; then
    ui_print "$(m "- Eski WebView Changer (Lordify tabanlı) bulundu; yerini bu sürüm alıyor." "- Old WebView Changer (Lordify based) found; this version replaces it.")"
    ui_print "$(m "  Yeniden başlatmadan sonra stok WebView geri gelir; eski sürümün modül" "  After reboot the stock WebView comes back; the WebView (Cromite/AOSmium)")"
    ui_print "$(m "  içine koyduğu WebView (Cromite/AOSmium) ve overlay'i kalkar." "  and overlay that the old version kept inside the module are removed.")"
    for p in app.vanadium.webview app.vanadium.trichromelibrary; do
        if [ -n "$(pm path "$p" 2>/dev/null)" ]; then
            ui_print "$(m "  Eski sürümün kurduğu $p /data'da duruyor; WVC ona dokunmaz." "  $p installed by the old version stays in /data; WVC leaves it alone.")"
            ui_print "$(m "  İstemiyorsanız: pm uninstall $p" "  To remove it: pm uninstall $p")"
        fi
    done
    ui_print " "
fi

# Onceki surumun kurulumlarini koru: /data kurulumlari hala kuruluysa listede kalir,
# sistem kurulumlari yeni module kopyalanir.
if [ -f "$WVC_LIVE/wvc.list" ]; then
    while read -r p mode; do
        if [ "$mode" = data ]; then
            if [ -n "$(pm path "$p" 2>/dev/null)" ]; then
                echo "$p data" >> "$LIST"
                ui_print "$(m "- Önceki kurulum korundu: $(wvc_name "$p")" "- Previous install kept: $(wvc_name "$p")")"
            fi
            continue
        fi
        [ "$mode" = system ] || continue
        d=$(wvc_dir "$p")
        [ -n "$d" ] && [ -f "$WVC_LIVE/system/product/app/$d/$d.apk" ] || continue
        mkdir -p "$MODPATH/system/product/app/$d"
        cp -a "$WVC_LIVE/system/product/app/$d/$d.apk" "$MODPATH/system/product/app/$d/"
        echo "$p system" >> "$LIST"
        ui_print "$(m "- Sistem kurulumu korundu: $(wvc_name "$p")" "- System install kept: $(wvc_name "$p")")"
    done < "$WVC_LIVE/wvc.list"
fi

TRIED=$MODPATH/.tried
: > "$TRIED"

# APK'lari bul (/sdcard ve /storage/emulated/0 ayni yer; SD kart /storage/XXXX-XXXX)
APKS=""
for f in /sdcard/WVC/*.apk /storage/*/WVC/*.apk; do
    [ -f "$f" ] || continue
    case "$f" in /storage/emulated/*|/storage/self/*) continue ;; esac
    APKS="$APKS
$f"
done
[ -n "$APKS" ] || abort "$(m "! APK bulunamadı. APK'ları /sdcard/WVC ya da SD kartta WVC klasörüne koyun." "! No APK found. Put the APKs in /sdcard/WVC or in a WVC folder on the SD card.")"

SKIP=$(m "Atlandı." "Skipped.")
echo "$APKS" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    ui_print " "
    ui_print "* ${f##*/}"
    p=$(wvc_apk_pkg "$f")
    case "$p" in
        org.axpos.aosmium_wv|org.wvc.vanadium_wv|com.android.webview) ;;
        app.vanadium.webview)
            ui_print "$(m "  GrapheneOS imzalı Vanadium desteklenmiyor; WVC Vanadium çatalını kullanın." "  GrapheneOS-signed Vanadium is not supported; use the WVC Vanadium fork.") $SKIP"
            continue ;;
        com.google.android.webview)
            ui_print "$(m "  Google WebView WVC ile kurulmaz (Play Store'dan güncellenir)." "  Google WebView is not installed by WVC (it updates from the Play Store).") $SKIP"
            continue ;;
        *)
            ui_print "$(m "  WebView APK'sı olarak tanınmadı." "  Not recognized as a WebView APK.") $SKIP"
            continue ;;
    esac
    ui_print "  $(wvc_name "$p") ($p)"
    if grep -q "^$p data" "$TRIED" 2>/dev/null; then
        ui_print "$(m "  Bu paket bu kurulumda zaten kuruldu." "  This package was already installed in this run.") $SKIP"
        continue
    fi
    if [ "$p" = org.wvc.vanadium_wv ] && [ "$API" -lt 34 ]; then
        ui_print "$(m "  Vanadium Android 14 (API 34) ve üstü ister." "  Vanadium needs Android 14 (API 34) or newer.") $SKIP"
        continue
    fi
    miss=$(wvc_abi_missing "$f")
    if [ -n "$miss" ]; then
        ui_print "$(m "  APK cihazın şu ABI'leri için kütüphane taşımıyor:$miss." "  The APK has no library for these device ABIs:$miss.") $SKIP"
        ui_print "$(m "  (64 ve 32 bit kütüphaneyi birlikte taşıyan APK gerekir.)" "  (An APK carrying both 64-bit and 32-bit libraries is needed.)")"
        continue
    fi
    if [ "$p" = com.android.webview ]; then
        sp=$(pm path com.android.webview 2>/dev/null | sed -n 's/^package://p' | head -1)
        case "$sp" in
            /system/*|/product/*|/system_ext/*|/vendor/*)
                ui_print "$(m "  Not: Cromite stok AOSP WebView'ın ($sp) güncellemesi olarak kurulur;" "  Note: Cromite installs as an update of the stock AOSP WebView ($sp);")"
                ui_print "$(m "  stok WebView listeden çıkar, geri dönmek için Cromite kaldırılır." "  the stock WebView leaves the list; uninstall Cromite to go back.")" ;;
        esac
    fi
    ui_print "$(m "  Kuruluyor..." "  Installing...")"
    out=$(wvc_pm_install "$f")
    if echo "$out" | grep -q '^Success'; then
        wvc_all_users "$p"
        echo "$p data" >> "$TRIED"
        grep -qE "^$p (data|system)" "$LIST" || echo "$p data" >> "$LIST"
        ui_print "$(m "  Kuruldu:" "  Installed:") $(wvc_version "$p")"
    else
        ui_print "$(m "  ! Kurulamadı:" "  ! Install failed:") $(echo "$out" | tail -1)"
    fi
done

rm -f "$TRIED"
ui_print " "
if [ ! -s "$LIST" ]; then
    abort "$(m "! Hiçbir WebView kurulmadı." "! No WebView was installed.")"
fi

ui_print "$(m "Kontrol:" "Checks:")"
ui_print "  $(m "Kök yöneticisi" "Root manager"): $(wvc_root)"
if z=$(wvc_zygisk); then zok=1; else zok=0; fi
ui_print "  Zygisk: $z"
if l=$(wvc_lsposed); then lok=1; else lok=0; fi
ui_print "  LSPosed: $l"
a=$(wvc_version "$WVC_ANYWEBVIEW")
ui_print "  AnyWebView: ${a:-$(m "kurulu değil" "not installed")}"
[ "$zok" = 1 ] || ui_print "$(m "  ! Zygisk sağlayıcısı etkin değil; AnyWebView çalışmaz." "  ! No active Zygisk provider; AnyWebView will not work.")"
[ "$lok" = 1 ] || ui_print "$(m "  ! LSPosed yok; AnyWebView çalışmaz." "  ! LSPosed not found; AnyWebView will not work.")"
[ -n "$a" ] || ui_print "$(m "  ! AnyWebView kurulu değil; ROM listesinde olmayan WebView'lar görünmez." "  ! AnyWebView is not installed; WebViews missing from the ROM list will not show up.")"
ui_print "$(m "  AnyWebView kapsamı LSPosed'da yalnız 'Sistem Çerçevesi' olmalı." "  In LSPosed, AnyWebView's scope must be 'System Framework' only.")"
ui_print " "
ui_print "$(m "Yeniden başlatın. AnyWebView kurulu WebView'ları açılışta tarar;" "Reboot. AnyWebView scans installed WebViews at boot;")"
ui_print "$(m "yeni kurulanlar ancak sonraki açılışta listeye girer." "newly installed ones join the list after the next boot.")"
ui_print "$(m "Durum açılıştan sonra modül açıklamasında ve $WVC_LIVE/status.txt dosyasında." "After boot the status is in the module description and in $WVC_LIVE/status.txt.")"

set_perm_recursive "$MODPATH" 0 0 0755 0644
if [ -d "$MODPATH/system" ]; then
    set_perm_recursive "$MODPATH/system" 0 0 0755 0644 u:object_r:system_file:s0
fi
