use alloy::{primitives::U256, sol_types::SolValue};
use ark_bn254::{Bn254, Fr, G1Affine, G2Affine};
use ark_ec::{pairing::Pairing, AffineRepr, CurveGroup, Group};
use ark_std::{
    rand::{rngs::StdRng, SeedableRng},
    UniformRand,
};
use bn254_contract_adapter::{u256_to_field, G1Point, G2Point};
use clap::{Parser, ValueEnum};
use const_hex::ToHexExt;

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
    /// Compute the g1 points = generator ^ scalar.
    Bn254G1FromScalar,
    /// Test if a G1 Point is on curve
    Bn254G1IsOnCurve,
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
            let p: G2Point = p.into();
            println!("{}", G2Point::abi_encode(&p).encode_hex());
        }
        Action::Bn254G1FromScalar => {
            if cli.args.len() != 1 {
                panic!("Should provide arg1=scalar");
            }
            let s: Fr = u256_to_field(cli.args[0].parse::<U256>().unwrap());
            let res: G1Point = (G1Affine::generator() * s).into_affine().into();
            println!("{}", G1Point::abi_encode(&res).encode_hex());
        }
        Action::Bn254G1IsOnCurve => {
            if cli.args.len() != 1 {
                panic!("Should provide arg1=point");
            }
            let point: G1Affine =
                G1Point::abi_decode(&const_hex::decode(&cli.args[0]).unwrap(), true)
                    .unwrap()
                    .into();
            let is_on_curve = point.is_on_curve();
            println!("{}", is_on_curve.abi_encode().encode_hex());
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

            let parsed_a_1: G1Point = a_1.into_affine().into();
            let parsed_a_2: G2Point = a_2.into_affine().into();
            let parsed_b_1: G1Point = (-b_1).into_affine().into();
            let parsed_b_2: G2Point = b_2.into_affine().into();
            let res = (parsed_a_1, parsed_a_2, parsed_b_1, parsed_b_2);
            println!("{}", res.abi_encode().encode_hex());
        }
        Action::TestOnly => {
            eprintln!("test only");
        }
    }
}
