{ config, lib, ... }:

let
  extensions = config.boot.bootspec.extensions or { };
  namespace = "io.pullclone.dotclone.uki";
  allowedPrefixes = [
    "${namespace}."
    "org.nixos."
    "org.xenproject."
  ];
  allNames = builtins.attrNames extensions;
  isAllowed = name: lib.any (prefix: lib.hasPrefix prefix name) allowedPrefixes;
in
{
  assertions = [
    {
      assertion = lib.all isAllowed allNames;
      message = "Bootspec extensions must use the '${namespace}.' or 'org.nixos.' namespace.";
    }
  ];
}
