default:
    just --list

# Build diff-test binary and forge test
sol-test:
    cargo build --bin diff-test-bn254 --release
    forge test
