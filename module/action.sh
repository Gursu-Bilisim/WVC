#!/system/bin/sh
# Eylem: durumu gosterir; surum kodu dusuk (Version code too low) WVC paketlerini
# sistem uygulamasi olarak module tasir (yeniden baslatma gerekir).
MODDIR=${0%/*}
. "$MODDIR/wvc-lib.sh"
LIST=$MODDIR/wvc.list

wvc_status "$LIST"
echo " "

if [ -z "$WVC_LOW" ]; then
    m "Sistem kurulumu gereken paket yok." "No package needs a system install."
    exit 0
fi

case "$(wvc_root)" in
    KernelSU|APatch)
        if ! mm=$(wvc_metamodule); then
            m "! Metamodül (örnek: Hybrid Mount) etkin değil; sistem kurulumu bağlanmaz." \
              "! No active metamodule (e.g. Hybrid Mount); a system install would not be mounted."
            m "  Önce metamodülü kurun, sonra Eylem'i tekrar çalıştırın." \
              "  Install a metamodule first, then run Action again."
            exit 1
        fi
        echo "$(m "Metamodül" "Metamodule"): $mm" ;;
esac

moved=0
for p in $WVC_LOW; do
    n=$(wvc_name "$p")
    d=$(wvc_dir "$p")
    [ -n "$d" ] || continue
    if [ "$p" = com.android.webview ] && dumpsys package com.android.webview \
        | grep -qE 'codePath=/(system|product|system_ext|vendor)/'; then
        m "$n stok AOSP WebView'ın güncellemesi olarak kurulu; sisteme taşınamaz, atlandı." \
          "$n is installed as an update of the stock AOSP WebView; cannot move to system, skipped."
        continue
    fi
    src=$(pm path "$p" 2>/dev/null | sed -n 's/^package://p' | grep 'base.apk$' | head -1)
    case "$src" in
        /data/app/*) ;;
        *) m "$n: /data kopyası yok ($src), atlandı." "$n: no /data copy ($src), skipped."; continue ;;
    esac
    dst=$MODDIR/system/product/app/$d
    mkdir -p "$dst"
    if ! cp "$src" "$dst/$d.apk"; then
        m "! $n kopyalanamadı." "! Could not copy $n."; rm -rf "$dst"; continue
    fi
    if [ "$(stat -c %s "$src")" != "$(stat -c %s "$dst/$d.apk")" ]; then
        m "! $n kopyası eksik." "! Copy of $n is incomplete."; rm -rf "$dst"; continue
    fi
    chown -R 0:0 "$MODDIR/system"
    chmod 0755 "$MODDIR/system" "$MODDIR/system/product" "$MODDIR/system/product/app" "$dst"
    chmod 0644 "$dst/$d.apk"
    chcon -R u:object_r:system_file:s0 "$MODDIR/system"
    pm uninstall "$p" >/dev/null 2>&1
    sed -i "s|^$p data\$|$p system|" "$LIST"
    grep -q "^$p system" "$LIST" || echo "$p system" >> "$LIST"
    m "$n sisteme taşındı: /product/app/$d" "$n moved to system: /product/app/$d"
    moved=1
done

if [ "$moved" = 1 ]; then
    echo " "
    m "Yeniden başlatın. Açılışta sistem kopyası fabrika sürümü sayılır ve" \
      "Reboot. At boot the system copy counts as the factory version and"
    m "asgari sürüm kodunu düşürür. Modül kaldırılırsa bu WebView'lar cihazdan gider." \
      "lowers the minimum version code. Removing the module removes these WebViews."
fi
