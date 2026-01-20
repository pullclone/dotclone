{
  description = "NyxOS research template — standalone, opt-in experiment boilerplate";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/30a3c519afcf3f99e2c6df3b359aec5692054d92";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      pythonEnv = pkgs.python311.withPackages (ps: [
        ps.pip
        ps.setuptools
        ps.wheel
        ps.pyyaml
        ps.rich
      ]);
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          git
          just
          ripgrep
          shellcheck
          shfmt
          nixfmt-rfc-style
          statix
          deadnix
          pythonEnv
        ];
      };

      apps.${system}.run = {
        type = "app";
        program = "${
          pkgs.writeShellApplication {
            name = "run-exp";
            runtimeInputs = with pkgs; [
              bash
              coreutils
              findutils
              gnugrep
              gawk
              pythonEnv
            ];
            text = ''
              set -euo pipefail

              exec "${self}/scripts/run-exp.sh" "$@"
            '';
          }
        }/bin/run-exp";
        meta.description = "Run a named research experiment (see templates/research)";
      };
    };
}
