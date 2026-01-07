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

    mkdir -p $out/lib $out/share/vulkan/implicit_layer.d $out/wine/lib $out/wine/lib64

    install -Dm755 layer/liblatencyflex_layer.so $out/lib/liblatencyflex_layer.so
    install -Dm644 layer/latencyflex.json $out/share/vulkan/implicit_layer.d/latencyflex.json

    substituteInPlace $out/share/vulkan/implicit_layer.d/latencyflex.json \
      --replace-fail "./liblatencyflex_layer.so" "$out/lib/liblatencyflex_layer.so"

    if [ -d wine ]; then
      install -Dm755 wine/x86_64-unix/latencyflex_layer.so \
        $out/wine/lib64/wine/x86_64-unix/latencyflex_layer.so
      install -Dm755 wine/x86_64-windows/latencyflex_layer.dll \
        $out/wine/lib64/wine/x86_64-windows/latencyflex_layer.dll
      install -Dm755 wine/x86_64-windows/latencyflex_wine.dll \
        $out/wine/lib64/wine/x86_64-windows/latencyflex_wine.dll
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "Vendor-agnostic latency reduction middleware (alternative to NVIDIA Reflex)";
    homepage = "https://github.com/ishitatsuyuki/LatencyFleX";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
