# WebView Changer (WVC)

[English](README.md)

Alternatif WebView sağlayıcılarını stok WebView'ın yanına kuran bir Magisk / KernelSU / APatch modülü. Stok WebView yerinde kalır; sağlayıcılar arasında **Geliştirici seçenekleri > WebView uygulaması** menüsünden istediğiniz zaman geçebilirsiniz.

WVC, Lordify'ın [WebView Changer](https://gitlab.com/Lordify/webview-changer) modülünden esinlenildi. Sürüm 9 baştan yazıldı: stok WebView'ı gizlemiyor, sağlayıcı listesini overlay ile değiştirmiyor.

## Desteklenen sağlayıcılar

| Sağlayıcı | Paket | İndirme | Not |
|---|---|---|---|
| AOSmium (AXP.OS) | `org.axpos.aosmium_wv` | [Codeberg sürümleri](https://codeberg.org/AXP-OS/app_aosmium/releases): 64 bit cihazlarda `webview64-signed.apk`, yalnız 32 bit cihazlarda `webview32-signed.apk` | Android 10 ve üstü |
| Vanadium, WVC çatalı | `org.wvc.vanadium_wv` | [WVC sürümleri](https://github.com/Gursu-Bilisim/WVC/releases), `vanadium-` ile başlayan etiketler | Android 14 ve üstü, arm64 cihazlar. Resmi olmayan derleme, bkz. [Vanadium çatalı](#vanadium-çatalı) |
| Cromite | `com.android.webview` | [Cromite sürümleri](https://github.com/uazo/cromite/releases): `arm64_SystemWebView.apk` | AOSP WebView'ın paket adını kullanır. AOSP WebView taşıyan ROM'larda onun güncellemesi olarak kurulur ve listede onun yerini alır |

WVC, Google WebView'ı (Play Store'dan güncellenir) ve GrapheneOS imzalı Vanadium'u kurmaz.

## Gereksinimler

- Root: Magisk, KernelSU ya da APatch (FolkPatch dahil).
- Bir Zygisk sağlayıcısı: Magisk'in yerleşik Zygisk'i, KernelSU ve APatch'te [Zygisk Next](https://github.com/LSPosed/ZygiskNext/releases).
- [LSPosed](https://lsposed.zip) ve [AnyWebView](https://github.com/neoblackxt/AnyWebView/releases) 1.4.5 ya da üstü. LSPosed'da AnyWebView'ın kapsamı yalnız **Sistem Çerçevesi** olmalı. AnyWebView kurulu WebView paketlerini sistemin sağlayıcı listesine ekler; o olmadan yalnız ROM'un zaten listelediği sağlayıcılar seçilebilir. 1.4.5, `getWebViewPackages()` metodunun satır içine alındığı derlemelerde de (Samsung One UI gibi) çalışır ([kayıt #37](https://github.com/neoblackxt/AnyWebView/issues/37)).
- Yalnız KernelSU ve APatch'te sistem kurulumu eylemi için: [Hybrid Mount](https://github.com/Hybrid-Mount/meta-hybrid_mount/releases) gibi bir metamodül.

## Kurulum

1. LSPosed'ı ve AnyWebView'ı kurun, AnyWebView'ı Sistem Çerçevesi kapsamıyla etkinleştirin, yeniden başlatın.
2. İstediğiniz WebView'ların APK'larını `/sdcard/WVC` klasörüne (ya da SD karttaki `WVC` klasörüne) koyun. WVC yalnız orada bulduğu APK'ları kurar.
3. WVC zip'ini kök yöneticisinin uygulamasından kurun. Recovery'den kurulum desteklenmiyor.
4. Yeniden başlatın. AnyWebView kurulu WebView'ları her açılışta bir kez taradığı için yeni kurulan sağlayıcılar bir sonraki açılışta listeye girer.
5. Geliştirici seçenekleri > WebView uygulaması menüsünden bir sağlayıcı seçin.

Kurulum sırasında WVC her APK'nın paket adını okur, WebView sağlayıcısı olmayan APK'ları ve cihazın ABI'lerinden biri için kütüphane taşımayan APK'ları atlar (WebView manifesti `multiArch` olduğu için Android bunları reddeder). Ardından Zygisk sağlayıcısını, LSPosed'ı ve AnyWebView'ı denetleyip eksikleri yazar.

Kurulum, Eylem ve durum mesajları sistem dili Türkçe ise Türkçe, değilse İngilizcedir.

## Durum ve Eylem düğmesi

WVC her açılıştan sonra durum raporunu `/data/adb/modules/WVC/status.txt` dosyasına, kısa özetini modül açıklamasına yazar. Kök yöneticisindeki Eylem düğmesi aynı raporu gösterir: kök yöneticisi, Zygisk, LSPosed ve AnyWebView sürümleri, AnyWebView kanca günlüğü, sistem listesindeki her sağlayıcı ve durumu, WVC paketleri.

Bir WVC paketi `Version code too low` gösteriyorsa sürümü ROM'un asgari WebView sürümünün altındadır. Android bu asgari değeri listedeki sağlayıcıların fabrika (sistem bölümündeki) sürümlerinden alır. Bu durumda Eylem düğmesi paketi modülün içine sistem uygulaması olarak (`/product/app`) kopyalar ve `/data` kopyasını kaldırır. Yeniden başlatmadan sonra sistem kopyası fabrika sürümü sayılır ve asgari değeri düşürür. KernelSU ve APatch'te bunun için etkin bir metamodül gerekir. Bu eylem modülün içinden henüz denenmedi; aynı işlem elle, BaikalOS 16.3 (user derleme) çalıştıran bir POCO F1'de çalıştı.

## Bilinen sınırlar

- Android etkin WebView sağlayıcısını kaldırmıyor (`DELETE_FAILED_INTERNAL_ERROR`). Önce başka bir sağlayıcıya geçin.
- Eylem düğmesiyle sisteme taşınan WebView'lar modülle birlikte kaldırılır.
- WVC'nin `/data`'ya kurduğu WebView'lar modül kaldırılınca yerinde kalır.
- Başka bir kimlikle kurulu bir WebView Changer modülü kurulumu durdurur. Önce onu kaldırıp yeniden başlatın: onun kaldırma betiği bir sonraki açılışta kurduğu paketleri siler, bunlar arasında WVC'nin kurduğu paketler de olabilir.
- Eski WVC (Lordify tabanlı, aynı kimlik) bu sürümle değiştirilir. Yeniden başlatmadan sonra stok WebView ve Chrome geri gelir. Eski sürümün kurduğu GrapheneOS Vanadium `/data`'da kalır; kurulum ekranı onun için `pm uninstall` komutunu gösterir.

## Test edilen cihazlar

| Cihaz | ROM | Root | Sonuç |
|---|---|---|---|
| Xiaomi Mi Note 10 (tucana) | LineageOS 23.2 (Android 16), BitGApps | FolkPatch, Zygisk Next 1.5.2, LSPosed 2.2.1, Hybrid Mount 6.2.5, AnyWebView 1.4.5 | WVC 9.1: kurulum, 9.0 üzerine güncelleme, 32 bit APK atlandı, Vanadium geçerli ve etkin; AOSmium AnyWebView ile geçerli |
| Samsung Galaxy A8 2018 (SM-A530F) | Galaxy S23 FE yazılımının One UI portu (XROM V16.1, Android 16) | Magisk (yerleşik Zygisk), LSPosed 2.2.1, AnyWebView 1.4.5 | WVC 9.1: kurulum; Google WebView, Cromite, Vanadium ve AOSmium geçerli; Vanadium etkin |

Vanadium çatalı WVC olmadan bir Mi Note 10 Pro'da (LineageOS 23.2) ve bir Pixel 4a 5G'de (LineageOS 24, Android 17) de denendi. Her sürümün test notları sürüme eklenir ve [test-notes](test-notes) klasöründe durur.

## Vanadium çatalı

WVC Vanadium çatalı, [GrapheneOS Vanadium](https://github.com/GrapheneOS/Vanadium)'un GrapheneOS dışındaki ROM'lar için resmi olmayan bir derlemesidir. GrapheneOS ile bağlantısı yoktur ve GrapheneOS tarafından onaylanmamıştır. GrapheneOS'ta işletim sistemiyle gelen Vanadium'u kullanın.

GrapheneOS derlemesinden farkları:

- Paket adı `org.wvc.vanadium_wv`: stok WebView'ın yanında durabilir, `app.vanadium.webview` ile çakışmaz.
- Bağımsız WebView hedefi `vanadium_webview_64_32_apk` ile, arm64 ve armeabi-v7a kütüphaneleriyle birlikte derlenir. GrapheneOS yalnız 64 bit derler; Android bunu 32 bit uygulamaları da destekleyen cihazlara kurmuyor.
- WVC anahtarıyla imzalıdır (sertifika SHA-256 `40342a299f0c62287330134005e5d5df8901ec3cd6c1c1b2e884396ca6332a88`).
- Vanadium config uygulaması yok: Vanadium yerleşik varsayılanlarıyla, içerik süzme olmadan çalışır.
- `args.gn`'nin geri kalanı ve bütün yamalar değişmedi.

Kaynak: sürümde adı geçen etiketteki (örneğin `156.0.8078.47.0`) [Gursu-Bilisim/Vanadium](https://github.com/Gursu-Bilisim/Vanadium) çatalı ve [vanadium/vanadium-wvc.sh](vanadium/vanadium-wvc.sh). Betik Chromium'u ve Vanadium'u o etiketten indirir, yamaları uygular, APK'yı derler ve imzalar. Derleme x86-64 Linux ister; Chromium'un Android derleme belgesi en az 100 GB boş disk istiyor.

## Güncellemeler

Yeni sürümler [GitHub sürümleri](https://github.com/Gursu-Bilisim/WVC/releases) olarak yayımlanır. Modülün `updateJson` satırı [update.json](update.json) dosyasını gösterir; Magisk, KernelSU ve APatch modül güncellemelerini modül listesinde bildirir.

## Tanı araçları

`tools/` geliştirme sırasında kullanılan betikleri içerir (mesajlar Türkçe):

- `wvc-tani.ps1` ve `wvc-tani.sh`: Windows'tan adb ile çalışır; WebView servisinin durumunu, overlay'leri, LSPosed ve logcat satırlarını her cihaz için tek bir rapora toplar.
- `anr-tani.sh`: son ANR ve watchdog dökümlerini ve kilitleri tutan iş parçacıklarını toplar.

## Teşekkür

- Lordify, [WebView Changer](https://gitlab.com/Lordify/webview-changer)
- neoblackxt, [AnyWebView](https://github.com/neoblackxt/AnyWebView)
- GrapheneOS, [Vanadium](https://github.com/GrapheneOS/Vanadium)
- AXP.OS, [AOSmium](https://codeberg.org/AXP-OS/app_aosmium)
- uazo, [Cromite](https://github.com/uazo/cromite)

## Lisans

Modül, araçlar ve derleme betiği GNU General Public License v3.0 ya da sonraki sürümler altında lisanslıdır ([LICENSE](LICENSE)). Vanadium yamaları kendi lisanslarını korur (GPL-2.0-only, çatala bakın).
