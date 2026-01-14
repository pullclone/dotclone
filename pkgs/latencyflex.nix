# pkgs/latencyflex.nix
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  file,
  vulkan-loader,
}:

stdenv.mkDerivation rec {
  pname = "latencyflex";
  version = "0.1.1";

  src = fetchurl {
    url = "https://github.com/ishitatsuyuki/LatencyFleX/releases/download/v${version}/latencyflex-v${version}.tar.xz";
    hash = "sha256-yZLr0vQ8matKhKb/zmktmq5MwlcVNqWFSuLnm2lR54o=";
  };

  sourceRoot = "latencyflex-v${version}";

  nativeBuildInputs = [
    autoPatchelfHook
    file
  ];

  buildInputs = [
    vulkan-loader
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  preInstall = ''
    test -f "layer/usr/lib/x86_64-linux-gnu/liblatencyflex_layer.so"
    test -f "layer/usr/share/vulkan/implicit_layer.d/latencyflex.json"
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib" "$out/share/vulkan/implicit_layer.d"

    cp -v layer/usr/lib/x86_64-linux-gnu/liblatencyflex_layer.so "$out/lib/"
    cp -v layer/usr/share/vulkan/implicit_layer.d/latencyflex.json \
      "$out/share/vulkan/implicit_layer.d/"

    substituteInPlace "$out/share/vulkan/implicit_layer.d/latencyflex.json" \
      --replace "/usr/lib/x86_64-linux-gnu/liblatencyflex_layer.so" \
                "$out/lib/liblatencyflex_layer.so"

    runHook postInstall

    test -f "$out/lib/liblatencyflex_layer.so"
    test -f "$out/share/vulkan/implicit_layer.d/latencyflex.json"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    test -s "$out/lib/liblatencyflex_layer.so"
    test -s "$out/share/vulkan/implicit_layer.d/latencyflex.json"
    file "$out/lib/liblatencyflex_layer.so"
  '';

  meta = with lib; {
    description = "Vendor-agnostic latency reduction middleware (alternative to NVIDIA Reflex)";
    homepage = "https://github.com/ishitatsuyuki/LatencyFleX";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
