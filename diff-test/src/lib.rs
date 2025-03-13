use alloy::{primitives::U256, sol};
use ark_ec::{
    short_weierstrass::{Affine, SWCurveConfig},
    AffineRepr,
};
use ark_ff::{BigInteger, Fp2, Fp2Config, PrimeField};

// TODO: (alex) maybe move these commonly shared util to a crate
/// convert a field element to U256, panic if field size is larger than 256 bit
pub fn field_to_u256<F: PrimeField>(f: F) -> U256 {
    if F::MODULUS_BIT_SIZE > 256 {
        panic!("Shouldn't convert a >256-bit field to U256");
    }
    U256::from_le_slice(&f.into_bigint().to_bytes_le())
}

/// convert U256 to a field (mod order)
pub fn u256_to_field<F: PrimeField>(x: U256) -> F {
    let bytes: [u8; 32] = x.to_le_bytes();
    F::from_le_bytes_mod_order(&bytes)
}

// same as `forge bind --alloy`, only the struct related part
sol! {
    struct G1Point {
        uint256 x;
        uint256 y;
    }
    struct G2Point {
        uint256 x0;
        uint256 x1;
        uint256 y0;
        uint256 y1;
    }
}

// this is convention from BN256 precompile
impl Default for G1Point {
    fn default() -> Self {
        Self {
            x: U256::from(0),
            y: U256::from(0),
        }
    }
}
impl PartialEq for G1Point {
    fn eq(&self, other: &Self) -> bool {
        self.x == other.x && self.y == other.y
    }
}

impl<P: SWCurveConfig> From<Affine<P>> for G1Point
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

impl<P: SWCurveConfig> From<G1Point> for Affine<P>
where
    P::BaseField: PrimeField,
{
    fn from(p: G1Point) -> Self {
        if p == G1Point::default() {
            Self::default()
        } else {
            Self::new_unchecked(
                u256_to_field::<P::BaseField>(p.x),
                u256_to_field::<P::BaseField>(p.y),
            )
        }
    }
}

impl<P: SWCurveConfig<BaseField = Fp2<C>>, C> From<G2Point> for Affine<P>
where
    C: Fp2Config,
{
    fn from(p: G2Point) -> Self {
        Self::new_unchecked(
            Fp2::new(u256_to_field(p.x0), u256_to_field(p.x1)),
            Fp2::new(u256_to_field(p.y0), u256_to_field(p.y1)),
        )
    }
}

impl<P: SWCurveConfig<BaseField = Fp2<C>>, C> From<Affine<P>> for G2Point
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
