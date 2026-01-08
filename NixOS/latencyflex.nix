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

  # Make it explicit (matches tar layout)
  sourceRoot = "latencyflex-v${version}";

  nativeBuildInputs = [ autoPatchelfHook ];

  # Key fix: satisfy libstdc++ / libgcc_s for autoPatchelf
  buildInputs = [
    vulkan-loader
    stdenv.cc.cc.lib
  ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p \
      "$out/lib" \
      "$out/share/vulkan/implicit_layer.d"

    cp -v layer/usr/lib/x86_64-linux-gnu/liblatencyflex_layer.so \
      "$out/lib/"

    cp -v layer/usr/share/vulkan/implicit_layer.d/latencyflex.json \
      "$out/share/vulkan/implicit_layer.d/"

    # Patch manifest to reference the Nix-installed location
    substituteInPlace "$out/share/vulkan/implicit_layer.d/latencyflex.json" \
      --replace "/usr/lib/x86_64-linux-gnu/liblatencyflex_layer.so" "$out/lib/liblatencyflex_layer.so"

    runHook postInstall

    test -f "$out/lib/liblatencyflex_layer.so"
    test -f "$out/share/vulkan/implicit_layer.d/latencyflex.json"
  '';

  meta = with lib; {
    description = "Vendor-agnostic latency reduction middleware (alternative to NVIDIA Reflex)";
    homepage = "https://github.com/ishitatsuyuki/LatencyFleX";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
