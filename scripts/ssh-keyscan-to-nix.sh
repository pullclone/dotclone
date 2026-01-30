#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <host> [host...]" >&2
  exit 1
fi

echo "# VERIFY THIS KEY OUT-OF-BAND BEFORE COMMITTING"
echo "{"
for host in "$@"; do
  key=$(ssh-keyscan -t ed25519 "$host" 2>/dev/null | awk 'NR==1 {print $2 " " $3}')
  if [ -z "$key" ]; then
    continue
  fi
  cat <<EOF_SNIPPET
  "${host}" = {
    hostNames = [ "${host}" ];
    publicKey = "${key}";
  };
EOF_SNIPPET
done
echo "}"
