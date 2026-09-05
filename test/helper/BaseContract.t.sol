// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";
import {TokenizeVault} from "src/TokenizeVault.sol";
import {MockAsset} from "test/mock/MockAsset.sol";

/**
 * @title BaseContract
 * @notice Base test contract containing common setup, accounts, constants,
 *         and helper functions for ERC4626 vault testing.
 * @dev Inherits from Foundry's Test contract to access cheatcodes and testing utilities.
 */
contract BaseContract is Test {
    /// @notice TokenizeVault vault instance used throughout the tests.
    TokenizeVault internal tokenVault;

    /// @notice Mock usdt asset used as the underlying asset of the vault.
    MockAsset internal usdt;

    /// @notice First test user.
    address internal user1 = makeAddr("user1");

    /// @notice Second test user.
    address internal user2 = makeAddr("user2");

    /// @notice Operator test address.
    address internal operator = makeAddr("operator");

    /// @notice Hacker test address used for attack-related test cases.
    address internal hacker = makeAddr("hacker");

    /// @notice Default amount of assets used for deposit tests.
    uint256 internal depositAmt = 500;

    /// @notice Default amount of shares used for mint tests.
    uint256 internal mintAmt = 500;

    /// @notice Default amount of assets used for withdrawal tests.
    uint256 internal withdrawlAmt = 400;

    /// @notice Default amount of shares used for redemption tests.
    uint256 internal redeemAmt = 400;

    /**
     * @notice Deploys the mock asset and ERC4626 vault and funds test accounts.
     * @dev Called automatically by Foundry before each test function.
     */
    function setUp() public {
        usdt = new MockAsset();
        tokenVault = new TokenizeVault(address(usdt));

        usdt.mint(user1, 2000);
        usdt.mint(user2, 2000);
        usdt.mint(hacker, 10001);
    }

    /**
     * @notice Approves the vault to spend usdt on behalf of an account.
     * @param account Address that grants the token allowance to the vault.
     */
    function _approve(address account) internal {
        vm.prank(account);
        usdt.approve(address(tokenVault), 2000);
    }

    /**
     * @notice Deposits assets into the vault on behalf of an account.
     * @param account Address performing the deposit and receiving the shares.
     * @param assets Amount of underlying assets to deposit.
     */
    function _deposit(address account, uint256 assets) internal {
        _approve(account);

        vm.prank(account);
        tokenVault.deposit(assets, account);
    }

    /**
     * @notice Mints a specified number of vault shares for user1.
     * @param shares Number of vault shares to mint.
     */
    function _mint(uint256 shares) internal {
        _approve(user1);

        vm.prank(user1);
        tokenVault.mint(shares, user1);
    }

    /**
     * @notice Withdraws a specified amount of assets from the vault.
     * @param assets Amount of underlying assets to withdraw.
     */
    function _withdraw(uint256 assets) internal {
        vm.prank(user1);
        tokenVault.withdraw(assets, user1, user1);
    }

    /**
     * @notice Redeems a specified number of shares from the vault.
     * @param shares Number of vault shares to redeem.
     */
    function _redeem(uint256 shares) internal {
        vm.prank(user1);
        tokenVault.redeem(shares, user2, user1);
    }
}
