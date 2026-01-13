# NixOS/overlays/latencyflex.nix
final: prev: {
  latencyflex = final.callPackage ../pkgs/latencyflex.nix { };
}
