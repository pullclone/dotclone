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
locker_expected="$(nix_opt_json_or_null "my.security.locker.expected")"
locker_active="$(nix_opt_json_or_null "my.security.locker.active")"
pam_targets_json="$(nix_opt_json_or_null "my.security.pam.targets")"
lock_handler_enable="$(nix_opt_json_or_null "services.systemd-lock-handler.enable")"

fp_enable="$(nix_opt_json_or_null "my.security.fingerprint.enable")"
fp_services_json="$pam_targets_json"

locker="unknown"
if [[ "$panel" == "noctalia" || "$noctalia_enabled" == "true" ]]; then
  locker="noctalia"
elif [[ "$swaylock_enabled" == "true" ]]; then
  locker="swaylock"
fi

expected_locker="$locker"
if [[ "$locker_expected" != "null" && -n "$locker_expected" ]]; then
  expected_locker="$locker_expected"
fi

expected_pam_service="unknown"
expected_lock_service="unknown"
if [[ "$expected_locker" == "swaylock" ]]; then
  expected_pam_service="swaylock"
  expected_lock_service="swaylock"
elif [[ "$expected_locker" == "noctalia" ]]; then
  expected_pam_service="noctalia-shell"
  expected_lock_service="noctalia-lock"
fi

pam_target_ok="unknown"
if [[ "$pam_targets_json" != "null" && "$expected_pam_service" != "unknown" ]]; then
  if echo "$pam_targets_json" | jq -e --arg svc "$expected_pam_service" 'index($svc) != null' >/dev/null 2>&1; then
    pam_target_ok="true"
  else
    pam_target_ok="false"
  fi
fi

pam_service_exists="unknown"
if [[ "$expected_pam_service" != "unknown" ]]; then
  pam_service_json="$(nix_opt_json_or_null "security.pam.services.${expected_pam_service}")"
  if [[ "$pam_service_json" != "null" ]]; then
    pam_service_exists="true"
  else
    pam_service_exists="false"
  fi
fi

lock_wanted_json="$(read_opt_json "home-manager.users.${user}.systemd.user.services.${expected_lock_service}.Install.WantedBy")"
lock_target_ok="unknown"
if [[ "$lock_wanted_json" != "null" && "$expected_lock_service" != "unknown" ]]; then
  if echo "$lock_wanted_json" | jq -e 'index("lock.target") != null' >/dev/null 2>&1; then
    lock_target_ok="true"
  else
    lock_target_ok="false"
  fi
fi

echo "Locker audit"
echo "------------"
echo "User:                 $user"
echo "Panel (HM):           $panel"
echo "Noctalia enabled:     $noctalia_enabled"
echo "Noctalia lockSuspend: $noctalia_lock_suspend"
echo "Swaylock enabled:     $swaylock_enabled"
echo "Lock handler enabled: $lock_handler_enable"
echo "Detected locker:      $locker"
echo "Expected locker:      $expected_locker"
echo "Locker (active):      $locker_active"
echo "Expected PAM svc:     $expected_pam_service"
echo "PAM target ok:        $pam_target_ok"
echo "PAM service exists:   $pam_service_exists"
echo "Lock target service:  $expected_lock_service"
echo "Lock target OK:       $lock_target_ok"
echo "Fingerprint enable:   $fp_enable"
echo "Fingerprint services: $fp_services_json"
echo "PAM targets:          $pam_targets_json"

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

if [[ "$pam_target_ok" == "false" ]]; then
  echo "  WARNING: my.security.pam.targets does not include expected locker PAM service (${expected_pam_service})."
fi
if [[ "$pam_service_exists" == "false" ]]; then
  echo "  WARNING: security.pam.services.${expected_pam_service} is not defined."
fi
if [[ "$lock_target_ok" == "false" ]]; then
  echo "  WARNING: lock.target does not include ${expected_lock_service} in WantedBy."
fi
if [[ "$lock_handler_enable" != "true" ]]; then
  echo "  WARNING: services.systemd-lock-handler.enable is not true."
fi

if [[ "$fp_enable" == "true" && "$fp_services_json" != "null" ]]; then
  echo
  echo "Fingerprint audit:"
  fp_services=$(echo "$fp_services_json" | jq -r '.[]?' 2>/dev/null || true)
  if [[ -z "$fp_services" ]]; then
    echo "  WARNING: fingerprint enabled but no PAM services listed."
  else
    for svc in $fp_services; do
      if [[ "$svc" == "doas" ]]; then
        continue
      fi
      fpauth=$(nix_opt_json_or_null "security.pam.services.${svc}.fprintAuth")
      unixauth=$(nix_opt_json_or_null "security.pam.services.${svc}.unixAuth")
      echo "  ${svc}: fprintAuth=${fpauth}, passwordFallback=${unixauth}"
    done
  fi
fi
