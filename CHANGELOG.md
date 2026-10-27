# Changelog

## v9.2 (2026-10-27)

- Daily update check for the installed WVC Vanadium fork, AOSmium, Cromite and AnyWebView. New versions are shown in the module description and in one notification (posted by the Shell app); the Action button downloads, checks and installs them.
- Cromite is recognised by its signing certificate, so a ROM's AOSP WebView with the same package name is not treated as Cromite.
- Downloads use `wvc-fetch.dex` (Android's HTTPS implementation, certificate checked against the system CA store, https only) instead of busybox `wget`, which does not check certificates. Source in `fetch/`.
- The check can be turned off with `/data/adb/modules/WVC/disable_update_check`; the file is kept on module updates.
- The installer banner reads the version from `module.prop`.

## v9.1 (2026-10-27)

- Rewrite. WebViews are installed next to the stock WebView instead of replacing it; the provider list is extended by AnyWebView (LSPosed).
- Installs the APKs found in `/sdcard/WVC` or a `WVC` folder on the SD card: AOSmium, the WVC Vanadium fork, Cromite.
- Skips APKs without native libraries for every device ABI, and Vanadium below Android 14.
- Checks the Zygisk provider, LSPosed and AnyWebView at install time.
- Status report after boot (`status.txt`, module description); Action button shows the report and moves packages with `Version code too low` to the system partition (not yet tested inside the module).
- Keeps previous installs on update; replaces the old Lordify-based WVC; stops if another WebView Changer module is installed.
- Turkish or English messages depending on the system language.
- `updateJson` for update notifications in the root manager.
