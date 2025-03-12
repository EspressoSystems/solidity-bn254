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

  inputs.foundry.url =
    "github:shazow/foundry.nix/monthly"; # Use monthly branch for permanent releases
  inputs.solc-bin.url = "github:EspressoSystems/nix-solc-bin";
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

  # support for shell.nix shim
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;

  outputs =
    { self
    , nixpkgs
    , rust-overlay
    , flake-utils
    , pre-commit-hooks
    , foundry
    , solc-bin
    , ...
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      overlays =
        [ (import rust-overlay) foundry.overlay solc-bin.overlays.default ];
      pkgs = import nixpkgs { inherit system overlays; };
      # Use a distinct target dir for builds from within nix shells.
      CARGO_TARGET_DIR = "target/nix";
      RUST_BACKTRACE = 1;
    in
    with pkgs; {
      checks = {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            cargo-fmt = {
              enable = true;
              description = "Enforce rustfmt";
              entry = "cargo fmt --all";
              types_or = [ "rust" "toml" ];
              pass_filenames = false;
            };
            cargo-sort = {
              enable = true;
              description = "Ensure Cargo.toml are sorted";
              entry = "cargo sort -g -w";
              types_or = [ "toml" ];
              pass_filenames = false;
            };
            cargo-clippy = {
              enable = true;
              description = "Run clippy";
              entry =
                "cargo clippy --workspace --all-features --all-targets -- -D warnings";
              types_or = [ "rust" "toml" ];
              pass_filenames = false;
            };
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
          stableToolchain = pkgs.rust-bin.stable.latest.minimal.override {
            extensions = [
              "rustfmt"
              "clippy"
              "llvm-tools-preview"
              "rust-src"
              "rust-analyzer"
            ];
          };
          nixWithFlakes = pkgs.writeShellScriptBin "nix" ''
            exec ${pkgs.nixVersions.stable}/bin/nix --experimental-features "nix-command flakes" "$@"
          '';
        in
        mkShell {
          buildInputs = [
            pkg-config
            coreutils
            stableToolchain

            # Rust tools
            cargo-audit
            cargo-edit
            cargo-sort
            just

            foundry-bin
            solc
            nixWithFlakes
            nixpkgs-fmt
          ] ++ lib.optionals stdenv.isDarwin
            [ darwin.apple_sdk.frameworks.SystemConfiguration ];
          shellHook = ''
            export CARGO_HOME=$HOME/.cargo-nix
            export PATH="$PWD/$CARGO_TARGET_DIR/release:$PATH"
          '' + self.checks.${system}.pre-commit-check.shellHook;
          FOUNDRY_SOLC = "${solc}/bin/solc";
          RUST_SRC_PATH = "${stableToolchain}/lib/rustlib/src/rust/library";
          inherit RUST_BACKTRACE CARGO_TARGET_DIR;
        };
    });
}
