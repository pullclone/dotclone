{ config, lib, pkgs, ... }:

{
  # ==========================================
  # KERNEL SYSCTL
  # ==========================================
  boot.kernel.sysctl = {
    # Memory Management
    "kernel.shmmni"                   = 4096;
    "vm.nr_hugepages"                 = 128;
    "vm.hugetlb_shm_group"            = 0;
    "vm.overcommit_memory"            = 1;
    "vm.overcommit_ratio"             = 50;
    "vm.zone_reclaim_mode"            = 0;
    # Base writeback defaults; profile modules may override.
    "vm.dirty_ratio"                  = lib.mkDefault 10;
    "vm.max_map_count"                = 262144;
    "vm.mmap_rnd_bits"                = 32;

    # Security
    "kernel.kptr_restrict"            = 2;
    "kernel.dmesg_restrict"           = 0;
    "kernel.perf_event_paranoid"      = 1;
    "kernel.yama.ptrace_scope"        = 1;
    "fs.protected_hardlinks"          = 1;
    "fs.protected_symlinks"           = 1;

    # Networking & Scheduler
    "kernel.sched_min_granularity_ns"     = 10000000;
    "kernel.sched_wakeup_granularity_ns"  = 15000000;
    "kernel.sched_latency_ns"             = 60000000;
    "net.core.default_qdisc"              = "fq";
    "net.ipv4.tcp_congestion_control"     = "bbr";
    "net.ipv4.tcp_notsent_lowat"          = 1;
    "net.ipv4.tcp_no_metrics_save"        = 1;
    "net.ipv4.tcp_keepalive_time"         = 300;
    "net.ipv4.tcp_keepalive_probes"       = 5;
    "net.ipv4.tcp_keepalive_intvl"        = 30;
    "net.ipv6.conf.all.disable_ipv6"      = 1;
  };

  # ==========================================
  # I/O SCHEDULER
  # ==========================================
  boot.extraModprobeConfig = ''
    options elevator=bfq
    options scsi_mod.use_blk_mq=1
    options nvme_core.io_timeout=30
    options nvme_core.max_retries=1
  '';

  # ==========================================
  # FILESYSTEM MAINTENANCE
  # ==========================================
  # TODO(batch1): Wire retention/enablement to install facts (snapshots.retention, trim policy).
  # One-shot service for manual or startup optimization
  systemd.services."btrfs-optimize" = {
    description = "Btrfs Optimization Service";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.btrfs-progs}/bin/btrfs filesystem defrag -r -v /";
    };
  };

  # Periodic maintenance
  environment.etc."btrfs-maintenance.xml".text = ''
    <?xml version="1.0"?>
    <config>
      <periodic>
        <balance enabled="true" interval="monthly" priority="nice">
          <filters>
            <usage>80</usage>
            <dusage>50</dusage>
          </filters>
        </balance>
        <scrub enabled="true" interval="weekly" priority="nice" />
        <trim enabled="true" interval="daily" priority="nice" />
        <defrag enabled="false" />
      </periodic>
      <syslog>warning</syslog>
    </config>
  '';
}
