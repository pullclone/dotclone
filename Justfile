export system_profile := env("SYSTEM_PROFILE", "balanced")
export latencyflex_enable := env("LATENCYFLEX_ENABLE", "true")
export config_name := "nyx-{{ system_profile }}-lfx-{{ if eq latencyflex_enable \"true\" }}on{{ else }}off{{ end }}"

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
    nix build ".#nixosConfigurations.{{ config_name }}.config.system.build.toplevel"

[group('Nix')]
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#{{ config_name }}"

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
    sudo nixos-rebuild switch --flake ".#nyx-{{ system_profile }}-lfx-on"

[group('Nix')]
switch-latencyflex-off:
    #!/usr/bin/env bash
    set -euo pipefail
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

[group('Lint')]
lint:
    @just check
    @just lint-shell
    @echo "Lint OK"

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
    just lint
    just build
    just test
    @echo "CI OK"
