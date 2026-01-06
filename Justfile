export system := env("SYSTEM", "nyx")

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

[private]
default:
    @just --list

[group('Nix')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    nix flake check ./NixOS

[group('Nix')]
build:
    #!/usr/bin/env bash
    set -euo pipefail
    nix build ".#nixosConfigurations.nyx.config.system.build.toplevel"

[group('Nix')]
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo nixos-rebuild switch --flake ".#nyx"

[group('Lint')]
lint-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    /usr/bin/find NixOS -iname "*.sh" -type f -exec shellcheck "{}" ';'

[group('Format')]
fmt-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v shfmt >/dev/null 2>&1; then
        echo "shfmt could not be found. Please install it."
        exit 1
    fi
    /usr/bin/find NixOS -iname "*.sh" -type f -exec shfmt --write "{}" ';'

[group('Lint')]
lint:
    @just check
    @just lint-shell
    @echo "Lint OK"

[group('Test')]
test:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building and running smoke tests..."
    just build
    # Verify g502-manager exists in build result
    if [ ! -x "./result/sw/bin/g502-manager" ]; then
        echo "Missing g502-manager in build result"
        exit 1
    fi
    echo "Smoke tests OK"

[group('CI')]
ci:
    just lint
    just build
    just test
    @echo "CI OK"