#!/usr/bin/env bash

# NyxOS Optimization Testing & Validation Script
# This script tests all the optimizations we've implemented

echo "🔍 NyxOS Optimization Testing & Validation"
echo "=========================================="
echo ""

is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null || \
        grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

is_nixos() {
    [ -r /etc/os-release ] && grep -q "^ID=nixos$" /etc/os-release
}

has_systemd() {
    [ -d /run/systemd/system ]
}

if is_wsl; then
    echo "SKIP (WSL): runtime optimization checks require a real NixOS systemd runtime."
    exit 0
fi

if ! is_nixos; then
    echo "SKIP (non-NixOS): runtime optimization checks require a NixOS runtime."
    exit 0
fi

if ! has_systemd; then
    echo "SKIP (no systemd): runtime optimization checks require systemd."
    exit 0
fi

# Function to test a specific optimization
test_optimization() {
    local name="$1"
    local command="$2"
    local expected="$3"
    local description="$4"
    local result
    local status
    
    echo "Testing: $name"
    echo "Description: $description"
    echo "Command: $command"
    
    # Run the command
    result=$(eval "$command" 2>/dev/null)
    status=$?

    # Check if result matches expected
    if [[ -z "$expected" ]]; then
        if [[ $status -eq 0 && -n "$result" ]]; then
            echo "✅ PASS: $result"
        elif [[ $status -ne 0 ]]; then
            echo "❌ FAIL: Command failed (exit $status)"
        else
            echo "❌ FAIL: Expected command output but got empty result"
        fi
    elif [[ $status -eq 0 && "$result" == *"$expected"* ]]; then
        echo "✅ PASS: $result"
    elif [[ $status -ne 0 ]]; then
        echo "❌ FAIL: Command failed (exit $status)"
    else
        echo "❌ FAIL: Expected '$expected', got '$result'"
    fi
    echo ""
}

# Function to measure performance
measure_performance() {
    local name="$1"
    local command="$2"
    local description="$3"
    
    echo "Measuring: $name"
    echo "Description: $description"
    echo "Command: $command"
    
    # Run the command and measure time
    start_time=$(date +%s.%N)
    result=$(eval "$command" 2>/dev/null)
    end_time=$(date +%s.%N)
    
    runtime=$(echo "$end_time - $start_time" | bc)
    echo "⏱️  Runtime: ${runtime} seconds"
    echo "📊 Result: $result"
    echo ""
}

echo "🚀 Phase 1: System-Wide Optimizations Test"
echo "=========================================="

# Test boot optimizations
test_optimization "Parallel Startup" \
    "systemctl show --property=DefaultTimeoutStartSec" \
    "5s" \
    "Check if parallel startup with reduced timeouts is enabled"

test_optimization "Kernel Parameters" \
    "cat /proc/cmdline | grep -E '(nowatchdog|nmi_watchdog=0|tsc=reliable)'" \
    "" \
    "Check if performance kernel parameters are active"

# Test memory optimizations
test_optimization "Memory Swappiness" \
    "cat /proc/sys/vm/swappiness" \
    "10" \
    "Check if reduced swappiness is active"

test_optimization "Cache Pressure" \
    "cat /proc/sys/vm/vfs_cache_pressure" \
    "50" \
    "Check if optimized cache pressure is active"

# Test Btrfs optimizations
test_optimization "Btrfs Mount Options" \
    "mount | grep btrfs | grep -E '(noatime|nodiratime|compress=zstd)'" \
    "" \
    "Check if Btrfs is mounted with optimal options"

test_optimization "Btrfs Compression" \
    "btrfs filesystem usage / | grep -i compress" \
    "" \
    "Check if Btrfs compression is working"

# Test network optimizations
test_optimization "TCP Reuse" \
    "sysctl net.ipv4.tcp_tw_reuse" \
    "1" \
    "Check if TCP connection reuse is enabled"

test_optimization "Socket Limits" \
    "sysctl net.core.somaxconn" \
    "4096" \
    "Check if increased socket limits are active"

echo "🎯 Phase 2: Service-Specific Optimizations Test"
echo "=============================================="

# Test service optimizations
test_optimization "SDDM Service" \
    "systemctl is-active sddm" \
    "active" \
    "Check if SDDM display manager is running"

test_optimization "PipeWire Service" \
    "systemctl --user is-active pipewire" \
    "active" \
    "Check if PipeWire audio service is running"

test_optimization "Power Profiles" \
    "powerprofilesctl get" \
    "performance" \
    "Check if performance power profile is active"

test_optimization "NetworkManager" \
    "systemctl is-active NetworkManager" \
    "active" \
    "Check if NetworkManager is running"

echo "📊 Monitoring Services Test"
echo "=========================="

# Test monitoring services
test_optimization "Netdata Service" \
    "systemctl is-active netdata" \
    "active" \
    "Check if Netdata monitoring is running"

test_optimization "Prometheus Exporter" \
    "systemctl is-active prometheus-node-exporter" \
    "active" \
    "Check if Prometheus node exporter is running"

test_optimization "Netdata Port" \
    "ss -tlnp | grep 19999" \
    "" \
    "Check if Netdata is listening on port 19999"

test_optimization "Prometheus Port" \
    "ss -tlnp | grep 9100" \
    "" \
    "Check if Prometheus exporter is listening on port 9100"

echo "⚡ Performance Measurement"
echo "========================"

# Measure boot performance
measure_performance "Boot Analysis" \
    "systemd-analyze" \
    "Measure overall boot time"

measure_performance "Boot Blame" \
    "systemd-analyze blame | head -5" \
    "Identify slowest boot services"

measure_performance "Critical Chain" \
    "systemd-analyze critical-chain | head -10" \
    "Analyze critical boot path"

echo "💾 Disk Performance Test"
echo "========================"

# Test Btrfs performance
measure_performance "Btrfs Usage" \
    "btrfs filesystem usage /" \
    "Check Btrfs filesystem usage"

measure_performance "Btrfs DF" \
    "btrfs filesystem df /" \
    "Check Btrfs disk space"

echo "🔧 System Health Check"
echo "======================"

# Check system health
measure_performance "CPU Info" \
    "lscpu | grep 'Model name'" \
    "Check CPU information"

measure_performance "Memory Info" \
    "free -h | grep Mem" \
    "Check memory usage"

measure_performance "Disk Space" \
    "df -h / | tail -1" \
    "Check root filesystem space"

echo "🚀 Phase 3: Advanced Optimizations Test"
echo "======================================"

# Test Phase 3 optimizations
test_optimization "Transparent HugePages" \
    "sysctl vm.nr_hugepages" \
    "128" \
    "Check if Transparent HugePages are configured"

test_optimization "Memory Overcommit" \
    "sysctl vm.overcommit_memory" \
    "1" \
    "Check if memory overcommit is optimized"

test_optimization "BFQ I/O Scheduler" \
    "cat /sys/block/nvme0n1/queue/scheduler | grep bfq" \
    "" \
    "Check if BFQ I/O scheduler is active"

test_optimization "TCP BBR Congestion Control" \
    "sysctl net.ipv4.tcp_congestion_control" \
    "bbr" \
    "Check if TCP BBR congestion control is enabled"

test_optimization "Grafana Service" \
    "systemctl is-active grafana-server" \
    "active" \
    "Check if Grafana visualization service is running"

test_optimization "Grafana Port" \
    "ss -tlnp | grep 3000" \
    "" \
    "Check if Grafana is listening on port 3000"

test_optimization "Advanced Btrfs Options" \
    "mount | grep btrfs | grep -E '(zstd:3|thread_pool|autodefrag)'" \
    "" \
    "Check if advanced Btrfs options are active"

test_optimization "CPU Scheduler Tuning" \
    "sysctl kernel.sched_min_granularity_ns" \
    "10000000" \
    "Check if CPU scheduler is tuned for performance"

echo "📋 Optimization Summary"
echo "======================"
echo ""
echo "✅ Phase 1 Optimizations:"
echo "   - Boot & Kernel: Parallel startup, reduced timeouts"
echo "   - Memory: Optimized swappiness and cache pressure"
echo "   - Filesystem: Btrfs with zstd compression"
echo "   - Network: Optimized TCP/IP stack"
echo ""
echo "✅ Phase 2 Optimizations:"
echo "   - Services: SDDM, PipeWire, Power Management, NetworkManager"
echo "   - Monitoring: Netdata, Prometheus Node Exporter"
echo "   - Tools: Comprehensive monitoring suite"
echo ""
echo "🚀 Phase 3 Optimizations:"
echo "   - Advanced Memory: Transparent HugePages, overcommit tuning"
echo "   - I/O Scheduler: BFQ for better responsiveness"
echo "   - Network: TCP BBR congestion control"
echo "   - Filesystem: Advanced Btrfs options (zstd:3, autodefrag)"
echo "   - Monitoring: Grafana visualization with dashboards"
echo "   - Performance: CPU scheduler tuning, service optimization"
echo ""
echo "🎯 Next Steps:"
echo "   1. Review test results above"
echo "   2. Check for any FAIL indicators"
echo "   3. Access monitoring dashboards:"
echo "      - Netdata: http://localhost:19999"
echo "      - Prometheus: http://localhost:9100/metrics"
echo "      - Grafana: http://localhost:3000 (username: admin, password: admin)"
echo "   4. Monitor system performance over time"
echo "   5. Consider additional tuning based on usage patterns"
echo ""
echo "📊 Test completed at: $(date)"
echo ""
echo "For detailed troubleshooting, refer to the README documentation."
echo ""
echo "💡 Tip: Run this test periodically to monitor optimization effectiveness!"
