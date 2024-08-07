// SPDX-License-Identifier: GPL-3.0-or-later
//
// Copyright (c) 2022 Espresso Systems (espressosys.com)
// This file is part of the solidity-bn254 library.
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

//
// Based on:
// - Christian Reitwiessner: https://gist.githubusercontent.com/chriseth/f9be9d9391efc5beb9704255a8e2989d/raw/4d0fb90847df1d4e04d507019031888df8372239/snarktest.solidity
// - Aztec: https://github.com/AztecProtocol/aztec-2-bug-bounty

pragma solidity ^0.8.0;

import { Utils } from "./Utils.sol";

/// @notice Barreto-Naehrig curve over a 254 bit prime field
library BN254 {
    /// @notice type alias for BN254::ScalarField
    type ScalarField is uint256;
    /// @notice type alias for BN254::BaseField
    type BaseField is uint256;

    // use notation from https://datatracker.ietf.org/doc/draft-irtf-cfrg-pairing-friendly-curves/
    //
    // Elliptic curve is defined over a prime field GF(p), with embedding degree k.
    // Short Weierstrass (SW form) is, for a, b \in GF(p^n) for some natural number n > 0:
    //   E: y^2 = x^3 + a * x + b
    //
    // Pairing is defined over cyclic subgroups G1, G2, both of which are of order r.
    // G1 is a subgroup of E(GF(p)), G2 is a subgroup of E(GF(p^k)).
    //
    // BN family are parameterized curves with well-chosen t,
    //   p = 36 * t^4 + 36 * t^3 + 24 * t^2 + 6 * t + 1
    //   r = 36 * t^4 + 36 * t^3 + 18 * t^2 + 6 * t + 1
    // for some integer t.
    // E has the equation:
    //   E: y^2 = x^3 + b
    // where b is a primitive element of multiplicative group (GF(p))^* of order (p-1).
    // A pairing e is defined by taking G1 as a subgroup of E(GF(p)) of order r,
    // G2 as a subgroup of E'(GF(p^2)),
    // and G_T as a subgroup of a multiplicative group (GF(p^12))^* of order r.
    //
    // BN254 is defined over a 254-bit prime order p, embedding degree k = 12.
    uint256 public constant P_MOD =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;
    uint256 public constant R_MOD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    struct G1Point {
        BaseField x;
        BaseField y;
    }

    // G2 group element where x \in Fp2 = c0 + c1 * X
    struct G2Point {
        BaseField x0;
        BaseField x1;
        BaseField y0;
        BaseField y1;
    }

    /// @return the generator of G1
    // solhint-disable-next-line func-name-mixedcase
    function P1() internal pure returns (G1Point memory) {
        return G1Point(BaseField.wrap(1), BaseField.wrap(2));
    }

    /// @return the generator of G2
    // solhint-disable-next-line func-name-mixedcase
    function P2() internal pure returns (G2Point memory) {
        return G2Point({
            x0: BaseField.wrap(0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed),
            x1: BaseField.wrap(0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2),
            y0: BaseField.wrap(0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa),
            y1: BaseField.wrap(0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b)
        });
    }

    /// @notice the neutral/infinity point of G1
    function infinity() internal pure returns (G1Point memory) {
        return G1Point(BaseField.wrap(0), BaseField.wrap(0));
    }

    /// @dev check if a G1 point is Infinity
    /// @notice precompile bn256Add at address(6) takes (0, 0) as Point of Infinity,
    /// some crypto libraries (such as arkwork) uses a boolean flag to mark PoI, and
    /// just use (0, 1) as affine coordinates (not on curve) to represents PoI.
    function isInfinity(G1Point memory point) internal pure returns (bool result) {
        assembly {
            let x := mload(point)
            let y := mload(add(point, 0x20))
            result := and(iszero(x), iszero(y))
        }
    }

    /// @dev assume input G1Point is canonical
    /// @return r the negation of p, i.e. p.add(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory) {
        if (isInfinity(p)) {
            return p;
        }
        return G1Point(p.x, negate(p.y));
    }

    /// @dev assume input ScalarField is canonical
    /// @return res = -fr the negation of scalar field element.
    function negate(ScalarField fr) internal pure returns (ScalarField res) {
        return ScalarField.wrap(R_MOD - ScalarField.unwrap(fr));
    }

    /// @dev assume input BaseField is canonical
    /// @notice res = -fq for base field
    function negate(BaseField fq) internal pure returns (BaseField) {
        return BaseField.wrap(P_MOD - BaseField.unwrap(fq));
    }

    /// @return r the sum of two points of G1
    function add(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint256[4] memory input;
        input[0] = BaseField.unwrap(p1.x);
        input[1] = BaseField.unwrap(p1.y);
        input[2] = BaseField.unwrap(p2.x);
        input[3] = BaseField.unwrap(p2.y);
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
        }
        require(success, "Bn254: group addition failed!");
    }

    /// @notice add for BaseField
    function add(BaseField a, BaseField b) internal pure returns (BaseField) {
        return BaseField.wrap(addmod(BaseField.unwrap(a), BaseField.unwrap(b), P_MOD));
    }

    /// @notice add for ScalarField
    function add(ScalarField a, ScalarField b) internal pure returns (ScalarField) {
        return ScalarField.wrap(addmod(ScalarField.unwrap(a), ScalarField.unwrap(b), R_MOD));
    }

    /// @notice mul for BaseField
    function mul(BaseField a, BaseField b) internal pure returns (BaseField) {
        return BaseField.wrap(mulmod(BaseField.unwrap(a), BaseField.unwrap(b), P_MOD));
    }

    /// @notice mul for ScalarField
    function mul(ScalarField a, ScalarField b) internal pure returns (ScalarField) {
        return ScalarField.wrap(mulmod(ScalarField.unwrap(a), ScalarField.unwrap(b), R_MOD));
    }

    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.mul(1) and p.add(p) == p.mul(2) for all points p.
    function scalarMul(G1Point memory p, ScalarField s) internal view returns (G1Point memory r) {
        uint256[3] memory input;
        input[0] = BaseField.unwrap(p.x);
        input[1] = BaseField.unwrap(p.y);
        input[2] = ScalarField.unwrap(s);
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
        }
        require(success, "Bn254: scalar mul failed!");
    }

    /// @dev Multi-scalar Mulitiplication (MSM)
    /// @return r = \Prod{B_i^s_i} where {s_i} are `scalars` and {B_i} are `bases`
    function multiScalarMul(G1Point[] memory bases, ScalarField[] memory scalars)
        internal
        view
        returns (G1Point memory r)
    {
        require(scalars.length == bases.length, "MSM err: length does not match");
        require(bases.length > 0, "MSM err: empty bases/scalars");

        r = scalarMul(bases[0], scalars[0]);
        for (uint256 i = 1; i < scalars.length; i++) {
            r = add(r, scalarMul(bases[i], scalars[i]));
        }
    }

    /// @dev Compute f^-1 for f \in Fr scalar field
    /// @notice credit: Aztec, Spilsbury Holdings Ltd
    function invert(ScalarField fr) internal view returns (ScalarField output) {
        require((ScalarField.unwrap(fr) != 0), "Bn254: cannot compute the inverse of 0");
        bool success;
        uint256 p = R_MOD;
        assembly {
            let mPtr := mload(0x40)
            mstore(mPtr, 0x20)
            mstore(add(mPtr, 0x20), 0x20)
            mstore(add(mPtr, 0x40), 0x20)
            mstore(add(mPtr, 0x60), fr)
            mstore(add(mPtr, 0x80), sub(p, 2))
            mstore(add(mPtr, 0xa0), p)
            success := staticcall(gas(), 0x05, mPtr, 0xc0, 0x00, 0x20)
            output := mload(0x00)
        }
        require(success, "Bn254: pow precompile failed!");
    }

    /**
     * validate the following:
     *   x < p
     *   y < p
     *   y^2 = x^3 + 3 mod p or Point-of-Infinity
     */
    /// @dev validate G1 point and check if it is on curve
    /// @notice credit: Aztec, Spilsbury Holdings Ltd
    function validateG1Point(G1Point memory point) internal pure {
        bool isWellFormed;
        uint256 p = P_MOD;
        if (isInfinity(point)) {
            return;
        }
        assembly {
            let x := mload(point)
            let y := mload(add(point, 0x20))

            isWellFormed :=
                and(
                    and(lt(x, p), lt(y, p)),
                    eq(mulmod(y, y, p), addmod(mulmod(x, mulmod(x, x, p), p), 3, p))
                )
        }
        require(isWellFormed, "Bn254: invalid G1 point");
    }

    /// @dev Validate scalar field, revert if invalid (namely if fr > r_mod).
    /// @notice Writing this inline instead of calling it might save gas.
    function validateScalarField(ScalarField fr) internal pure {
        bool isValid;
        assembly {
            isValid := lt(fr, R_MOD)
        }
        require(isValid, "Bn254: invalid scalar field");
    }

    /// @dev Evaluate the following pairing product:
    /// @dev e(a1, a2).e(b1, b2) == 1
    /// @dev equality holds for e(a1, a2) == e(-b1, b2) (NOTE: input `b1`=-b1)
    /// @dev caller needs to ensure that a1, a2, b1 and b2 are within proper group
    /// @dev Modified from original credit: Aztec, Spilsbury Holdings Ltd
    function pairingProd2(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2
    ) internal view returns (bool) {
        uint256 out;
        bool success;
        assembly {
            let mPtr := mload(0x40)
            mstore(mPtr, mload(a1))
            mstore(add(mPtr, 0x20), mload(add(a1, 0x20)))
            mstore(add(mPtr, 0x40), mload(add(a2, 0x20)))
            mstore(add(mPtr, 0x60), mload(a2))
            mstore(add(mPtr, 0x80), mload(add(a2, 0x60)))
            mstore(add(mPtr, 0xa0), mload(add(a2, 0x40)))

            mstore(add(mPtr, 0xc0), mload(b1))
            mstore(add(mPtr, 0xe0), mload(add(b1, 0x20)))
            mstore(add(mPtr, 0x100), mload(add(b2, 0x20)))
            mstore(add(mPtr, 0x120), mload(b2))
            mstore(add(mPtr, 0x140), mload(add(b2, 0x60)))
            mstore(add(mPtr, 0x160), mload(add(b2, 0x40)))
            success := staticcall(gas(), 8, mPtr, 0x180, 0x00, 0x20)
            out := mload(0x00)
        }
        require(success, "Bn254: Pairing check failed!");
        return (out != 0);
    }

    function fromLeBytesModOrder(bytes memory leBytes) internal pure returns (uint256 ret) {
        for (uint256 i = 0; i < leBytes.length; i++) {
            ret = mulmod(ret, 256, R_MOD);
            ret = addmod(ret, uint256(uint8(leBytes[leBytes.length - 1 - i])), R_MOD);
        }
    }

    /// @dev Check if y-coordinate of G1 point is negative.
    function isYNegative(G1Point memory point) internal pure returns (bool) {
        return (BaseField.unwrap(point.y) << 1) < P_MOD;
    }

    // @dev Perform a modular exponentiation.
    // @return base^exponent (mod modulus)
    // This method is ideal for small exponents (~64 bits or less), as it is cheaper than using the pow precompile
    // @notice credit: credit: Aztec, Spilsbury Holdings Ltd
    function powSmall(uint256 base, uint256 exponent, uint256 modulus)
        internal
        pure
        returns (uint256)
    {
        uint256 result = 1;
        uint256 input = base;
        uint256 count = 1;

        assembly {
            let endpoint := add(exponent, 0x01)
            for { } lt(count, endpoint) { count := add(count, count) } {
                if and(exponent, count) { result := mulmod(result, input, modulus) }
                input := mulmod(input, input, modulus)
            }
        }

        return result;
    }

    // TODO: remove endian conversion in <https://github.com/EspressoSystems/espresso-sequencer/issues/1739>
    function g1Serialize(G1Point memory point) internal pure returns (bytes memory) {
        uint256 mask = 0;

        // Set the 254-th bit to 1 for infinity
        // https://docs.rs/ark-serialize/0.3.0/src/ark_serialize/flags.rs.html#117
        if (isInfinity(point)) {
            return bytes("0x4000000000000000000000000000000000000000000000000000000000000000");
        }

        // Set the 255-th bit to 1 for positive Y
        // https://docs.rs/ark-serialize/0.3.0/src/ark_serialize/flags.rs.html#118
        if (!isYNegative(point)) {
            mask = 0x8000000000000000000000000000000000000000000000000000000000000000;
        }

        return abi.encodePacked(Utils.reverseEndianness(BaseField.unwrap(point.x) | mask));
    }

    /// @dev for big endian u256 input, the first two leading bits (255-th and 254-th)
    /// 00: negativeY; 10: positiveY; 01/11: infinity
    /// for the remaining 254-bit value, canonical representation refers to the smallest
    /// non-negative integer for every field element.
    function g1Deserialize(bytes32 input) internal view returns (G1Point memory point) {
        uint256 mask = 0x4000000000000000000000000000000000000000000000000000000000000000;
        // TODO: remove endian conversion in <https://github.com/EspressoSystems/espresso-sequencer/issues/1739>
        uint256 xVal = Utils.reverseEndianness(uint256(input));
        bool isQuadraticResidue;
        bool isYPositive;
        if (xVal & mask != 0) {
            // the 254-th bit == 1 for infinity
            point = infinity();
        } else {
            // Set the 255-th bit to 1 for positive Y
            mask = 0x8000000000000000000000000000000000000000000000000000000000000000;
            isYPositive = (xVal & mask != 0);
            // mask off the first two bits of x
            mask = 0x3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
            xVal &= mask;

            require(xVal < P_MOD, "deser fail: non-canonical repr");

            // solve for y where E: y^2 = x^3 + 3
            BaseField x = BaseField.wrap(xVal);
            BaseField y = add(mul(mul(x, x), x), BaseField.wrap(3));
            (isQuadraticResidue, y) = quadraticResidue(y);

            require(isQuadraticResidue, "deser fail: not on curve");

            if (isYPositive) {
                y = negate(y);
            }
            point = G1Point(x, y);
        }
    }

    function quadraticResidue(BaseField x)
        internal
        view
        returns (bool isQuadraticResidue, BaseField)
    {
        bool success;
        uint256 a;
        // e = (p+1)/4
        uint256 e = 0xc19139cb84c680a6e14116da060561765e05aa45a1c72a34f082305b61f3f52;
        uint256 p = P_MOD;

        // we have p == 3 mod 4 therefore
        // a = x^((p+1)/4)
        assembly {
            // credit: Aztec
            let mPtr := mload(0x40)
            mstore(mPtr, 0x20)
            mstore(add(mPtr, 0x20), 0x20)
            mstore(add(mPtr, 0x40), 0x20)
            mstore(add(mPtr, 0x60), x)
            mstore(add(mPtr, 0x80), e)
            mstore(add(mPtr, 0xa0), p)
            success := staticcall(gas(), 0x05, mPtr, 0xc0, 0x00, 0x20)
            a := mload(0x00)
        }
        require(success, "pow precompile call failed!");

        // ensure a < p/2
        if (a << 1 > p) {
            a = p - a;
        }

        // check if a^2 = x, if not x is not a quadratic residue
        e = mulmod(a, a, p);

        isQuadraticResidue = (e == BaseField.unwrap(x));
        return (isQuadraticResidue, BaseField.wrap(a));
    }
}
