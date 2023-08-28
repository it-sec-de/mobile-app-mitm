#! /bin/sh

# Disables Certificate Transparency on Chrome/WebView based apps.

cert=proxy.der

spki_fingerprint=$(openssl x509 -in $cert -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)
printf 'SPKI Fingerprint: %s\n' "$spki_fingerprint" >&2

printf 'Generating SPKI disable chrome command line and pushing on target device...\n' >&2
printf 'chrome --ignore-certificate-errors-spki-list=%s\n' "$spki_fingerprint" > .chrome-command-line
adb push .chrome-command-line /storage/emulated/0/Download/

printf 'Copying command line to each chrome environment\n' >&2
adb shell <<EOF
su

for dest in /data/local/chrome-command-line /data/local/android-webview-command-line /data/local/webview-command-line /data/local/content-shell-command-line /data/local/tmp/chrome-command-line /data/local/tmp/android-webview-command-line /data/local/tmp/webview-command-line /data/local/tmp/content-shell-command-line; do
	cp /storage/emulated/0/Download/.chrome-command-line \$dest
	chmod 555 \$dest
done

am force-stop com.android.chrome

exit
exit
EOF
