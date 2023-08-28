# Mobile App Web Interception Setup

This repository collects some information and scripts to setup mobile apps for
certain penetration testing techniques.
This mostly focuses on the steps required to read, intercept and replay Web-API
requests from the tested app.

## General Setup: MITM

Many mobile apps act simply as a frontend to some API server.
As such, a large amount of testing concerns not much of the app itself,
but the traffic sent between the app and the server.
Thus, our goal is to create a classic Man-in-the-Middle setup:

```
  ╭───╮
  │   │            +----------+                ╒════════════╕
  │   │╶╶╶WiFi╶╶╶> |  Proxy   |╶╶╶Upstream╶╶╶> │••••••••    │
  │   │            +----------+                ╘════════════╛
  ╰───╯

 Phone           Pentest-System                  Server
```

We need to configure the following components:

1. Phone (Android/iOS)
2. Wireless AP
3. Transparent MITM proxy
4. Mobile App itself

The phone may or may not be emulated.
In this setup, we focus on physical devices only,
despite some linked resources referring to emulated devices due to the large overlap.

## Phone Setup

### Android

Modern Android systems do not allow to add custom certificates to the system store,
and apps need to explicitly opt-in into trusting user store certificates.
Further, writing the `/system` partition is heavily restricted and
not even directly possible with `root` user access,
due to read-only mounts and dm-verity protecting the system's integrity.
Thus, quite a few steps need to be undertaken in order to prepare the hosting phone
for the test.

For reference, we use Pixel 6a for testing purposes, as it's a cheap device to get hold of
but has recent system updates and features available,
and as such is a realistic target.
Further more, the devices allow unlocking and are well supported by flashing tools.

#### Rooting

Follow the
[Magisk Installation Guide](https://topjohnwu.github.io/Magisk/install.html)
to first enable OEM bootloader unlocking in settings and unlock it through fastboot (if not done already).
Afterwards, root the system with the recommended Magisk technique.
Note that updating the OS will remove the Magisk `su` binary again,
thus re-rooting would be necessary afterwards.

#### Enrolling Self-Signed Certificate

The next step is to enroll the self-signed certificate of your proxy solution into
the phone's system certificate store.

We've mostly automated this task through a shell script that implements 
functionality similar to HTTP Toolkit's "Android ADB" hook [^2],
described in prose in the corresponding guide [^1], and
also documented in a similar guide for emulators [^4].
First, export the certificate from e.g.,
Burp [^3], Mitmproxy or HTTP Toolkit (although, for the latter, we recommend using
the built-in functionality),
and run the script with the provided certificate:
```
./android_enrollcert.sh proxy.der
```

Note that this only adds the certificate into the system store.
Chrome/WebView based applications use Certificate Transparency to further
check the legitimacy of certificates.
The enrolled certificate can be separately exempted from this process.
Standalone apps may similarly enable certificate pinning which needs to be
disabled on a per-app basis.
Both are covered later in this guide.

### iOS

TBD

<!--
ch3ckra1n jailbreak
-->

## Wireless AP

Next, we need to start a WiFi Access Point for our device to connect to,
as well as route requests to our proxy endpoint.
Again, we've automated this setup, although a lot of this is highly specific to
the pentester's testing environment.
In this case, this is a rather classic Linux+NetworkManager+iptables system
with the GNOME default Hotspot profile.

You can dry-run the script using the `-n` flag to see the commands it would run:
```
./linux_wireless_ap.sh -n
```

## Transparent Proxy

Since we do not want the app to know that it's being proxied,
the proxy must act "transparent" or be invisible to it.
This is a different mode from the often default SOCKS5 proxy which you either
configure system-wide or in the browser or application.

The configuration required is highly specific to the proxy used.
For Burp, refer to the Android guide in [^3].

## Mobile App

Ontop of the operating system's security features,
mobile apps may employ additional security measures.

### Android

On Android, applications built around the built-in Chrome/WebView components,
the Android system will enforce Certificate Transparency (CT) for all visited endpoints.
Since our self-signed certificate is not in Google's CT log,
the browser engine will deny connections.
We can however explicitly allow our certificate be exempt from this verification,
similar to HTTP Toolkit's implementation of this feature [^5]:
```
# expects proxy.der in CWD
./android_chrome_kill_CT.sh
```

For standalone apps, Certificate Pinning is often employed to prevent MITM attacks
just like ours.
In that case, the public certificate of the API endpoint is hard-coded into the mobile
app and it will deny connections to any other certificate.
We can employ the Frida tool to inject code into the running application to disable
any such code.
We simply use HTTP Toolkit's Frida script that acts as a kind-of catch-all HTTP
Unpinning tool [^6],
with detailed steps described on their blog [^7].

### iOS

TBD

<!--
SSL Unpin app from Cydia store
-->


[^1]: https://httptoolkit.com/docs/guides/android/#adb-interception
[^2]: https://github.com/httptoolkit/httptoolkit-server/blob/main/src/interceptors/android/adb-commands.ts
[^3]: https://portswigger.net/burp/documentation/desktop/mobile/config-android-device
[^4]: https://docs.mitmproxy.org/stable/howto-install-system-trusted-ca-android/
[^5]: https://github.com/httptoolkit/httptoolkit-server/blob/main/src/interceptors/android/android-adb-interceptor.ts#L221
[^6]: https://github.com/httptoolkit/frida-android-unpinning
[^7]: https://httptoolkit.com/blog/frida-certificate-pinning/
