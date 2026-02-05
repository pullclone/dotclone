#!/usr/bin/env bash

echo "🔍 NyxOS Configuration Test"
echo "================================"
echo ""

# Test 1: Check for ashy user (no dmail)
echo "✓ Test 1: Username consistency"
if grep -q "users.users.ashy" configuration.nix && ! grep -q "users.users.dmail" configuration.nix; then
    echo "  ✅ PASS: Only 'ashy' user found, no 'dmail' references"
else
    echo "  ❌ FAIL: User configuration issue detected"
fi

# Test 2: Check for timezone
echo "✓ Test 2: Timezone configuration"
if grep -q "time.timeZone" configuration.nix; then
    echo "  ✅ PASS: Timezone configuration found"
else
    echo "  ❌ FAIL: Timezone configuration missing"
fi

# Test 3: Check for privacy DNS
echo "✓ Test 3: Privacy-focused DNS"
if grep -q "142.242.2.2" configuration.nix; then
    echo "  ✅ PASS: Privacy DNS servers configured"
else
    echo "  ❌ FAIL: Privacy DNS not found"
fi

# Test 4: Check for optimizations
echo "✓ Test 4: Phase 3 optimizations"
if grep -q "PHASE 3" configuration.nix && \
   grep -q "Transparent HugePages" configuration.nix && \
   grep -q "TCP BBR" configuration.nix; then
    echo "  ✅ PASS: Phase 3 optimizations present"
else
    echo "  ❌ FAIL: Phase 3 optimizations missing"
fi

# Test 5: Check for monitoring
echo "✓ Test 5: Monitoring services"
if grep -q "netdata = {" configuration.nix && \
   grep -q "prometheus-node-exporter = {" configuration.nix && \
   grep -q "grafana = {" configuration.nix; then
    echo "  ✅ PASS: Monitoring services configured"
else
    echo "  ❌ FAIL: Monitoring services missing"
fi

# Test 6: Check for Btrfs optimizations
echo "✓ Test 6: Btrfs configuration"
if grep -q "compress=zstd:3" configuration.nix && \
   grep -q "autodefrag" configuration.nix; then
    echo "  ✅ PASS: Btrfs optimizations present"
else
    echo "  ❌ FAIL: Btrfs optimizations missing"
fi

# Test 7: Check flake.nix
echo "✓ Test 7: Flake configuration"
if grep -q "home-manager.users.ashy" flake.nix && ! grep -q "home-manager.users.dmail" flake.nix; then
    echo "  ✅ PASS: Flake uses 'ashy' user"
else
    echo "  ❌ FAIL: Flake user configuration issue"
fi

# Test 8: Check home configuration
echo "✓ Test 8: Home configuration"
if [ -f "home-ashy.nix" ] && ! [ -f "home-dmail.nix" ]; then
    echo "  ✅ PASS: home-ashy.nix exists, home-dmail.nix removed"
else
    echo "  ❌ FAIL: Home configuration issue"
fi

# Test 9: Nix eval checks (panel, IPv6, PAM, lock handler)
echo "✓ Test 9: Nix eval checks (panel/IPv6/PAM/lock)"
if command -v nix >/dev/null 2>&1; then
    system_name="${SYSTEM:-nyx}"
    panel=$(nix eval --raw ".#nixosConfigurations.${system_name}.config.my.install.desktop.panel" 2>/dev/null || true)
    if [ "$panel" = "noctalia" ] || [ "$panel" = "waybar" ]; then
        echo "  ✅ PASS: Panel selection is ${panel}"
    else
        echo "  ❌ FAIL: Panel selection invalid or eval failed (${panel:-empty})"
    fi

    ipv6=$(nix eval ".#nixosConfigurations.${system_name}.config.networking.enableIPv6" 2>/dev/null || true)
    if [ "$ipv6" = "true" ] || [ "$ipv6" = "false" ]; then
        echo "  ✅ PASS: IPv6 toggle evaluates to ${ipv6}"
    else
        echo "  ❌ FAIL: IPv6 toggle eval failed (${ipv6:-empty})"
    fi

    lock_handler=$(nix eval ".#nixosConfigurations.${system_name}.config.services.systemd-lock-handler.enable" 2>/dev/null || true)
    if [ "$lock_handler" = "true" ]; then
        echo "  ✅ PASS: systemd-lock-handler enabled"
    else
        echo "  ❌ FAIL: systemd-lock-handler not enabled (${lock_handler:-empty})"
    fi

    if nix eval ".#nixosConfigurations.${system_name}.config.security.pam.services.swaylock" >/dev/null 2>&1; then
        echo "  ✅ PASS: PAM service 'swaylock' present"
    else
        echo "  ❌ FAIL: PAM service 'swaylock' missing"
    fi

    if nix eval ".#nixosConfigurations.${system_name}.config.security.pam.services.\"noctalia-shell\"" >/dev/null 2>&1; then
        echo "  ✅ PASS: PAM service 'noctalia-shell' present"
    else
        echo "  ❌ FAIL: PAM service 'noctalia-shell' missing"
    fi
else
    echo "  ! SKIP: nix not available; skipping eval checks"
fi

echo ""
echo "📊 Configuration Summary:"
echo "========================"
echo ""
echo "Files checked:"
echo "  ✓ configuration.nix"
echo "  ✓ flake.nix"
echo "  ✓ home-ashy.nix"
echo ""
echo "All tests completed. Review results above."
echo "If all tests show ✅ PASS, your configuration is ready!"
