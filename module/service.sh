#!/system/bin/sh
# Acilistan sonra WVC durumunu status.txt'ye ve modul aciklamasina yazar.
MODDIR=${0%/*}
. "$MODDIR/wvc-lib.sh"

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done
# LSPosed gunlugu ve WebView servisi otursun
sleep 30

rm -f "$MODDIR/durum.txt"
exec 3>&1
exec > "$MODDIR/status.txt" 2>&1
wvc_status "$MODDIR/wvc.list"
exec >&3 2>&1

sum=$(echo "$WVC_SUMMARY" | sed 's/ | $//')
[ -n "$sum" ] || sum=$(m "WVC paketi kayıtlı değil" "No WVC package recorded")
tail=$(m "Ayrıntı: Eylem düğmesi ya da status.txt. Lordify WebView Changer'dan esinlenildi." "Details: Action button or status.txt. Inspired by Lordify's WebView Changer.")
tmp=$MODDIR/module.prop.tmp
grep -v '^description=' "$MODDIR/module.prop" > "$tmp"
echo "description=$sum. $tail" >> "$tmp"
cat "$tmp" > "$MODDIR/module.prop"
rm -f "$tmp"
