# Vanadium WVC fork 156.0.8078.47.0 test notes

Artifact: `VanadiumWebView-WVC-156.0.8078.47.0-64_32.apk`, SHA-256 `0f4076f6670888ce86e8632c188502233037e05e33cefda1d2823f5cae8bd9ed`

- Package `org.wvc.vanadium_wv`, versionName `156.0.8078.47.0`, versionCode `807804703`, minSdk 34, targetSdk 37
- Native code: `arm64-v8a`, `armeabi-v7a`
- Signer: `CN=WVC`, certificate SHA-256 `40342a299f0c62287330134005e5d5df8901ec3cd6c1c1b2e884396ca6332a88` (APK Signature Scheme v3)
- Source: GrapheneOS Vanadium tag `156.0.8078.47.0` (fork: Gursu-Bilisim/Vanadium), Chromium `156.0.8078.47`
- Build: `vanadium/vanadium-wvc.sh` with `WVC_ABI=64_32` on Ubuntu 22.04 (WSL2), target `vanadium_webview_64_32_apk`; `args.gn` = Vanadium `args.gn` with `system_webview_package_name = "org.wvc.vanadium_wv"` and `enable_android_secondary_abi = true`

## Results

| Device | ROM | AnyWebView | Result |
|---|---|---|---|
| Xiaomi Mi Note 10 Pro (tucana) | LineageOS 23.2 (Android 16) | 1.4.4 | Added by the hook after a reboot, `Valid`; selected in Developer options and used for browsing (user report) |
| Google Pixel 4a 5G (bramble) | LineageOS 24 (Android 17) | 1.4.5 | `Valid`, active provider; an app loaded `org.wvc.vanadium_wv` and started its sandboxed renderer |
| Samsung Galaxy A8 2018 (SM-A530F) | One UI port (XROM V16.1, Android 16) | 1.4.5 | Added through the constructor hook, `Valid`, active provider |
| Xiaomi Mi Note 10 (tucana) | LineageOS 23.2 (Android 16) | 1.4.5 | Installed by WVC v9.1, `Valid`, active provider |

## Notes

- A newly installed Vanadium shows up in the list after the next boot: AnyWebView scans installed WebViews once per boot.
- Without the Vanadium config app, every WebView process logs `cr_VanadiumConfParser: No parsed config found, parsing not initialized`. Expected; defaults are used.
- The earlier 64-bit-only build (`vanadium_webview_64_apk`) failed to install on tucana: `INSTALL_FAILED_INTERNAL_ERROR: ... The multiArch app's native libs don't support all the natively supported ABIs of the device.`

## Not tested

- POCO F1 (beryllium) and Galaxy Tab S7+ (SM-T970).
- Updating from an earlier fork version (this is the first release).
