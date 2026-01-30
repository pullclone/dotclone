{ lib, ca }:
lib.mapAttrs (
  _name: bundle:
  {
    hostNames = map (pattern: "@cert-authority ${pattern}") bundle.patterns;
    publicKey = bundle.publicKey;
  }
  // lib.optionalAttrs (bundle.comment != null) { comment = bundle.comment; }
) ca.bundles
