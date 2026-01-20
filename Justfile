export system_profile := env("SYSTEM_PROFILE", "balanced")
export latencyflex_enable := env("LATENCYFLEX_ENABLE", "true")

[private]
assert-config:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ system_profile }}" in
      latency|balanced|throughput|battery|memory-saver) ;;
      *) echo "Invalid SYSTEM_PROFILE='{{ system_profile }}'. Expected one of: latency balanced throughput battery memory-saver" >&2; exit 1 ;;
    esac
    case "{{ latencyflex_enable }}" in
      true|false) ;;
      *) echo "Invalid LATENCYFLEX_ENABLE='{{ latencyflex_enable }}'. Expected true or false." >&2; exit 1 ;;
    esac

[group('Utility')]
bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking tools..."
    command -v just >/dev/null || { echo "Missing: just"; exit 1; }
    command -v nix >/dev/null || { echo "Missing: nix"; exit 1; }
    command -v git >/dev/null || { echo "Missing: git"; exit 1; }
    command -v jq >/dev/null || echo "Recommended: jq"
    command -v shellcheck >/dev/null || echo "Recommended: shellcheck"
    command -v shfmt >/dev/null || echo "Recommended: shfmt"
    echo "OK"

[group('Utility')]
env-ci:
    @echo 'Use this in constrained environments:'
    @echo '  NIX_REMOTE=daemon NIX_CONFIG="sandbox = false" just ci'

[private]
default:
    @just --list

[group('Nix')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    nix flake check .

[group('Nix')]
build:
    #!/usr/bin/env bash
    set -euo pipefail
    just assert-config
    name="nyx-{{ system_profile }}-lfx-$(if [ '{{ latencyflex_enable }}' = 'true' ]; then echo on; else echo off; fi)"
    nix build ".#nixosConfigurations.${name}.config.system.build.toplevel"

[group('Nix')]
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    just assert-config
    name="nyx-{{ system_profile }}-lfx-$(if [ '{{ latencyflex_enable }}' = 'true' ]; then echo on; else echo off; fi)"
    sudo nixos-rebuild switch --flake ".#${name}"

[group('Nix')]
switch-balanced:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-balanced-lfx-on"

[group('Nix')]
switch-aggressive:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-throughput-lfx-on"

[group('Nix')]
switch-writeback:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-memory-saver-lfx-on"

[group('Nix')]
switch-latencyflex-on:
    #!/usr/bin/env bash
    set -euo pipefail
    just assert-config
    sudo nixos-rebuild switch --flake ".#nyx-{{ system_profile }}-lfx-on"

[group('Nix')]
switch-latencyflex-off:
    #!/usr/bin/env bash
    set -euo pipefail
    just assert-config
    sudo nixos-rebuild switch --flake ".#nyx-{{ system_profile }}-lfx-off"

[group('Nix')]
switch-latency-lfx-on:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-latency-lfx-on"

[group('Nix')]
switch-latency-lfx-off:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-latency-lfx-off"

[group('Nix')]
switch-balanced-lfx-on:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-balanced-lfx-on"

[group('Nix')]
switch-balanced-lfx-off:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-balanced-lfx-off"

[group('Nix')]
switch-throughput-lfx-on:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-throughput-lfx-on"

[group('Nix')]
switch-throughput-lfx-off:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-throughput-lfx-off"

[group('Nix')]
switch-battery-lfx-on:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-battery-lfx-on"

[group('Nix')]
switch-battery-lfx-off:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-battery-lfx-off"

[group('Security')]
sec-preview target:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v doas >/dev/null 2>&1; then
        echo "doas is required for security previews; enable it first." >&2
        exit 1
    fi
    build=".#nixosConfigurations.{{ target }}.config.system.build.toplevel"
    nix build "$build"
    result="$(readlink -f result)"
    echo "Dry-activating $build via $result/bin/switch-to-configuration..."
    doas "$result/bin/switch-to-configuration" dry-activate

[group('Security')]
sec-test target:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v doas >/dev/null 2>&1; then
        echo "doas is required for security tests; enable it first." >&2
        exit 1
    fi
    doas nixos-rebuild test --flake ".#{{ target }}"

[group('Security')]
sec-switch target:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v doas >/dev/null 2>&1; then
        echo "doas is required for security switches; enable it first." >&2
        exit 1
    fi
    doas nixos-rebuild switch --flake ".#{{ target }}"

[group('Nix')]
build-uki target:
    #!/usr/bin/env bash
    set -euo pipefail
    nix build ".#nixosConfigurations.{{ target }}.config.system.build.bootspec"
    echo "UKI bootspec built at ./result"

[group('Apps')]
app-protonvpn-check target="nyx":
    #!/usr/bin/env bash
    set -euo pipefail
    nix eval ".#nixosConfigurations.{{ target }}.config.home-manager.users.ashy.my.home.apps.protonvpn.enable"

[group('Apps')]
app-protonvpn-enable target="nyx":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "To enable ProtonVPN GUI:"
    echo "  1) Set my.install.protonvpn.enable = true (install answers) or"
    echo "  2) Override home-manager.users.ashy.my.home.apps.protonvpn.enable = true"
    echo "Then rebuild: just sec-preview {{ target }} ; just sec-test {{ target }}"

[group('Observability')]
aide-init:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v doas >/dev/null 2>&1; then
        echo "doas is required to start aide-init service." >&2
        exit 1
    fi
    echo "Initializing AIDE database..."
    doas systemctl start aide-init.service

[group('Observability')]
aide-check:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v doas >/dev/null 2>&1; then
        echo "doas is required to run aide-check service." >&2
        exit 1
    fi
    doas systemctl start aide-check.service
    echo "AIDE check triggered; see /var/log/nyxos/aide for reports."

[group('Observability')]
lynis:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v doas >/dev/null 2>&1; then
        echo "doas is required to run lynis-audit service." >&2
        exit 1
    fi
    doas systemctl start lynis-audit.service

[group('Observability')]
lynis-report:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "/var/log/nyxos/lynis" ]; then
        echo "No Lynis reports found at /var/log/nyxos/lynis" >&2
        exit 1
    fi
    latest="$(ls -1 /var/log/nyxos/lynis | sort | tail -n1 || true)"
    if [ -z "$latest" ]; then
        echo "No Lynis reports found at /var/log/nyxos/lynis" >&2
        exit 1
    fi
    echo "Latest Lynis report directory: /var/log/nyxos/lynis/$latest"
    if [ -f "/var/log/nyxos/lynis/$latest/lynis.log" ]; then
        echo "--- Summary (tail -n 20) ---"
        tail -n 20 "/var/log/nyxos/lynis/$latest/lynis.log"
    fi

[group('Nix')]
switch-memory-saver-lfx-on:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-memory-saver-lfx-on"

[group('Nix')]
switch-memory-saver-lfx-off:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx-memory-saver-lfx-off"

[group('Nix')]
show:
    #!/usr/bin/env bash
    set -euo pipefail
    nix flake show .

[group('Lint')]
lint-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    /usr/bin/find install-nyxos.sh scripts -iname "*.sh" -type f -exec shellcheck "{}" ';'

[group('Format')]
fmt-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v shfmt >/dev/null 2>&1; then
        echo "shfmt could not be found. Please install it."
        exit 1
    fi
    /usr/bin/find install-nyxos.sh scripts -iname "*.sh" -type f -exec shfmt --write "{}" ';'

[group('Format')]
fmt-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    nix fmt .

[group('Format')]
check-nixfmt:
    #!/usr/bin/env bash
    set -euo pipefail
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    git diff > "$tmpdir/before.diff"
    nix fmt .
    git diff > "$tmpdir/after.diff"
    if ! diff -q "$tmpdir/before.diff" "$tmpdir/after.diff" >/dev/null; then
        echo "nix fmt introduced changes; please commit formatting."
        exit 1
    fi

[group('Lint')]
lint-nix-report:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p reports
    nix run .#statix -- check . > reports/statix.txt || true
    nix run .#deadnix -- . > reports/deadnix.txt || true

[group('Lint')]
lint:
    @just check
    @just lint-shell
    @echo "Lint OK"

[group('Audit')]
audit:
    #!/usr/bin/env bash
    set -euo pipefail
    just check-nixfmt
    scripts/audit-repo.sh

[group('Templates')]
audit-templates:
    #!/usr/bin/env bash
    set -euo pipefail
    scripts/audit-templates.sh

[group('Test')]
test-g502:
    #!/usr/bin/env bash
    set -euo pipefail

    if [ ! -e "./result" ]; then
        echo "No ./result symlink found. Run: just build"
        exit 1
    fi

    if [ ! -x "./result/sw/bin/g502-manager" ]; then
        echo "Missing g502-manager in build result"
        exit 1
    fi

    echo "g502-manager smoke test OK"

[group('Test')]
test-latencyflex:
    #!/usr/bin/env bash
    set -euo pipefail

    if [ ! -e "./result" ]; then
        echo "No ./result symlink found. Run: just build"
        exit 1
    fi

    manifest="./result/sw/share/vulkan/implicit_layer.d/latencyflex.json"
    if [ ! -f "$manifest" ]; then
        echo "Missing LatencyFleX manifest in build result: $manifest"
        exit 1
    fi

    # The layer should exist in the system profile; common location is ./result/sw/lib
    # (This assumes the package installs into $out/lib and patches the JSON accordingly.)
    if ! /usr/bin/find "./result/sw/lib" -maxdepth 1 -type f -name "*latencyflex*.so*" | grep -q .; then
        echo "Missing LatencyFleX shared library in build result under ./result/sw/lib"
        echo "Hint: ensure the package installs to \$out/lib and the manifest is patched."
        exit 1
    fi

    # Basic sanity: manifest should reference latencyflex and a .so path
    if ! grep -qi "latencyflex" "$manifest"; then
        echo "LatencyFleX manifest exists but does not mention latencyflex (unexpected): $manifest"
        exit 1
    fi
    if ! grep -q "\.so" "$manifest"; then
        echo "LatencyFleX manifest does not appear to reference a .so (unexpected): $manifest"
        exit 1
    fi

    echo "LatencyFleX smoke test OK"

[group('Test')]
test:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building and running smoke tests..."
    just build
    just test-g502
    just test-latencyflex
    echo "Smoke tests OK"

[group('CI')]
ci:
    just audit
    just build
    just test
    @echo "CI OK"
