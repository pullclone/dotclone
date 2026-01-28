{ config, ... }:

{
  config = {
    programs.ssh = {
      enable = true;
      # Explicitly disable upstream defaults; policy comes from my.ssh templates.
      enableDefaultConfig = false;
    };
  };
}
