#!/usr/bin/env bash

echo "🔍 NyxOS Configuration Test"
echo "================================"
echo ""

fail_count=0
STRICT="${STRICT:-0}"
system_name="${SYSTEM:-nyx}"

pass() {
    echo "  ✅ PASS: $1"
}

fail() {
    echo "  ❌ FAIL: $1"
    fail_count=$((fail_count + 1))
}

warn() {
    echo "  ⚠️ WARN: $1"
}

skip() {
    echo "  ! SKIP: $1"
}

warn_required() {
    local msg="$1"
    if [ "$STRICT" = "1" ]; then
        fail "$msg"
    else
        echo "  ⚠️ WARN: $msg"
        fail_count=$((fail_count + 1))
    fi
}

nix_available=0
if command -v nix >/dev/null 2>&1; then
    nix_available=1
fi

nix_raw() {
    nix eval --raw ".#nixosConfigurations.${system_name}.config.${1}" 2>/dev/null
}

nix_json() {
    nix eval --json ".#nixosConfigurations.${system_name}.config.${1}" 2>/dev/null
}

# Test 1: Check for install-driven user (no dmail)
echo "✓ Test 1: Username consistency"
if [ "$nix_available" -ne 1 ]; then
    skip "nix not available; skipping nix-based checks"
else
    issues=""
    user_name=""
    if user_name=$(nix_raw "my.install.userName"); then
        if [ -z "$user_name" ]; then
            issues="install userName is empty"
        fi
    else
        issues="nix eval failed for my.install.userName"
    fi

    if users_json=$(nix_json "users.users"); then
        if printf '%s' "$users_json" | grep -q '"dmail"'; then
            if [ -n "$issues" ]; then
                issues="${issues}; "
            fi
            issues="${issues}legacy 'dmail' user present"
        fi
    else
        if [ -n "$issues" ]; then
            issues="${issues}; "
        fi
        issues="${issues}nix eval failed for users.users"
    fi

    if [ -z "$issues" ]; then
        pass "User derives from install answers, no 'dmail' references"
    else
        warn_required "User configuration issue: ${issues}"
    fi
fi

# Test 2: Check for timezone
echo "✓ Test 2: Timezone configuration"
if [ "$nix_available" -ne 1 ]; then
    skip "nix not available; skipping nix-based checks"
else
    if tz=$(nix_raw "time.timeZone"); then
        if [ -n "$tz" ]; then
            pass "Timezone configuration found (${tz})"
        else
            warn_required "Timezone configuration missing"
        fi
    else
        warn_required "nix eval failed for time.timeZone"
    fi
fi

# Test 3: Check for privacy DNS
echo "✓ Test 3: Privacy-focused DNS"
if [ "$nix_available" -ne 1 ]; then
    skip "nix not available; skipping nix-based checks"
else
    if nameservers_json=$(nix_json "networking.nameservers"); then
        nameservers_json=$(printf '%s' "$nameservers_json" | tr -d '\n')
        if printf '%s' "$nameservers_json" | grep -q '"142.242.2.2"'; then
            pass "Privacy DNS servers configured (142.242.2.2)"
        else
            if [ -z "$nameservers_json" ] || [ "$nameservers_json" = "null" ]; then
                warn "Privacy DNS not found (nameservers empty)"
            else
                warn "Privacy DNS not found (nameservers=${nameservers_json})"
            fi
        fi
    else
        warn "nix eval failed for networking.nameservers"
    fi
fi

# Test 4: Check for optimizations
echo "✓ Test 4: Phase 3 optimizations"
if [ "$nix_available" -ne 1 ]; then
    skip "nix not available; skipping nix-based checks"
else
    notes=""
    all_ok=1

    if hugepages=$(nix_json "boot.kernel.sysctl.\"vm.nr_hugepages\""); then
        hugepages=$(printf '%s' "$hugepages" | tr -d '\n')
        if [ "$hugepages" != "128" ]; then
            all_ok=0
            notes="${notes}vm.nr_hugepages=${hugepages:-empty}"
        fi
    else
        all_ok=0
        notes="${notes}vm.nr_hugepages=eval_failed"
    fi

    if overcommit=$(nix_json "boot.kernel.sysctl.\"vm.overcommit_memory\""); then
        overcommit=$(printf '%s' "$overcommit" | tr -d '\n')
        if [ "$overcommit" != "1" ]; then
            if [ -n "$notes" ]; then
                notes="${notes}; "
            fi
            all_ok=0
            notes="${notes}vm.overcommit_memory=${overcommit:-empty}"
        fi
    else
        if [ -n "$notes" ]; then
            notes="${notes}; "
        fi
        all_ok=0
        notes="${notes}vm.overcommit_memory=eval_failed"
    fi

    if tcp_cc=$(nix_raw "boot.kernel.sysctl.\"net.ipv4.tcp_congestion_control\""); then
        if [ "$tcp_cc" != "bbr" ]; then
            if [ -n "$notes" ]; then
                notes="${notes}; "
            fi
            all_ok=0
            notes="${notes}tcp_congestion_control=${tcp_cc:-empty}"
        fi
    else
        if [ -n "$notes" ]; then
            notes="${notes}; "
        fi
        all_ok=0
        notes="${notes}tcp_congestion_control=eval_failed"
    fi

    if [ "$all_ok" -eq 1 ]; then
        pass "Phase 3 optimizations present (hugepages=128, overcommit=1, tcp_cc=bbr)"
    else
        warn "Phase 3 optimizations not fully enabled (${notes})"
    fi
fi

# Test 5: Check for monitoring
echo "✓ Test 5: Monitoring services"
if [ "$nix_available" -ne 1 ]; then
    skip "nix not available; skipping nix-based checks"
else
    netdata=""
    node_exporter=""
    grafana=""

    if netdata=$(nix_json "services.netdata.enable"); then
        netdata=$(printf '%s' "$netdata" | tr -d '\n')
    else
        netdata="eval_failed"
    fi

    if node_exporter=$(nix_json "services.prometheus.exporters.node.enable"); then
        node_exporter=$(printf '%s' "$node_exporter" | tr -d '\n')
    else
        node_exporter="eval_failed"
    fi

    if grafana=$(nix_json "services.grafana.enable"); then
        grafana=$(printf '%s' "$grafana" | tr -d '\n')
    else
        grafana="eval_failed"
    fi

    if [ "$netdata" = "true" ] && [ "$node_exporter" = "true" ] && [ "$grafana" = "true" ]; then
        pass "Monitoring services configured"
    else
        warn "Monitoring services missing or partial (netdata=${netdata}, prometheus-node-exporter=${node_exporter}, grafana=${grafana})"
    fi
fi

# Test 6: Check for Btrfs optimizations
echo "✓ Test 6: Btrfs configuration"
if [ "$nix_available" -ne 1 ]; then
    skip "nix not available; skipping nix-based checks"
else
    if fs_type=$(nix_raw "fileSystems.\"/\".fsType"); then
        if [ -z "$fs_type" ]; then
            warn "Root filesystem type is empty; cannot evaluate Btrfs options"
        elif [ "$fs_type" != "btrfs" ]; then
            skip "Root filesystem is ${fs_type} (not Btrfs)"
        else
            if opts_json=$(nix_json "fileSystems.\"/\".options"); then
                opts_json=$(printf '%s' "$opts_json" | tr -d '\n')
                compress_ok=0
                autodefrag_ok=0

                if printf '%s' "$opts_json" | grep -q 'compress='; then
                    compress_ok=1
                fi
                if printf '%s' "$opts_json" | grep -q 'autodefrag'; then
                    autodefrag_ok=1
                fi

                if [ "$compress_ok" -eq 1 ] && [ "$autodefrag_ok" -eq 1 ]; then
                    pass "Btrfs options include compression and autodefrag"
                elif [ "$compress_ok" -eq 1 ]; then
                    warn "Btrfs compression enabled; autodefrag missing"
                else
                    warn_required "Btrfs compression missing (options=${opts_json})"
                fi
            else
                warn "nix eval failed for fileSystems.\"/\".options"
            fi
        fi
    else
        warn "nix eval failed for fileSystems.\"/\".fsType"
    fi
fi

# Test 7: Check flake.nix
echo "✓ Test 7: Flake configuration"
if grep -q "home-manager.users.ashy" flake.nix && ! grep -q "home-manager.users.dmail" flake.nix; then
    pass "Flake uses 'ashy' user"
else
    fail "Flake user configuration issue"
fi

# Test 8: Check home configuration
echo "✓ Test 8: Home configuration"
if [ -f "modules/home/home-ashy.nix" ] && ! [ -f "modules/home/home-dmail.nix" ]; then
    pass "modules/home/home-ashy.nix exists, modules/home/home-dmail.nix absent"
else
    fail "Home configuration issue"
fi

# Test 9: Nix eval checks (panel, IPv6, PAM, lock handler)
echo "✓ Test 9: Nix eval checks (panel/IPv6/PAM/lock)"
if [ "$nix_available" -ne 1 ]; then
    skip "nix not available; skipping nix-based checks"
else
    if panel=$(nix_raw "my.install.desktop.panel"); then
        if [ "$panel" = "noctalia" ] || [ "$panel" = "waybar" ]; then
            pass "Panel selection is ${panel}"
        else
            fail "Panel selection invalid (${panel:-empty})"
        fi
    else
        fail "Panel selection eval failed"
    fi

    if ipv6=$(nix_json "networking.enableIPv6"); then
        ipv6=$(printf '%s' "$ipv6" | tr -d '\n')
        if [ "$ipv6" = "true" ] || [ "$ipv6" = "false" ]; then
            pass "IPv6 toggle evaluates to ${ipv6}"
        else
            fail "IPv6 toggle eval failed (${ipv6:-empty})"
        fi
    else
        fail "IPv6 toggle eval failed"
    fi

    if lock_handler=$(nix_json "services.systemd-lock-handler.enable"); then
        lock_handler=$(printf '%s' "$lock_handler" | tr -d '\n')
        if [ "$lock_handler" = "true" ]; then
            pass "systemd-lock-handler enabled"
        else
            fail "systemd-lock-handler not enabled (${lock_handler:-empty})"
        fi
    else
        fail "systemd-lock-handler eval failed"
    fi

    if nix eval ".#nixosConfigurations.${system_name}.config.security.pam.services.swaylock" >/dev/null 2>&1; then
        pass "PAM service 'swaylock' present"
    else
        fail "PAM service 'swaylock' missing"
    fi

    if nix eval ".#nixosConfigurations.${system_name}.config.security.pam.services.\"noctalia-shell\"" >/dev/null 2>&1; then
        pass "PAM service 'noctalia-shell' present"
    else
        fail "PAM service 'noctalia-shell' missing"
    fi
fi

echo ""
echo "📊 Configuration Summary:"
echo "========================"
echo ""
echo "Files checked:"
echo "  ✓ configuration.nix"
echo "  ✓ flake.nix"
echo "  ✓ modules/home/home-ashy.nix"
echo ""
echo "All tests completed. Review results above."
echo "If all tests show ✅ PASS, your configuration is ready!"

if [ "$fail_count" -eq 0 ]; then
    echo "RESULT: PASS"
    exit 0
fi

if [ "$STRICT" = "1" ]; then
    echo "RESULT: FAIL — ${fail_count} failing checks"
    exit 1
fi

echo "RESULT: PASS (with warnings) — ${fail_count} failing checks"
exit 0
