{ config, ... }:

{
  config = {
    programs.ssh = {
      enable = true;
      # Intentionally relying on OpenSSH defaults.
      # HM warning acknowledged; revisit only if defaults are removed upstream.
      enableDefaultConfig = true;
    };
  };
}
