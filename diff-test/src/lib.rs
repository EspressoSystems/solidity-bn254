use std::str::FromStr;

use ark_ec::{
    short_weierstrass::{Affine, SWCurveConfig},
    AffineRepr,
};
use ark_ff::{BigInteger, Fp2, Fp2Config, PrimeField};
use ethers::{
    abi::AbiDecode,
    prelude::{AbiError, EthAbiCodec, EthAbiType},
    types::U256,
};

// TODO: (alex) maybe move these commonly shared util to a crate
/// convert a field element to U256, panic if field size is larger than 256 bit
pub fn field_to_u256<F: PrimeField>(f: F) -> U256 {
    if F::MODULUS_BIT_SIZE > 256 {
        panic!("Shouldn't convert a >256-bit field to U256");
    }
    U256::from_little_endian(&f.into_bigint().to_bytes_le())
}

/// convert U256 to a field (mod order)
pub fn u256_to_field<F: PrimeField>(x: U256) -> F {
    let mut bytes = [0u8; 32];
    x.to_little_endian(&mut bytes);
    F::from_le_bytes_mod_order(&bytes)
}

/// an intermediate representation of `BN254.G1Point` in solidity.
#[derive(Clone, PartialEq, Eq, Debug, EthAbiType, EthAbiCodec)]
pub struct ParsedG1Point {
    x: U256,
    y: U256,
}

// this is convention from BN256 precompile
impl Default for ParsedG1Point {
    fn default() -> Self {
        Self {
            x: U256::from(0),
            y: U256::from(0),
        }
    }
}

impl FromStr for ParsedG1Point {
    type Err = AbiError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let parsed: (Self,) = AbiDecode::decode_hex(s)?;
        Ok(parsed.0)
    }
}

impl<P: SWCurveConfig> From<Affine<P>> for ParsedG1Point
where
    P::BaseField: PrimeField,
{
    fn from(p: Affine<P>) -> Self {
        if p.is_zero() {
            // this convention is from the BN precompile
            Self {
                x: U256::from(0),
                y: U256::from(0),
            }
        } else {
            Self {
                x: field_to_u256::<P::BaseField>(*p.x().unwrap()),
                y: field_to_u256::<P::BaseField>(*p.y().unwrap()),
            }
        }
    }
}

impl<P: SWCurveConfig> From<ParsedG1Point> for Affine<P>
where
    P::BaseField: PrimeField,
{
    fn from(p: ParsedG1Point) -> Self {
        if p == ParsedG1Point::default() {
            Self::default()
        } else {
            Self::new(
                u256_to_field::<P::BaseField>(p.x),
                u256_to_field::<P::BaseField>(p.y),
            )
        }
    }
}

/// Intermediate representation of `G2Point` in Solidity
#[derive(Clone, PartialEq, Eq, Debug, EthAbiType, EthAbiCodec)]
pub struct ParsedG2Point {
    x0: U256,
    x1: U256,
    y0: U256,
    y1: U256,
}

impl FromStr for ParsedG2Point {
    type Err = AbiError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let parsed: (Self,) = AbiDecode::decode_hex(s)?;
        Ok(parsed.0)
    }
}

impl<P: SWCurveConfig<BaseField = Fp2<C>>, C> From<ParsedG2Point> for Affine<P>
where
    C: Fp2Config,
{
    fn from(p: ParsedG2Point) -> Self {
        Self::new(
            Fp2::new(u256_to_field(p.x0), u256_to_field(p.x1)),
            Fp2::new(u256_to_field(p.y0), u256_to_field(p.y1)),
        )
    }
}

impl<P: SWCurveConfig<BaseField = Fp2<C>>, C> From<Affine<P>> for ParsedG2Point
where
    C: Fp2Config,
{
    fn from(p: Affine<P>) -> Self {
        Self {
            x0: field_to_u256(p.x().unwrap().c0),
            x1: field_to_u256(p.x().unwrap().c1),
            y0: field_to_u256(p.y().unwrap().c0),
            y1: field_to_u256(p.y().unwrap().c1),
        }
    }
}
