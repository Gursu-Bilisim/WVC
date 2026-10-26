#!/system/bin/sh
# WVC tani betigi: WebView saglayici durumunu tek dosyaya yazar.
# Kullanim: terminalde once su, sonra: sh /sdcard/wvc-tani.sh
# Cikti: /sdcard/wvc-tani-<cihaz>-<tarih>.txt

[ "$(id -u)" = 0 ] || { echo "Root gerekli: once su calistirin."; exit 1; }

DEV=$(getprop ro.product.device)
NAME=wvc-tani-${DEV}-$(date +%Y%m%d-%H%M).txt
# Cikti once /data/local/tmp'ye yazilir: /sdcard (FUSE) uzerindeki bir dosyaya
# system_server yazamadigi icin pm ve cmd komutlari orada bos ya da hatali donuyor.
TMP=/data/local/tmp/$NAME
OUT=/sdcard/$NAME
exec 3>&1
exec > "$TMP" 2>&1

sec() { echo; echo "=== $1 ==="; }

sec "Cihaz ve ROM"
for p in ro.product.device ro.product.model ro.build.version.release \
         ro.build.version.sdk ro.build.version.security_patch ro.build.type \
         ro.debuggable ro.build.display.id ro.lineage.version \
         ro.lineage.build.version ro.modversion; do
  echo "$p=$(getprop "$p")"
done
uptime

sec "LSPosed props.txt (sahtelenmemis olabilecek degerler)"
grep -E '^\[?(ro.build.type|ro.debuggable|ro.lineage.version|ro.build.display.id)' /data/adb/lspd/log/props.txt 2>/dev/null

sec "Root yoneticisi"
for d in /data/adb/ap /data/adb/ksu /data/adb/magisk; do
  [ -d "$d" ] && echo "var: $d"
done

sec "Moduller (id | surum | durum)"
for m in /data/adb/modules/*/module.prop; do
  [ -f "$m" ] || continue
  dir=${m%/module.prop}
  st=etkin
  [ -f "$dir/disable" ] && st=devre_disi
  [ -f "$dir/remove" ] && st=kaldirilacak
  echo "$(grep -m1 '^id=' "$m" | cut -d= -f2) | $(grep -m1 '^version=' "$m" | cut -d= -f2) | $st"
done

sec "Kullanicilar"
pm list users

sec "WebView ile ilgili paketler"
pm list packages -f | grep -iE 'webview|aosmium|vanadium|cromite'

sec "Aday paket ayrintilari"
for pkg in com.android.webview com.google.android.webview org.axpos.aosmium_wv \
           app.vanadium.webview com.thinkdifferent.anywebview; do
  echo "--- $pkg"
  dumpsys package "$pkg" | grep -E 'codePath=|versionCode=|versionName=|pkgFlags=' | head -8
done

sec "dumpsys webviewupdate"
dumpsys webviewupdate

sec "framework-res config_webview_packages (dizgiler)"
unzip -p /system/framework/framework-res.apk res/xml/config_webview_packages.xml \
  | tr -d '\000' | strings

sec "android paketini hedefleyen etkin overlay'ler"
cmd overlay list android | grep '\[x\]'

sec "Etkin listeyi degistiren overlay'ler (config_webview_packages)"
# framework-res icindeki liste etkin liste olmayabilir: ROM'un derleme anli
# overlay'leri (auto_generated_rro_*) bu kaynagi ezebilir. Bulunan XML'ler
# rapor yanina ayri dosya olarak cikarilir.
for ov in $(cmd overlay list android | sed -n 's/^\[x\] //p'); do
  path=$(cmd overlay dump "$ov" | sed -n 's/.*mBaseCodePath[.]*: //p' | head -1)
  [ -f "$path" ] || continue
  unzip -l "$path" 2>/dev/null | grep -q 'res/xml/config_webview_packages.xml' || continue
  x=/sdcard/${NAME%.txt}-$ov.xml
  unzip -p "$path" res/xml/config_webview_packages.xml > "$x"
  echo "--- $ov ($path)"
  tr -d '\000' < "$x" | strings
  echo "Ek: $x"
done

sec "Kaynak cozumleme (hangi overlay kazaniyor)"
cmd overlay lookup --verbose android android:xml/config_webview_packages

sec "LSPosed"
ls -d /data/adb/lspd* /data/adb/*posed* 2>/dev/null
ls -la /data/adb/lspd/log/ 2>/dev/null
for f in /data/adb/lspd/log/*; do
  [ -f "$f" ] || continue
  hits=$(grep -iE 'anywebview|thinkdifferent' "$f" | tail -20)
  [ -n "$hits" ] && { echo "--- $f"; echo "$hits"; }
done

sec "logcat (anywebview, webviewupdate)"
logcat -b all -d | grep -iE 'anywebview|thinkdifferent|webviewupdate|WebViewFactory' | tail -60

exec >&3 2>&1
cp "$TMP" "$OUT" && rm -f "$TMP"
echo "Yazildi: $OUT"
