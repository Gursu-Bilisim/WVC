# WebView Changer (WVC)

[Türkçe](README.tr.md)

A Magisk / KernelSU / APatch module that installs alternative WebView providers next to the stock WebView. The stock WebView stays in place, and you can switch between the providers at any time in **Developer options > WebView implementation**.

WVC was inspired by Lordify's [WebView Changer](https://gitlab.com/Lordify/webview-changer). Version 9 is a rewrite: it no longer hides the stock WebView or replaces the provider list with an overlay.

## Supported providers

| Provider | Package | Download | Notes |
|---|---|---|---|
| AOSmium (AXP.OS) | `org.axpos.aosmium_wv` | [Codeberg releases](https://codeberg.org/AXP-OS/app_aosmium/releases): `webview64-signed.apk` on 64-bit devices, `webview32-signed.apk` on 32-bit-only devices | Android 10 or newer |
| Vanadium, WVC fork | `org.wvc.vanadium_wv` | [WVC releases](https://github.com/Gursu-Bilisim/WVC/releases), tags starting with `vanadium-` | Android 14 or newer, arm64 devices. Unofficial build, see [Vanadium fork](#vanadium-fork) |
| Cromite | `com.android.webview` | [Cromite releases](https://github.com/uazo/cromite/releases): `arm64_SystemWebView.apk` | Uses the AOSP WebView package name. On ROMs that ship an AOSP WebView it installs as an update of it and takes its place in the list |

WVC does not install Google WebView (it updates from the Play Store) or the GrapheneOS-signed Vanadium.

## Requirements

- Root: Magisk, KernelSU or APatch (including FolkPatch). WVC has been tested with Magisk and FolkPatch; KernelSU has not been tested yet, so a [test report](#test-reports) from a KernelSU device is welcome.
- A Zygisk provider: Magisk's built-in Zygisk, or [Zygisk Next](https://github.com/LSPosed/ZygiskNext/releases) on KernelSU and APatch.
- [LSPosed](https://lsposed.zip) and [AnyWebView](https://github.com/neoblackxt/AnyWebView/releases) 1.4.5 or newer. In LSPosed, AnyWebView's scope must be **System Framework** only. AnyWebView adds installed WebView packages to the system's provider list; without it, only providers that the ROM already lists can be selected. Version 1.4.5 also works on builds where `getWebViewPackages()` is inlined, such as Samsung One UI ([issue #37](https://github.com/neoblackxt/AnyWebView/issues/37)).
- Only for the system install action on KernelSU and APatch: a metamodule such as [Hybrid Mount](https://github.com/Hybrid-Mount/meta-hybrid_mount/releases).

## Installation

1. Install LSPosed and AnyWebView, enable AnyWebView with the System Framework scope, and reboot.
2. Put the APKs of the WebViews you want into `/sdcard/WVC` (or a `WVC` folder on the SD card). WVC installs exactly the APKs it finds there.
3. Install the WVC zip from the root manager app. Installing from recovery is not supported.
4. Reboot. AnyWebView scans installed WebViews once per boot, so newly installed providers show up after the next boot.
5. Pick a provider in Developer options > WebView implementation.

During installation WVC reads the package name from each APK, skips APKs that are not WebView providers, and skips APKs that lack a native library for one of the device's ABIs (the WebView manifest is `multiArch`, so Android rejects them). It then checks the Zygisk provider, LSPosed and AnyWebView and reports what is missing.

Installer, Action and status messages are in Turkish when the system language is Turkish and in English otherwise.

## Status and the Action button

After every boot WVC writes a status report to `/data/adb/modules/WVC/status.txt` and a short summary to the module description. The Action button in the root manager shows the same report: root manager, Zygisk, LSPosed and AnyWebView versions, the AnyWebView hook log, every provider in the system list with its state, and the WVC packages. It then checks for new versions of the installed WebViews and installs them (see [Updates of the installed WebViews](#updates-of-the-installed-webviews)).

If a WVC package shows `Version code too low`, its version is below the ROM's minimum WebView version, which Android takes from the factory (system partition) versions of the listed providers. The Action button then copies that package into the module as a system app (`/product/app`) and removes its `/data` copy. After a reboot the system copy counts as a factory version and lowers the minimum. On KernelSU and APatch this needs an active metamodule. This action has not yet been tested from within the module; the same procedure done by hand worked on a POCO F1 with BaikalOS 16.3 (user build).

## Known limitations

- Android does not uninstall the active WebView provider (`DELETE_FAILED_INTERNAL_ERROR`). Switch to another provider first.
- WebViews moved to the system with the Action button are removed together with the module.
- WebViews that WVC installed to `/data` stay installed when the module is removed.
- Another WebView Changer module installed under a different ID stops the installation. Remove it and reboot first: its uninstall script removes the packages it installed on the next boot, which could include packages that WVC installs.
- The update check needs network access. Without it WVC retries every hour.
- An older WVC (Lordify-based, same ID) is replaced. After a reboot the stock WebView and Chrome come back. A GrapheneOS Vanadium installed by the old version stays in `/data`; the installer shows the `pm uninstall` command for it.

## Tested devices

| Device | ROM | Root | Result |
|---|---|---|---|
| Xiaomi Mi Note 10 (tucana) | LineageOS 23.2 (Android 16), BitGApps | FolkPatch, Zygisk Next 1.5.2, LSPosed 2.2.1, Hybrid Mount 6.2.5, AnyWebView 1.4.5 | WVC 9.1: install, update over 9.0, 32-bit APK skipped, Vanadium valid and active; AOSmium valid through AnyWebView. WVC 9.2: certificate checks of the downloader, update check with the Action button |
| Samsung Galaxy Tab S7+ Wi-Fi (SM-T970) | Android 16 | FolkPatch, Hybrid Mount, Zygisk Next, LSPosed 2.2.1, AnyWebView 1.4.5 | WVC 9.2: update from 9.1 through the root manager; Cromite recognised by its certificate; Vanadium, AOSmium and Cromite valid. WVC 9.3: Turkish messages, update check at boot |
| Samsung Galaxy A8 2018 (SM-A530F) | One UI port of the Galaxy S23 FE firmware (XROM V16.1, Android 16) | Magisk with built-in Zygisk, LSPosed 2.2.1, AnyWebView 1.4.5 | WVC 9.1: install; Google WebView, Cromite, Vanadium and AOSmium valid; Vanadium active. WVC 9.2: update check at boot with notification, Cromite 148 to 153 installed with the Action button |

The Vanadium fork was also tested without WVC on a Mi Note 10 Pro (LineageOS 23.2) and a Pixel 4a 5G (LineageOS 24, Android 17). Test notes for every release are attached to the release and kept in [test-notes](test-notes).

## Vanadium fork

The WVC Vanadium fork is an unofficial build of [GrapheneOS Vanadium](https://github.com/GrapheneOS/Vanadium) for ROMs other than GrapheneOS. It is not affiliated with or endorsed by GrapheneOS. On GrapheneOS, use the Vanadium that ships with the OS.

Differences from the GrapheneOS build:

- Package name `org.wvc.vanadium_wv`, so it can sit next to the stock WebView and does not clash with `app.vanadium.webview`.
- Built from the standalone WebView target `vanadium_webview_64_32_apk` with both arm64 and armeabi-v7a libraries. GrapheneOS builds 64-bit only, which Android refuses to install on devices that also support 32-bit apps.
- Signed with the WVC key (certificate SHA-256 `40342a299f0c62287330134005e5d5df8901ec3cd6c1c1b2e884396ca6332a88`).
- No Vanadium config app: Vanadium runs with its built-in defaults, without content filtering.
- The rest of `args.gn` and all patches are unchanged.

Source: the [Gursu-Bilisim/Vanadium](https://github.com/Gursu-Bilisim/Vanadium) fork at the tag named in the release (for example `156.0.8078.47.0`), plus [vanadium/vanadium-wvc.sh](vanadium/vanadium-wvc.sh), which fetches Chromium and Vanadium at that tag, applies the patches and builds and signs the APK. The build needs x86-64 Linux; Chromium's Android build instructions ask for at least 100 GB of free disk space.

## Updates

New versions of WVC are published as [GitHub releases](https://github.com/Gursu-Bilisim/WVC/releases). The module's `updateJson` points to [update.json](update.json), so Magisk, KernelSU and APatch show module updates in their module list.

### Updates of the installed WebViews

Once a day WVC checks for new versions of the packages that are installed on the device: the WVC Vanadium fork, AOSmium, Cromite and AnyWebView. The first check runs at the first boot after installing WVC. Cromite is recognised by its signing certificate (SHA-256 `633fa41d8211d6d0916a819b89668c6de92e64232da67f9d16fd81c3b7e923ff`), so a ROM's own AOSP WebView, which uses the same package name, is not mistaken for it. The check reads the release lists of the [WVC](https://github.com/Gursu-Bilisim/WVC/releases), [AOSmium](https://codeberg.org/AXP-OS/app_aosmium/releases), [Cromite](https://github.com/uazo/cromite/releases) and [AnyWebView](https://github.com/neoblackxt/AnyWebView/releases) repositories through the GitHub and Codeberg APIs.

When it finds a new version, WVC writes it to the module description and posts one notification for that set of versions. The notification comes from the Shell app (`com.android.shell`), because Android drops notifications posted as root. Tapping it opens nothing: Android does not let the shell create a tap action for it. Turning off Shell notifications in the system settings also turns off these notifications.

The Action button checks again and installs the new versions. For each package it downloads the APK to `/data/local/tmp/wvc-dl`, checks the size, the SHA-256 published by GitHub or AOSmium's `.sha512` file, the package name and the ABIs, installs it with `pm install`, and deletes the download. Android installs an update only if it is signed with the same key as the installed package. Cromite's `arm64_SystemWebView.apk` is about 290 MB, and the Action screen shows no progress while it downloads. After an AnyWebView update, reboot.

Downloads use `wvc-fetch.dex`, a small Java program that runs with `app_process` and uses Android's own HTTPS implementation: the server certificate is checked against the system CA store, and only `https` addresses and redirects are accepted. The `wget` in the root managers' busybox does not check certificates, so WVC does not use it. Source and build script: [fetch/](fetch).

To turn the check off, create `/data/adb/modules/WVC/disable_update_check` (for example `touch /data/adb/modules/WVC/disable_update_check` in a root shell). The file is kept when WVC is updated. The Action button then only shows the status.

## Test reports

Reports from devices, ROMs and root managers that are not in the tested list help most, KernelSU above all. Open an issue with the [test report form](https://github.com/Gursu-Bilisim/WVC/issues/new?template=test-report.yml). It asks for the device, ROM, root manager and module versions, and the text WVC already writes: the Action output, `/data/adb/modules/WVC/status.txt` and `/data/adb/modules/WVC/update.log`. Remove anything personal before posting.

## Diagnostic tools

`tools/` contains the scripts used during development (messages in Turkish):

- `wvc-tani.ps1` and `wvc-tani.sh`: run from Windows over adb; collects the WebView service state, overlays, LSPosed and logcat lines into one report per device.
- `anr-tani.sh`: collects recent ANR and watchdog traces and the threads holding locks.

## Credits

- Lordify, [WebView Changer](https://gitlab.com/Lordify/webview-changer)
- neoblackxt, [AnyWebView](https://github.com/neoblackxt/AnyWebView)
- GrapheneOS, [Vanadium](https://github.com/GrapheneOS/Vanadium)
- AXP.OS, [AOSmium](https://codeberg.org/AXP-OS/app_aosmium)
- uazo, [Cromite](https://github.com/uazo/cromite)

## License

The module, the tools, the downloader and the build script are licensed under the GNU General Public License v3.0 or later ([LICENSE](LICENSE)). The Vanadium patches keep their own license (GPL-2.0-only, see the fork).
