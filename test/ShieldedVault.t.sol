// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {ShieldedVault} from "../src/ShieldedVault.sol";
import {DarkPoolErrors} from "../src/errors/DarkPoolErrors.sol";
import {MockHasher} from "../src/mocks/MockHasher.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {PoseidonHasher} from "../src/PoseidonHasher.sol";
import {IHasher} from "../src/interfaces/IHasher.sol";

/**
 * @title ShieldedVaultTest
 * @notice Fase 2: deposit ETH/ERC-20, roots historicas, nullifiers, settlement stub.
 */
contract ShieldedVaultTest is Test {
    uint32 internal constant LEVELS = 4;

    MockHasher internal mockHasher;
    PoseidonHasher internal poseidonHasher;
    ShieldedVault internal ethVault;
    ShieldedVault internal erc20Vault;
    MockERC20 internal mockToken;

    address internal darkPool = makeAddr("darkPool");
    address internal alice = makeAddr("alice");

    event Deposited(bytes32 indexed noteCommitment, uint32 leafIndex, uint256 amount, address indexed from);
    event SettlementApplied(
        bytes32 indexed buyNullifier,
        bytes32 indexed sellNullifier,
        bytes32 newBuyNote,
        bytes32 newSellNote
    );

    function setUp() public {
        mockHasher = new MockHasher();
        poseidonHasher = new PoseidonHasher();
        mockToken = new MockERC20();

        ethVault = new ShieldedVault(LEVELS, IHasher(address(mockHasher)), address(0));
        ethVault.setDarkPool(darkPool);

        erc20Vault = new ShieldedVault(LEVELS, IHasher(address(mockHasher)), address(mockToken));
        erc20Vault.setDarkPool(darkPool);

        vm.deal(alice, 100 ether);
        mockToken.mint(alice, 1_000_000e18);
    }

    function test_constructor_emptyRootKnown() public view {
        bytes32 root = ethVault.balanceRoot();
        assertTrue(root != bytes32(0));
        assertTrue(ethVault.isKnownBalanceRoot(root));
        assertEq(ethVault.nextIndex(), 0);
    }

    function test_constructor_rejectsZeroHasher() public {
        vm.expectRevert(DarkPoolErrors.ZeroAddress.selector);
        new ShieldedVault(LEVELS, IHasher(address(0)), address(0));
    }

    function test_constructor_rejectsInvalidLevels() public {
        vm.expectRevert(DarkPoolErrors.InvalidNoteCommitment.selector);
        new ShieldedVault(0, IHasher(address(mockHasher)), address(0));
    }

    function test_setDarkPool_onlyOnce() public {
        ShieldedVault v = new ShieldedVault(LEVELS, IHasher(address(mockHasher)), address(0));
        v.setDarkPool(darkPool);
        vm.expectRevert(DarkPoolErrors.Unauthorized.selector);
        v.setDarkPool(makeAddr("other"));
    }

    function test_setDarkPool_rejectsZero() public {
        ShieldedVault v = new ShieldedVault(LEVELS, IHasher(address(mockHasher)), address(0));
        vm.expectRevert(DarkPoolErrors.ZeroAddress.selector);
        v.setDarkPool(address(0));
    }

    function test_depositETH_success_updatesRoot() public {
        bytes32 note = keccak256("note-eth-1");
        bytes32 rootBefore = ethVault.balanceRoot();
        uint256 amount = 1 ether;

        vm.expectEmit(true, true, false, true);
        emit Deposited(note, 0, amount, alice);

        vm.prank(alice);
        ethVault.deposit{value: amount}(amount, note);

        bytes32 rootAfter = ethVault.balanceRoot();
        assertTrue(rootAfter != rootBefore);
        assertTrue(ethVault.isKnownBalanceRoot(rootBefore));
        assertTrue(ethVault.isKnownBalanceRoot(rootAfter));
        assertTrue(ethVault.notes(note));
        assertEq(ethVault.nextIndex(), 1);
        assertEq(address(ethVault).balance, amount);
    }

    function test_depositETH_wrongValue_reverts() public {
        vm.prank(alice);
        vm.expectRevert(DarkPoolErrors.InvalidDepositAmount.selector);
        ethVault.deposit{value: 0.5 ether}(1 ether, keccak256("n"));
    }

    function test_deposit_zeroAmount_reverts() public {
        vm.prank(alice);
        vm.expectRevert(DarkPoolErrors.InvalidDepositAmount.selector);
        ethVault.deposit{value: 0}(0, keccak256("n"));
    }

    function test_deposit_zeroCommitment_reverts() public {
        vm.prank(alice);
        vm.expectRevert(DarkPoolErrors.InvalidNoteCommitment.selector);
        ethVault.deposit{value: 1 ether}(1 ether, bytes32(0));
    }

    function test_deposit_duplicateNote_reverts() public {
        bytes32 note = keccak256("dup");
        vm.startPrank(alice);
        ethVault.deposit{value: 1 ether}(1 ether, note);
        vm.expectRevert(DarkPoolErrors.InvalidNoteCommitment.selector);
        ethVault.deposit{value: 1 ether}(1 ether, note);
        vm.stopPrank();
    }

    function test_depositERC20_success() public {
        bytes32 note = keccak256("note-erc20");
        uint256 amount = 100e18;

        vm.startPrank(alice);
        mockToken.approve(address(erc20Vault), amount);
        erc20Vault.deposit(amount, note);
        vm.stopPrank();

        assertTrue(erc20Vault.notes(note));
        assertEq(mockToken.balanceOf(address(erc20Vault)), amount);
        assertEq(erc20Vault.nextIndex(), 1);
    }

    function test_depositERC20_withMsgValue_reverts() public {
        vm.prank(alice);
        vm.expectRevert(DarkPoolErrors.InvalidDepositAmount.selector);
        erc20Vault.deposit{value: 1}(100e18, keccak256("x"));
    }

    function test_deposit_treeFull_reverts() public {
        uint32 capacity = uint32(1) << LEVELS;
        vm.startPrank(alice);
        for (uint32 i; i < capacity; ++i) {
            ethVault.deposit{value: 0.01 ether}(0.01 ether, keccak256(abi.encodePacked("leaf", i)));
        }
        vm.expectRevert(DarkPoolErrors.TreeFull.selector);
        ethVault.deposit{value: 0.01 ether}(0.01 ether, keccak256("overflow"));
        vm.stopPrank();
    }

    function test_deposit_withPoseidonHasher() public {
        ShieldedVault v = new ShieldedVault(LEVELS, IHasher(address(poseidonHasher)), address(0));
        bytes32 note = poseidonHasher.hashLeftRight(bytes32(uint256(1)), bytes32(uint256(2)));
        v.deposit{value: 1 ether}(1 ether, note);
        assertTrue(v.notes(note));
        assertTrue(v.isKnownBalanceRoot(v.balanceRoot()));
    }

    function test_applySettlement_success_marksNullifiersAndInsertsChange() public {
        bytes32 note = keccak256("funded");
        vm.prank(alice);
        ethVault.deposit{value: 2 ether}(2 ether, note);

        bytes32 buyN = keccak256("buy-null");
        bytes32 sellN = keccak256("sell-null");
        bytes32 newBuy = keccak256("change-buy");
        bytes32 newSell = keccak256("change-sell");
        bytes32 rootBefore = ethVault.balanceRoot();

        vm.expectEmit(true, true, false, true);
        emit SettlementApplied(buyN, sellN, newBuy, newSell);

        vm.prank(darkPool);
        ethVault.applySettlement(buyN, sellN, newBuy, newSell);

        assertTrue(ethVault.noteNullifiers(buyN));
        assertTrue(ethVault.noteNullifiers(sellN));
        assertTrue(ethVault.notes(newBuy));
        assertTrue(ethVault.notes(newSell));
        assertTrue(ethVault.balanceRoot() != rootBefore);
        assertEq(ethVault.nextIndex(), 3); // 1 deposit + 2 change
    }

    function test_applySettlement_unauthorized_reverts() public {
        vm.expectRevert(DarkPoolErrors.Unauthorized.selector);
        ethVault.applySettlement(keccak256("a"), keccak256("b"), bytes32(0), bytes32(0));
    }

    function test_applySettlement_nullifierReplay_reverts() public {
        bytes32 buyN = keccak256("bn");
        bytes32 sellN = keccak256("sn");

        vm.prank(darkPool);
        ethVault.applySettlement(buyN, sellN, bytes32(0), bytes32(0));

        vm.prank(darkPool);
        vm.expectRevert(DarkPoolErrors.InvalidSettlement.selector);
        ethVault.applySettlement(buyN, keccak256("other"), bytes32(0), bytes32(0));
    }

    function test_applySettlement_zeroNullifier_reverts() public {
        vm.prank(darkPool);
        vm.expectRevert(DarkPoolErrors.InvalidSettlement.selector);
        ethVault.applySettlement(bytes32(0), keccak256("s"), bytes32(0), bytes32(0));
    }

    function testFuzz_depositETH_uniqueNotes(uint256 amount, bytes32 salt) public {
        amount = bound(amount, 1, 10 ether);
        bytes32 note = keccak256(abi.encodePacked(salt, amount));
        vm.assume(!ethVault.notes(note));
        vm.assume(ethVault.nextIndex() < (uint32(1) << LEVELS));

        uint256 balBefore = address(ethVault).balance;
        vm.prank(alice);
        ethVault.deposit{value: amount}(amount, note);

        assertTrue(ethVault.notes(note));
        assertEq(address(ethVault).balance, balBefore + amount);
        assertTrue(ethVault.isKnownBalanceRoot(ethVault.balanceRoot()));
    }
}
