#!/usr/bin/env bash
set -euo pipefail

user="${1:-}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd nixos-option
require_cmd jq

nix_opt_json_or_null() {
  local path="$1"
  if nixos-option --json "$path" >/dev/null 2>&1; then
    nixos-option --json "$path" | jq -r .
  else
    echo "null"
  fi
}

read_opt_json() {
  local path="$1"
  if nixos-option --json "$path" >/dev/null 2>&1; then
    nixos-option --json "$path" | jq -r .
  else
    echo "null"
  fi
}

if [[ -z "$user" ]]; then
  user="$(read_opt_json "my.install.userName")"
  [[ "$user" == "null" ]] && user="${USER:-ashy}"
fi

panel="$(read_opt_json "home-manager.users.${user}.my.desktop.panel")"
noctalia_enabled="$(read_opt_json "home-manager.users.${user}.programs.noctalia-shell.enable")"
swaylock_enabled="$(read_opt_json "home-manager.users.${user}.programs.swaylock.enable")"
noctalia_lock_suspend="$(read_opt_json "home-manager.users.${user}.programs.noctalia-shell.settings.general.lockOnSuspend")"

fp_enable="$(nix_opt_json_or_null "my.security.fingerprint.enable")"
fp_services_json="$(nix_opt_json_or_null "my.security.fingerprint.pamServices")"

locker="unknown"
if [[ "$panel" == "noctalia" || "$noctalia_enabled" == "true" ]]; then
  locker="noctalia"
elif [[ "$swaylock_enabled" == "true" ]]; then
  locker="swaylock"
fi

echo "Locker audit"
echo "------------"
echo "User:                 $user"
echo "Panel (HM):           $panel"
echo "Noctalia enabled:     $noctalia_enabled"
echo "Noctalia lockSuspend: $noctalia_lock_suspend"
echo "Swaylock enabled:     $swaylock_enabled"
echo "Detected locker:      $locker"
echo "Fingerprint enable:   $fp_enable"
echo "Fingerprint services: $fp_services_json"

echo
echo "PAM snippets (/etc/pam.d) relevant to locker/escalation:"
pam_files=$(grep -ElEi 'login|lock|swaylock|noctalia|doas|sudo|system-auth' /etc/pam.d/* 2>/dev/null || true)
if [[ -z "$pam_files" ]]; then
  echo "  (no matching PAM files found)"
else
  for f in $pam_files; do
    echo "--- $f ---"
    sed -n '1,160p' "$f" || true
    echo
  done
fi

echo "Idle/suspend hooks summary:"
if [[ "$locker" == "noctalia" ]]; then
  if [[ "$noctalia_lock_suspend" == "true" ]]; then
    echo "  Noctalia configured to lock on suspend."
  else
    echo "  WARNING: Noctalia active but lockOnSuspend=false."
  fi
fi
if [[ "$noctalia_enabled" == "true" && "$swaylock_enabled" == "true" ]]; then
  echo "  WARNING: both Noctalia and swaylock appear enabled; ensure only one locker handles idle/suspend."
elif [[ "$locker" == "unknown" ]]; then
  echo "  WARNING: unable to detect a locker; check panel selection and Home Manager config."
else
  echo "  Single locker detected: $locker"
fi

if [[ "$fp_enable" == "true" && "$fp_services_json" != "null" ]]; then
  echo
  echo "Fingerprint audit:"
  fp_services=$(echo "$fp_services_json" | jq -r '.[]?' 2>/dev/null || true)
  if [[ -z "$fp_services" ]]; then
    echo "  WARNING: fingerprint enabled but no PAM services listed."
  else
    for svc in $fp_services; do
      fpauth=$(nix_opt_json_or_null "security.pam.services.${svc}.fprintAuth")
      unixauth=$(nix_opt_json_or_null "security.pam.services.${svc}.unixAuth")
      echo "  ${svc}: fprintAuth=${fpauth}, passwordFallback=${unixauth}"
    done
  fi
fi
