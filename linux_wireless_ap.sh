#! /bin/sh

# Automatically enables Linux kernel routing mode,
# starts a wireless hotspot/access point and
# routes requests on some ports to the proxy.
#
# This script isn't very generic and makes a couple of assumptions about the underlying base system:
#  * NetworkManager for managing network interfaces
#  * A default "Hotspot" profile
#  * The Linux kernel tool `iw` pre-installed
#  * IP tables for firewalling

set -e

dryrun=
while getopts n opt; do
  case $opt in
  n) dryrun=echo;;
  ?) printf 'Usage: %s: [-n]\n' "$0"
     printf ' -n: dry-run, print commands instead of executing them\n'
     exit 2;;
 esac
done

WLAN_AP=
PROXY_IP=127.0.0.1
PROXY_PORT=8080

printf '# Using Wireless Interface %s for Hotspot/AP\n' "${WLAN_AP:=$(iw dev | awk '/Interface/ { print $2; exit }')}" >&2

# https://askubuntu.com/a/1444282/265381
printf '# NetworkManager: Quirk: Change Security Key Management paremeters\n' >&2
$dryrun nmcli connection modify Hotspot 802-11-wireless-security.key-mgmt sae
printf '# NetworkManager: Enable Hotspot\n' >&2
$dryrun nmcli connection up Hotspot

printf '# Kernel: Allow forwarding / enable routing functionality\n' >&2
$dryrun sudo sysctl -w net.ipv4.ip_forward=1
$dryrun sudo sysctl -w net.ipv6.conf.all.forwarding=1

printf '# Firewall: Redirect IPv4 traffic on :80 and :443 (HTTP/s) to proxy\n' >&2
$dryrun sudo iptables -t nat -A PREROUTING -i $WLAN_AP -p tcp --dport 80  -j REDIRECT --to-ports $PROXY_PORT
$dryrun sudo iptables -t nat -A PREROUTING -i $WLAN_AP -p tcp --dport 443 -j REDIRECT --to-ports $PROXY_PORT

printf '# Firewall: Redirect IPv6 traffic on :80 and :443 (HTTP/s) to proxy\n' >&2
$dryrun sudo ip6tables -t nat -A PREROUTING -i $WLAN_AP -p tcp --dport 80  -j REDIRECT --to-ports $PROXY_PORT
$dryrun sudo ip6tables -t nat -A PREROUTING -i $WLAN_AP -p tcp --dport 443 -j REDIRECT --to-ports $PROXY_PORT

