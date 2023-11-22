default:
    just --list

# Build diff-test binary and forge test
sol-test:
    cargo build --bin diff-test --release
    forge test
