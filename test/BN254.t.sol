// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

// Libraries
import "forge-std/Test.sol";

// Target contract
import { BN254 } from "../src/BN254.sol";

contract BN254CommonTest is Test {
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
        cmds[0] = "diff-test-bn254";
        cmds[1] = "bn254-g2-gen";

        bytes memory result = vm.ffi(cmds);
        BN254.G2Point memory g2Gen = abi.decode(result, (BN254.G2Point));

        assertEqG2Point(BN254.P2(), g2Gen);
    }
}

contract BN254_g1BasicArithmetic is BN254CommonTest {
    function testFuzz_Add(uint64 seed) external {
        string[] memory cmds = new string[](3);
        cmds[0] = "diff-test-bn254";
        cmds[1] = "bn254-g1-add-op";
        cmds[2] = vm.toString(seed);

        bytes memory result = vm.ffi(cmds);
        (BN254.G1Point memory a, BN254.G1Point memory b, BN254.G1Point memory sum) =
            abi.decode(result, (BN254.G1Point, BN254.G1Point, BN254.G1Point));
        assertEqG1Point(sum, BN254.add(a, b));
    }

    function testFuzz_Negate(uint64 seed) external {
        string[] memory cmds = new string[](3);
        cmds[0] = "diff-test-bn254";
        cmds[1] = "bn254-g1-neg-op";
        cmds[2] = vm.toString(seed);

        bytes memory result = vm.ffi(cmds);
        (BN254.G1Point memory a, BN254.G1Point memory neg) =
            abi.decode(result, (BN254.G1Point, BN254.G1Point));
        assertEqG1Point(neg, BN254.negate(a));
    }
}

contract BN254_scalarMul_Test is BN254CommonTest {
    /// @dev Test some edge cases
    function test_EdgeCases() external {
        assertEqG1Point(BN254.scalarMul(BN254.P1(), BN254.ScalarField.wrap(0)), BN254.infinity());
        assertEqG1Point(BN254.scalarMul(BN254.P1(), BN254.ScalarField.wrap(1)), BN254.P1());
        // generator ^ -1
        BN254.G1Point memory genInv = BN254.G1Point(
            BN254.BaseField.wrap(1),
            BN254.BaseField.wrap(0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd45)
        );
        assertEqG1Point(
            BN254.scalarMul(BN254.P1(), BN254.ScalarField.wrap(BN254.R_MOD - 1)), genInv
        );
        assertEqG1Point(
            BN254.scalarMul(BN254.P1(), BN254.ScalarField.wrap(BN254.R_MOD)), BN254.infinity()
        );
        assertEqG1Point(
            BN254.scalarMul(BN254.P1(), BN254.ScalarField.wrap(BN254.R_MOD + 1)), BN254.P1()
        );
    }

    /// @dev Test scalarMul matches results from arkworks
    function testFuzz_scalarMul_matches(uint256 randScalar) external {
        string[] memory cmds = new string[](3);
        cmds[0] = "diff-test-bn254";
        cmds[1] = "bn254-g1-from-scalar";
        cmds[2] = vm.toString(bytes32(randScalar));

        bytes memory result = vm.ffi(cmds);
        (BN254.G1Point memory point) = abi.decode(result, (BN254.G1Point));

        assertEqG1Point(point, BN254.scalarMul(BN254.P1(), BN254.ScalarField.wrap(randScalar)));
    }
}

contract BN254_validateG1Point_Test is BN254CommonTest {
    /// @dev Test some valid edge-case points
    function test_EdgeCases() external pure {
        BN254.validateG1Point(BN254.P1());
        BN254.validateG1Point(BN254.infinity());
        BN254.validateG1Point(BN254.negate(BN254.P1()));
        // generator ^ -1
        BN254.G1Point memory genInv = BN254.G1Point(
            BN254.BaseField.wrap(1),
            BN254.BaseField.wrap(0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd45)
        );
        BN254.validateG1Point(genInv);
    }

    /// @dev Test random valid points should pass
    function testFuzz_ValidPointShouldPass(uint256 randScalar) external {
        string[] memory cmds = new string[](3);
        cmds[0] = "diff-test-bn254";
        cmds[1] = "bn254-g1-from-scalar";
        cmds[2] = vm.toString(bytes32(randScalar));

        bytes memory result = vm.ffi(cmds);
        BN254.G1Point memory point = abi.decode(result, (BN254.G1Point));

        // valid point should pass
        BN254.validateG1Point(point);
    }

    /// @dev Test invalid points should cause revert
    /// forge-config: default.allow_internal_expect_revert = true
    function test_RevertWhenInvalidPoint(BN254.G1Point memory point) external {
        string[] memory cmds = new string[](3);
        cmds[0] = "diff-test-bn254";
        cmds[1] = "bn254-g1-is-on-curve";
        cmds[2] = vm.toString(abi.encode(point));

        bytes memory result = vm.ffi(cmds);
        bool isOnCurve = abi.decode(result, (bool));

        if (!isOnCurve) {
            vm.expectRevert(BN254.InvalidG1.selector);
            BN254.validateG1Point(point);
        }
    }
}

contract BN254_pairingProd2_Test is BN254CommonTest {
    /// @dev Test pairingProd2 function with random G1, G2 pairs,
    /// fuzzer only generate random seed, actual random pairs are generated in diff-test-bn254
    function testFuzz_pairingProd2_matches(uint64 seed) external {
        string[] memory cmds = new string[](3);
        cmds[0] = "diff-test-bn254";
        cmds[1] = "bn254-pairing-prod2";
        cmds[2] = vm.toString(seed);

        bytes memory result = vm.ffi(cmds);
        (
            BN254.G1Point memory a1,
            BN254.G2Point memory a2,
            BN254.G1Point memory b1,
            BN254.G2Point memory b2
        ) = abi.decode(result, (BN254.G1Point, BN254.G2Point, BN254.G1Point, BN254.G2Point));

        // when seed % 2 == 1, diff-test-bn254 will generate pairs that satisfy the pairing product
        // else it will generate unsatisyfing pairs
        if (seed % 2 == 0) {
            assert(!BN254.pairingProd2(a1, a2, b1, b2));
        } else {
            assert(BN254.pairingProd2(a1, a2, b1, b2));
        }
    }
}

contract BN254_ScalarFieldArithmetic_Test is Test {
    /// forge-config: default.allow_internal_expect_revert = true
    function testInvertOnZero() external {
        vm.expectRevert(BN254.BN254ScalarInvZero.selector);
        BN254.invert(BN254.ScalarField.wrap(0));
    }

    function testFuzz_Invert(uint256 scalar) external {
        scalar = bound(scalar, 1, BN254.R_MOD - 1);
        string[] memory cmds = new string[](3);
        cmds[0] = "diff-test-bn254";
        cmds[1] = "bn254-scalar-inv-op";
        cmds[2] = vm.toString(scalar);

        bytes memory result = vm.ffi(cmds);
        uint256 inv = abi.decode(result, (uint256));
        assertEq(inv, BN254.ScalarField.unwrap(BN254.invert(BN254.ScalarField.wrap(scalar))));
    }

    function testFuzz_Negate(uint256 scalar) external {
        scalar = bound(scalar, 0, BN254.R_MOD - 1);
        string[] memory cmds = new string[](3);
        cmds[0] = "diff-test-bn254";
        cmds[1] = "bn254-scalar-neg-op";
        cmds[2] = vm.toString(scalar);

        bytes memory result = vm.ffi(cmds);
        uint256 neg = abi.decode(result, (uint256));
        assertEq(neg, BN254.ScalarField.unwrap(BN254.negate(BN254.ScalarField.wrap(scalar))));
    }
}

contract BN254_multiScalarMul_Test is BN254CommonTest {
    /// forge-config: default.allow_internal_expect_revert = true
    function test_revertWhenEmptyArray() external {
        BN254.G1Point[] memory bases;
        BN254.ScalarField[] memory scalars;
        assert(bases.length == 0 && scalars.length == 0);
        vm.expectRevert(BN254.InvalidArgs.selector);
        BN254.multiScalarMul(bases, scalars);
    }

    function test_msm() external {
        uint64 numBases = 5;

        string[] memory cmds = new string[](3);
        cmds[0] = "diff-test-bn254";
        cmds[1] = "bn254-msm";
        cmds[2] = vm.toString(numBases);

        bytes memory result = vm.ffi(cmds);
        (BN254.G1Point[] memory bases, BN254.ScalarField[] memory scalars, BN254.G1Point memory res)
        = abi.decode(result, (BN254.G1Point[], BN254.ScalarField[], BN254.G1Point));

        assertEqG1Point(res, BN254.multiScalarMul(bases, scalars));
    }
}

contract BN254Caller {
    function foo() public view returns (BN254.G1Point memory res) {
        res = BN254.add(BN254.P1(), BN254.P1());
    }
}

contract InternalLibTest is Test {
    BN254Caller c;

    function setUp() public {
        c = new BN254Caller();
    }

    function containsDelegateCall(bytes memory code) internal pure returns (bool) {
        for (uint256 i = 0; i < code.length - 1; i++) {
            if (code[i] == 0xF4) {
                // 0xF4 = DELEGATECALL opcode
                return true;
            }
        }
        return false;
    }

    function testLibraryIsInlined() public {
        bytes memory bytecode = address(c).code;
        assertFalse(containsDelegateCall(bytecode), "Library should be inlined");
    }
}
