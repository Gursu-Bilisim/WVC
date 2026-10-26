#!/system/bin/sh
# ANR/watchdog izleri: son dosyalar, kilit sahipleri, WebView ile ilgili satirlar.
# Kullanim: su -c 'sh /data/local/tmp/anr-tani.sh [dakika]'   (varsayilan: son 60 dakika)
MIN=${1:-60}
OUT=/data/local/tmp/anr-tani-$(getprop ro.product.device)-$(date +%Y%m%d-%H%M).txt
TMP=/data/local/tmp/anr-tani.$$
exec 3>&1
exec > "$OUT" 2>&1
sec() { echo; echo "=== $1 ==="; }

sec "uptime"
uptime

sec "dumpsys webviewupdate (ozet)"
dumpsys webviewupdate | grep -E 'Current WebView|Minimum WebView|package'

sec "son $MIN dakikadaki ANR/watchdog dosyalari"
FILES=$(find /data/anr /data/system/dropbox -type f -mmin -"$MIN" 2>/dev/null | grep -iE 'anr|trace|watchdog|crash')
for f in $FILES; do ls -l "$f"; done

for f in $FILES; do
  case "$f" in
    *.gz) gzip -dc "$f" > "$TMP" 2>/dev/null ;;
    *.dat|*.pb) continue ;;
    *) cat "$f" > "$TMP" 2>/dev/null ;;
  esac
  sec "$f"
  grep -m5 -E '^Process:|^Subject:|Cmd line:|----- pid' "$TMP"
  echo "-- WebView/kanca satirlari"
  grep -nE -i 'webview|vanadium|aosmium|relro|anywebview|xposed|lspd|HookBridge' "$TMP" | head -40
  echo "-- main is parcacigi"
  awk 'BEGIN{RS=""} /^"main" /{print; exit}' "$TMP" | head -40
  echo "-- kilit sahipleri"
  for t in $(grep -oE 'held by thread [0-9]+' "$TMP" | awk '{print $4}' | sort -u | head -6); do
    echo "- tid=$t"
    awk -v T=" tid=$t " 'BEGIN{RS=""} index($0,T){print; exit}' "$TMP" | head -45
  done
done
rm -f "$TMP"

sec "logcat: ANR ve WebView"
logcat -b all -d | grep -iE 'ANR in|not responding|WebViewUpdate|WebViewFactory|relro|vanadium|Watchdog' | tail -80

exec >&3 2>&1
echo "Yazildi: $OUT"
