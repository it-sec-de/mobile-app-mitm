#! /bin/sh

# Automates enrolling custom SSL certificates into the system store of a rooted
# Android device.

set -e

ANDROID_TMPDIR=/data/local/tmp
ANDROID_SYSTEM_CA_PATH=/system/etc/security/cacerts

android_check() {
  printf 'Checking whether we run on Android ...\n' >&2
  if [ -z "$ANDROID_ROOT" ]; then
    printf 'This script is only to be run on Android devices\n' >&2
    exit 1
  fi
}

android_disable_verity() {
  android_check

  printf 'Disabling fs-verity as root (requires reboot)...\n' >&2
  printf 'WARNING: THIS FUNCTIONALITY IS BROKEN AND DISABLED -- MAYBE IT WORKS ANYWAY?!\n' >&2
  #su -c disable-verity
}

_android_enroll_ca() {
  cert="$1"
  printf 'Creating backup of current CA certificate store\n' >&2
  rm -rf "$ANDROID_TMPDIR/cacerts/" && mkdir "$ANDROID_TMPDIR/cacerts/"
  cp "$ANDROID_SYSTEM_CA_PATH/"* "$ANDROID_TMPDIR/cacerts"

  printf 'Overlaying CA store\n' >&2
  mount -t tmpfs tmpfs $ANDROID_SYSTEM_CA_PATH
  
  printf 'Restoring CA certificates\n' >&2
  cp "$ANDROID_TMPDIR/cacerts/"* "$ANDROID_SYSTEM_CA_PATH/"

  printf 'Adding own certificate\n' >&2
  cp "$cert" "$ANDROID_SYSTEM_CA_PATH/"

  printf 'Restoring permissions\n' >&2
  chown root:root "$ANDROID_SYSTEM_CA_PATH/"*
  chmod 644 "$ANDROID_SYSTEM_CA_PATH/"*
  chcon u:object_r:system_file:s0 "$ANDROID_SYSTEM_CA_PATH/"*
}

android_enroll_ca() {
  script="$0"
  cert="$2"

  android_check

  printf 'Running as root ...\n' >&2
  su -c "'$script' _android-enroll-ca '$cert'"
}

hash_cert() {
  cert_der="$1"
  cert_pem="${cert_der%.der}.pem"
  
  openssl x509 -inform DER -in "$cert_der" -out "$cert_pem"
  thehash="$(openssl x509 -inform PEM -subject_hash_old -in "$cert_pem" | head -1)"
  cp "$cert_pem" "$thehash.0"
  
  echo "$thehash.0"
}

disable_verity() {
  script="$1"

  printf 'Copying script to android client\n' >&2
  adb push "$script" "$ANDROID_TMPDIR/android_enrollcert.sh"
  adb shell "chmod +x '$ANDROID_TMPDIR/android_enrollcert.sh'"

  printf 'Running "android-disable-verity" on android client\n' >&2
  adb shell "'$ANDROID_TMPDIR'/android_enrollcert.sh android-disable-verity"
  printf 'Rebooting android client\n' >&2
  adb reboot && adb wait-for-device
}

enroll_ca() {
  script="$1"
  cert="$2"

  printf 'Copying script to android client\n' >&2
  adb push "$script" "$ANDROID_TMPDIR"/android_enrollcert.sh
  adb shell "chmod +x '$ANDROID_TMPDIR/android_enrollcert.sh'"

  printf 'Copying cert to android client\n' >&2
  adb push "$cert" ""$ANDROID_TMPDIR"/$cert"

  printf 'Running "android-enroll-ca" on android client\n' >&2
  adb shell ""$ANDROID_TMPDIR"/android_enrollcert.sh android-enroll-ca '"$ANDROID_TMPDIR"/$cert'"
}


run() {
  script="$1"
  cert="$2"

  hashedcert="$(hash_cert "$cert")"
  disable_verity "$script"
  enroll_ca "$script" "$hashedcert"
}

usage() {
  printf 'Usage: android_enrollcert.sh proxy.der\n'
  printf 'Advanced Usage (host only): android_enrollcert.sh hash-cert proxy.der|host-disable-verity|host-enroll-ca hashed.0\n'
  printf 'Advanced Usage (android client only): android_enrollcert.sh android-disable-verity|android-enroll-ca hashed.0\n'
}

if [ $# -lt 1 ]; then
  printf 'enrollcerts.sh: Certificate (or command) required!\n' >&2
  usage >&2
  exit 1
fi

# First, assume the given arg is a file
if [ -f "$1" ]; then
  cert="$1"
  run "$0" "$cert"
  exit 0
fi
# Otherwise it's (hopefully) a command:
command="$1"
case "$command" in
  hash-cert) hash_cert "$2"; exit 0;;
  #
  host-disable-verity) disable_verity "$0"; exit 0;;
  android-disable-verity) android_disable_verity; exit 0;;
  # Missing error handling if "$2" not provided
  host-enroll-ca) enroll_ca "$0" "$2"; exit 0;;
  android-enroll-ca) android_enroll_ca "$0" "$2"; exit 0;;
  _android-enroll-ca) _android_enroll_ca "$2"; exit 0;;
  # 
  -h|--help) usage; exit 0;;
  #
  *) printf 'Invalid cert or unknown command "%s"\n' "$command" >&2; usage >&2; exit 1; ;;
esac
