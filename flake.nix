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
  inputs.rust-overlay.url = "github:oxalica/rust-overlay";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.foundry.url = "github:shazow/foundry.nix"; # Use monthly branch for permanent releases
  inputs.solc-bin.url = "github:EspressoSystems/nix-solc-bin";

  outputs =
    { self
    , nixpkgs
    , rust-overlay
    , flake-utils
    , foundry
    , solc-bin
    , ...
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      overlays = [
        (import rust-overlay)
        foundry.overlay
        solc-bin.overlays.default
      ];
      pkgs = import nixpkgs {
        inherit system overlays;
      };
    in
    with pkgs;
    {
      devShells.default =
        let
          stableToolchain = pkgs.rust-bin.stable.latest.minimal.override {
            extensions = [ "rustfmt" "clippy" "llvm-tools-preview" "rust-src" ];
          };
          solc = pkgs.solc-bin.latest;
        in
        mkShell
          {
            buildInputs = [
              # Rust dependencies
              pkgconfig
              stableToolchain
              coreutils

              foundry-bin
              solc
            ] ++ lib.optionals stdenv.isDarwin [ darwin.apple_sdk.frameworks.SystemConfiguration ];
            shellHook = ''
              # Prevent cargo aliases from using programs in `~/.cargo` to avoid conflicts
              # with rustup installations.
              export CARGO_HOME=$HOME/.cargo-nix
            '';
            FOUNDRY_SOLC = "${solc}/bin/solc";
          };
    }
    );
}
