{ config, lib, ... }:

let
  extensions = config.boot.bootspec.extensions or { };
  namespace = "io.pullclone.dotclone.uki";
  allNames = builtins.attrNames extensions;
in
{
  assertions = [
    {
      assertion =
        lib.all (name: lib.hasPrefix "${namespace}." name) allNames;
      message = "Bootspec extensions must use the '${namespace}.' namespace.";
    }
  ];
}
