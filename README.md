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

- Root: Magisk, KernelSU or APatch (including FolkPatch).
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

After every boot WVC writes a status report to `/data/adb/modules/WVC/status.txt` and a short summary to the module description. The Action button in the root manager shows the same report: root manager, Zygisk, LSPosed and AnyWebView versions, the AnyWebView hook log, every provider in the system list with its state, and the WVC packages.

If a WVC package shows `Version code too low`, its version is below the ROM's minimum WebView version, which Android takes from the factory (system partition) versions of the listed providers. The Action button then copies that package into the module as a system app (`/product/app`) and removes its `/data` copy. After a reboot the system copy counts as a factory version and lowers the minimum. On KernelSU and APatch this needs an active metamodule. This action has not yet been tested from within the module; the same procedure done by hand worked on a POCO F1 with BaikalOS 16.3 (user build).

## Known limitations

- Android does not uninstall the active WebView provider (`DELETE_FAILED_INTERNAL_ERROR`). Switch to another provider first.
- WebViews moved to the system with the Action button are removed together with the module.
- WebViews that WVC installed to `/data` stay installed when the module is removed.
- Another WebView Changer module installed under a different ID stops the installation. Remove it and reboot first: its uninstall script removes the packages it installed on the next boot, which could include packages that WVC installs.
- An older WVC (Lordify-based, same ID) is replaced. After a reboot the stock WebView and Chrome come back. A GrapheneOS Vanadium installed by the old version stays in `/data`; the installer shows the `pm uninstall` command for it.

## Tested devices

| Device | ROM | Root | Result |
|---|---|---|---|
| Xiaomi Mi Note 10 (tucana) | LineageOS 23.2 (Android 16), BitGApps | FolkPatch, Zygisk Next 1.5.2, LSPosed 2.2.1, Hybrid Mount 6.2.5, AnyWebView 1.4.5 | WVC 9.1: install, update over 9.0, 32-bit APK skipped, Vanadium valid and active; AOSmium valid through AnyWebView |
| Samsung Galaxy A8 2018 (SM-A530F) | One UI port of the Galaxy S23 FE firmware (XROM V16.1, Android 16) | Magisk with built-in Zygisk, LSPosed 2.2.1, AnyWebView 1.4.5 | WVC 9.1: install; Google WebView, Cromite, Vanadium and AOSmium valid; Vanadium active |

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

New versions are published as [GitHub releases](https://github.com/Gursu-Bilisim/WVC/releases). The module's `updateJson` points to [update.json](update.json), so Magisk, KernelSU and APatch show module updates in their module list.

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

The module, the tools and the build script are licensed under the GNU General Public License v3.0 or later ([LICENSE](LICENSE)). The Vanadium patches keep their own license (GPL-2.0-only, see the fork).
