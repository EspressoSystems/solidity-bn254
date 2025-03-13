default:
    just --list

# Build diff-test binary and forge test
sol-test:
    cargo build --bin diff-test-bn254 --release
    forge test

# Generate alloy bindings
bind:
    forge bind --alloy --alloy-version "0.12.5" --crate-name contract-bindings --force --overwrite
