{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, vulkan-loader
}:

stdenv.mkDerivation rec {
  pname = "latencyflex";
  version = "0.1.1";

  src = fetchurl {
    url = "https://github.com/ishitatsuyuki/LatencyFleX/releases/download/v${version}/latencyflex-v${version}.tar.xz";
    hash = "sha256-yZLr0vQ8matKhKb/zmktmq5MwlcVNqWFSuLnm2lR54o=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ vulkan-loader ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Preserve upstream /usr layout so latencyflex.json stays correct
    mkdir -p \
      $out/usr/lib/x86_64-linux-gnu \
      $out/usr/share/vulkan/implicit_layer.d

    cp -v layer/usr/lib/x86_64-linux-gnu/liblatencyflex_layer.so \
      $out/usr/lib/x86_64-linux-gnu/

    cp -v layer/usr/share/vulkan/implicit_layer.d/latencyflex.json \
      $out/usr/share/vulkan/implicit_layer.d/

    runHook postInstall
    
    test -f "$out/usr/lib/x86_64-linux-gnu/liblatencyflex_layer.so"
    test -f "$out/usr/share/vulkan/implicit_layer.d/latencyflex.json"
  '';

  meta = with lib; {
    description = "Vendor-agnostic latency reduction middleware (alternative to NVIDIA Reflex)";
    homepage = "https://github.com/ishitatsuyuki/LatencyFleX";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
