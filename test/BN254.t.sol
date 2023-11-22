// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

// Libraries
import "forge-std/Test.sol";

// Target contract
import { BN254 } from "../src/BN254.sol";

contract BN254CommonTest is Test {
    using BN254 for BN254.BaseField;
    using BN254 for BN254.ScalarField;

    /// Thin wrapper to ensure two G1 points are the same
    /// @dev we not only require value equality (mod p), but also representation equality in u256
    function assertEqG1Point(BN254.G1Point memory a, BN254.G1Point memory b) public {
        assertEq(BN254.BaseField.unwrap(a.x), BN254.BaseField.unwrap(b.x));
        assertEq(BN254.BaseField.unwrap(a.y), BN254.BaseField.unwrap(b.y));
    }

    /// Thin wrapper to ensure two G2 points are the same
    /// @dev we not only require value equality (mod p), but also representation equality in u256
    function assertEqG2Point(BN254.G2Point memory a, BN254.G2Point memory b) public {
        assertEq(BN254.BaseField.unwrap(a.x0), BN254.BaseField.unwrap(b.x0));
        assertEq(BN254.BaseField.unwrap(a.x1), BN254.BaseField.unwrap(b.x1));
        assertEq(BN254.BaseField.unwrap(a.y0), BN254.BaseField.unwrap(b.y0));
        assertEq(BN254.BaseField.unwrap(a.y1), BN254.BaseField.unwrap(b.y1));
    }
}

contract BN254_P2_Test is BN254CommonTest {
    /// @dev Test if the G2 generator matches with arkworks
    function test_p2_matches() external {
        string[] memory cmds = new string[](2);
        cmds[0] = "diff-test";
        cmds[1] = "bn254-g2-gen";

        bytes memory result = vm.ffi(cmds);
        (BN254.G2Point memory g2Gen) = abi.decode(result, (BN254.G2Point));

        assertEqG2Point(BN254.P2(), g2Gen);
    }
}

contract BN254_pairingProd2_Test is BN254CommonTest {
    /// @dev Test pairingProd2 function with random G1, G2 pairs,
    /// fuzzer only generate random seed, actual random pairs are generated in diff-test
    function testFuzz_pairingProd2_matches(uint64 seed) external {
        string[] memory cmds = new string[](3);
        cmds[0] = "diff-test";
        cmds[1] = "bn254-pairing-prod2";
        cmds[2] = vm.toString(seed);

        bytes memory result = vm.ffi(cmds);
        (
            BN254.G1Point memory a1,
            BN254.G2Point memory a2,
            BN254.G1Point memory b1,
            BN254.G2Point memory b2
        ) = abi.decode(result, (BN254.G1Point, BN254.G2Point, BN254.G1Point, BN254.G2Point));

        // when seed % 2 == 1, diff-test will generate pairs that satisfy the pairing product
        // else it will generate unsatisyfing pairs
        if (seed % 2 == 0) {
            assert(!BN254.pairingProd2(a1, a2, b1, b2));
        } else {
            assert(BN254.pairingProd2(a1, a2, b1, b2));
        }
    }
}
