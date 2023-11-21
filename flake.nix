{
  description = "Espresso BN254 library";

  nixConfig = {
    extra-substituters = [
      "https://espresso-systems-private.cachix.org"
      "https://nixpkgs-cross-overlay.cachix.org"
    ];
    extra-trusted-public-keys = [
      "espresso-systems-private.cachix.org-1:LHYk03zKQCeZ4dvg3NctyCq88e44oBZVug5LpYKjPRI="
      "nixpkgs-cross-overlay.cachix.org-1:TjKExGN4ys960TlsGqNOI/NBdoz2Jdr2ow1VybWV5JM="
    ];
  };

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.foundry.url = "github:shazow/foundry.nix"; # Use monthly branch for permanent releases
  inputs.solc-bin.url = "github:EspressoSystems/nix-solc-bin";
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , pre-commit-hooks
    , foundry
    , solc-bin
    , ...
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      overlays = [
        foundry.overlay
        solc-bin.overlays.default
      ];
      pkgs = import nixpkgs {
        inherit system overlays;
      };
    in
    with pkgs;
    {
      checks = {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            forge-fmt = {
              enable = true;
              description = "Enforce forge fmt";
              entry = "forge fmt";
              types_or = [ "solidity" ];
              pass_filenames = false;
            };
            nixpkgs-fmt.enable = true;
          };
        };
      };
      devShells.default =
        let
          solc = pkgs.solc-bin.latest;
          nixWithFlakes = pkgs.writeShellScriptBin "nix" ''
            exec ${pkgs.nixFlakes}/bin/nix --experimental-features "nix-command flakes" "$@"
          '';
        in
        mkShell
          {
            buildInputs = [
              pkg-config
              coreutils

              foundry-bin
              solc
              nixWithFlakes
              nixpkgs-fmt
            ] ++ lib.optionals stdenv.isDarwin [ darwin.apple_sdk.frameworks.SystemConfiguration ];
            shellHook = ''
              # Add shell hook here
            '' + self.checks.${system}.pre-commit-check.shellHook;
            FOUNDRY_SOLC = "${solc}/bin/solc";
          };
    }
    );
}
