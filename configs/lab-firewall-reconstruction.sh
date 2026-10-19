#!/usr/bin/env bash
# Portfolio reconstruction from documented CSCI 412 Labtainer commands.
# Not the byte-for-byte original example_fw.sh.
# DANGEROUS on normal systems: changes default policies to DROP!
set -euo pipefail

if [[ "${LABTAINERS_DISPOSABLE_FIREWALL_ONLY:-}" != "I_ACKNOWLEDGE_NETWORK_LOSS_RISK" ]]; then
  echo 'Refusing to change firewall rules. Use only inside a disposable Labtainer firewall container.' >&2
  echo 'Read the README and inspect this script first.' >&2
  exit 2
fi
if [[ "$(id -u)" != "0" ]]; then
  echo 'Root required inside the isolated lab container.' >&2
  exit 2
fi

IPTABLES="$(command -v iptables)"
CLIENT=172.24.0.3
SERVER=172.25.0.3

# Base experiment: flush existing filter/NAT rules in the disposable lab.
"$IPTABLES" -F
"$IPTABLES" -t nat -F
"$IPTABLES" -X
"$IPTABLES" -P FORWARD DROP
"$IPTABLES" -P INPUT DROP
"$IPTABLES" -P OUTPUT DROP

# Accept response traffic for established connections and the course's initial SSH rule.
"$IPTABLES" -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
"$IPTABLES" -A FORWARD -p tcp --dport 22 -j ACCEPT
"$IPTABLES" -A INPUT -i lo -j ACCEPT

# Later course steps: permit lab service on port 10071, then deny HTTP from one client.
"$IPTABLES" -A FORWARD -p tcp -s "$CLIENT" -d "$SERVER" --dport 10071 -j ACCEPT
"$IPTABLES" -I FORWARD 1 -p tcp -s "$CLIENT" -d "$SERVER" --dport 80 -j DROP

# Log unmatched traffic at a bounded rate before the default DROP policy.
"$IPTABLES" -A FORWARD -m limit --limit 2/min -j NFLOG --nflog-prefix 'IPTABLES DROPPED'
"$IPTABLES" -L FORWARD -v -n --line-numbers
