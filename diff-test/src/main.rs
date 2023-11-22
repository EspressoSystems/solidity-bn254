use ark_ec::AffineRepr;
use clap::{Parser, ValueEnum};
use ethers::abi::AbiEncode;

use diff_test::ParsedG2Point;

#[derive(Parser)]
#[command(author, version, about, long_about=None)]
struct Cli {
    /// Identifier for the functions to invoke in Jellyfish
    #[arg(value_enum)]
    action: Action,
    /// Optional arguments for the `action`
    #[arg(value_parser, num_args = 1.., value_delimiter = ' ')]
    args: Vec<String>,
}

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ValueEnum)]
enum Action {
    /// Get BN254's G2 generator in arkworks
    Bn254G2Gen,
    /// Test only logic
    TestOnly,
}

fn main() {
    let cli = Cli::parse();
    match cli.action {
        Action::Bn254G2Gen => {
            let p = ark_bn254::G2Affine::generator();
            let parsed_p: ParsedG2Point = p.into();
            println!("{}", (parsed_p,).encode_hex());
        }
        Action::TestOnly => {
            eprintln!("test only");
        }
    }
}
