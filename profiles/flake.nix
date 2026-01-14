{
  description = "NyxOS profile framework (system + zram)";

  outputs = _: {
    nyxProfiles = {
      # ZRAM modules (reusable)
      zram = {
        lz4 = import ./zram/lz4.nix;
        zstd-balanced = import ./zram/zstd-balanced.nix;
        zstd-aggressive = import ./zram/zstd-aggressive.nix;
        writeback = import ./zram/writeback.nix;
      };

      # System profiles (compose tunings)
      system = {
        latency = import ./system/latency.nix;
        balanced = import ./system/balanced.nix;
        throughput = import ./system/throughput.nix;
        battery = import ./system/battery.nix;
        memory-saver = import ./system/memory-saver.nix;
      };

      # Optional metadata (docs/help)
      meta.system = {
        latency.bestFor = [ "low-latency" "gaming" "interactive" ];
        latency.tradeoffs = [ "higher power" "possible throughput loss under sustained load" ];

        balanced.bestFor = [ "daily-driver" "mixed workloads" ];
        balanced.tradeoffs = [ "none" ];

        throughput.bestFor = [ "compiles" "rendering" "batch jobs" ];
        throughput.tradeoffs = [ "latency spikes" "higher memory pressure" ];

        battery.bestFor = [ "portable" "quiet" ];
        battery.tradeoffs = [ "lower peak performance" ];

        memory-saver.bestFor = [ "low-ram" "many apps" ];
        memory-saver.tradeoffs = [ "more CPU compression work" ];
      };
    };
  };
}
