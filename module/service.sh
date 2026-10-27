#!/system/bin/sh
# Acilistan sonra WVC durumunu status.txt'ye ve modul aciklamasina yazar,
# sonra gunde bir guncelleme denetler (wvc-update.sh).
MODDIR=${0%/*}
. "$MODDIR/wvc-lib.sh"
. "$MODDIR/wvc-update.sh"

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done
# LSPosed gunlugu ve WebView servisi otursun
sleep 30

rm -f "$MODDIR/durum.txt"
exec 3>&1
exec > "$MODDIR/status.txt" 2>&1
wvc_status "$MODDIR/wvc.list"
exec >&3 2>&1

echo "$WVC_SUMMARY" | sed 's/ | $//' > "$MODDIR/summary.txt"
wvc_desc "$MODDIR"

wvc_update_loop "$MODDIR"
