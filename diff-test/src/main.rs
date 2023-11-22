use ark_bn254::{Bn254, Fr, G1Affine, G2Affine};
use ark_ec::{pairing::Pairing, AffineRepr, CurveGroup, Group};
use ark_std::{
    rand::{rngs::StdRng, SeedableRng},
    UniformRand,
};
use clap::{Parser, ValueEnum};
use ethers::abi::AbiEncode;

use diff_test::{ParsedG1Point, ParsedG2Point};

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
    /// Generate two pairs of (G1, G2) to test pairingProd2
    Bn254PairingProd2,
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
        Action::Bn254PairingProd2 => {
            if cli.args.len() != 1 {
                panic!("Should provide arg1=seed");
            }

            let seed = cli.args[0].parse::<u64>().unwrap();
            let mut rng = StdRng::seed_from_u64(seed);

            // testing e(a1, a2) =?= e(b1, b2) where
            // a1 = g^\alpha_l, a2 = h^\beta_l
            // b1 = g^\alpha_r, b2 = h^\beta_r
            let alpha_l = Fr::rand(&mut rng);
            let beta_l = Fr::rand(&mut rng);
            let alpha_r = Fr::rand(&mut rng);
            let beta_r = alpha_l * beta_l / alpha_r;

            let a_1 = G1Affine::generator() * alpha_l;
            let a_2 = G2Affine::generator() * beta_l;
            let b_1 = G1Affine::generator() * alpha_r;
            let mut b_2 = G2Affine::generator() * beta_r;

            assert_eq!(Bn254::pairing(a_1, a_2), Bn254::pairing(b_1, b_2));
            if seed % 2 == 0 {
                b_2 = b_2.double();
                assert_ne!(Bn254::pairing(a_1, a_2), Bn254::pairing(b_1, b_2));
            }

            let parsed_a_1: ParsedG1Point = a_1.into_affine().into();
            let parsed_a_2: ParsedG2Point = a_2.into_affine().into();
            let parsed_b_1: ParsedG1Point = (-b_1).into_affine().into();
            let parsed_b_2: ParsedG2Point = b_2.into_affine().into();
            let res = (parsed_a_1, parsed_a_2, parsed_b_1, parsed_b_2);
            println!("{}", res.encode_hex());
        }
        Action::TestOnly => {
            eprintln!("test only");
        }
    }
}
