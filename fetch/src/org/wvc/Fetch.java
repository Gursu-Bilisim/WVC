/*
 * WVC fetch: HTTPS downloads for the WVC module, run with app_process.
 * Uses Android's own HttpsURLConnection (Conscrypt), so the server certificate
 * is checked against the system CA store. Only https:// URLs and https
 * redirects are accepted.
 *
 *   CLASSPATH=wvc-fetch.dex app_process /system/bin org.wvc.Fetch <url> <file|-> [accept]
 *
 * Exit codes: 0 ok, 1 network/TLS error, 2 usage, 3 HTTP status other than 200.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
package org.wvc;

import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;

public final class Fetch {
    private static final String UA = "WVC-update-check (+https://github.com/Gursu-Bilisim/WVC)";

    public static void main(String[] args) {
        if (args.length < 2) {
            System.err.println("usage: Fetch <https-url> <file|-> [accept]");
            System.exit(2);
        }
        try {
            URL url = new URL(args[0]);
            HttpURLConnection c;
            int hops = 0;
            while (true) {
                if (!"https".equals(url.getProtocol())) {
                    throw new IOException("not https: " + url);
                }
                c = (HttpURLConnection) url.openConnection();
                c.setInstanceFollowRedirects(false);
                c.setConnectTimeout(30000);
                c.setReadTimeout(60000);
                c.setRequestProperty("User-Agent", UA);
                if (args.length > 2) {
                    c.setRequestProperty("Accept", args[2]);
                }
                int code = c.getResponseCode();
                if (code >= 300 && code < 400) {
                    String loc = c.getHeaderField("Location");
                    c.disconnect();
                    if (loc == null || ++hops > 5) {
                        throw new IOException("bad redirect from " + url.getHost());
                    }
                    url = new URL(url, loc);
                    continue;
                }
                if (code != 200) {
                    System.err.println("HTTP " + code + " " + url.getHost());
                    System.exit(3);
                }
                break;
            }
            InputStream in = c.getInputStream();
            boolean toStdout = "-".equals(args[1]);
            OutputStream out = toStdout ? System.out : new FileOutputStream(args[1]);
            byte[] buf = new byte[65536];
            int n;
            while ((n = in.read(buf)) > 0) {
                out.write(buf, 0, n);
            }
            out.flush();
            if (!toStdout) {
                out.close();
            }
            in.close();
            System.exit(0);
        } catch (Exception e) {
            System.err.println(e.toString());
            System.exit(1);
        }
    }
}
