{
  description = "Yazi plugin to dump all tabs to a shell-escaped file.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem = { pkgs, lib, ... }: {
        packages.default = pkgs.stdenvNoCC.mkDerivation {
          pname = "dump-tabs";
          version = "0.1.0";
          src = ./.;
          installPhase = ''
            runHook preInstall
            cp -r . $out
            runHook postInstall
          '';
          meta = {
            license = lib.licenses.mit;
            platform = lib.platforms.all;
            sourceProvenance = [ lib.sourceTypes.fromSource ];
          };
        };
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            lua5_2
            stylua
          ];
        };
      };
    };
}
