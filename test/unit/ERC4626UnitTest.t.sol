// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BaseContract} from "test/helper/BaseContract.t.sol";
import {ERC4626} from "src/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * @title ERC4626UnitTest
 * @notice Unit tests for the ERC4626 vault implementation.
 * @dev Tests vault metadata, asset/share conversions, limits, preview functions,
 *      deposits, mints, withdrawals, redemptions, exchange-rate behavior,
 *      and the ERC4626 inflation attack.
 */
contract ERC4626UnitTest is BaseContract {
    /**
     * @notice Tests that `asset()` returns the address of the underlying asset.
     */
    function test_asset_ReturnsUnderlyingAssetAddress() external view {
        assertEq(tokenVault.asset(), address(usdt));
    }

    /**
     * @notice Tests that `totalAssets()` returns the total assets held by the vault.
     */
    function test_totalAssets_ReturnsTotalAssetsHeldByVault() external {
        _deposit(user1, depositAmt);
        _deposit(user1, depositAmt);

        assertEq(tokenVault.totalAssets(), 2 * depositAmt);
    }

    /**
     * @notice Tests conversion of shares into assets when the exchange rate is 1:1.
     */
    function test_convertToAssets_ReturnsAmountOfAssets() external view {
        assertEq(tokenVault.convertToAssets(500), 500);
    }

    /**
     * @notice Tests conversion of assets into shares when the exchange rate is 1:1.
     */
    function test_convertToShares_ReturnsAmountOfShares() external view {
        assertEq(tokenVault.convertToShares(400), 400);
    }

    /**
     * @notice Tests that `maxDeposit()` returns the maximum amount of assets
     *         that can be deposited.
     */
    function test_maxDeposit_ReturnsMaximumAssetsThatCanBeDeposited() external view {
        assertEq(tokenVault.maxDeposit(user1), type(uint128).max);
    }

    /**
     * @notice Tests that `maxMint()` returns the maximum amount of shares
     *         that can be minted.
     */
    function test_maxMint_ReturnsMaximumSharesThatCanBeMinted() external view {
        assertEq(tokenVault.maxMint(user1), type(uint128).max);
    }

    /**
     * @notice Tests that `maxRedeem()` returns the maximum number of shares
     *         that the owner can redeem.
     */
    function test_maxRedeem_ReturnsMaximumSharesThatCanBeRedeemed() external {
        _deposit(user1, depositAmt);
        uint256 userShareBal = tokenVault.balanceOf(user1);

        assertEq(tokenVault.maxRedeem(user1), userShareBal);
    }

    /**
     * @notice Tests that `maxWithdraw()` returns the maximum amount of assets
     *         that the owner can withdraw using all available shares.
     */
    function test_maxWithdraw_ReturnsMaximumAssetsThatCanBeWithdrawn() external {
        _deposit(user1, depositAmt);
        uint256 assets = tokenVault.previewRedeem(tokenVault.balanceOf(user1));

        assertEq(tokenVault.maxWithdraw(user1), assets);
    }

    /**
     * @notice Tests that `previewDeposit()` returns the number of shares
     *         received for a given amount of assets.
     * @dev ERC4626 deposit conversion rounds down.
     */
    function test_previewDeposit_ReturnsSharesReceivedForAssets() external {
        _deposit(user1, depositAmt);
        assertEq(tokenVault.balanceOf(user1), tokenVault.previewDeposit(depositAmt));

        vm.prank(user2);
        usdt.transfer(address(tokenVault), 333);

        // Conversion rounds down.
        assertEq(tokenVault.previewDeposit(550), 330);
    }

    /**
     * @notice Tests that `previewMint()` returns the amount of assets
     *         required to mint a given number of shares.
     * @dev ERC4626 mint conversion rounds up.
     */
    function test_previewMint_ReturnsAssetsRequiredForShares() external {
        _mint(mintAmt);
        assertEq(tokenVault.totalAssets(), tokenVault.previewMint(mintAmt));

        vm.prank(user2);
        usdt.transfer(address(tokenVault), 333);

        // Conversion rounds up.
        assertEq(tokenVault.previewMint(550), 917);
    }

    /**
     * @notice Tests that `previewWithdraw()` returns the number of shares
     *         that must be burned to withdraw a given amount of assets.
     * @dev ERC4626 withdrawal conversion rounds up.
     */
    function test_previewWithdraw_ReturnsSharesRequiredForAssets() external {
        _deposit(user1, depositAmt);

        vm.prank(user2);
        usdt.transfer(address(tokenVault), 333);

        // Conversion rounds up.
        assertEq(tokenVault.previewWithdraw(550), 331);
    }

    /**
     * @notice Tests that `previewRedeem()` returns the amount of assets
     *         received when redeeming a given number of shares.
     * @dev ERC4626 redemption conversion rounds down.
     */
    function test_previewRedeem_ReturnsAssetsReceivedForShares() external {
        _deposit(user1, depositAmt);

        vm.prank(user2);
        usdt.transfer(address(tokenVault), 333);

        // Conversion rounds down.
        assertEq(tokenVault.previewRedeem(550), 916);
    }

    /**
     * @notice Tests that a deposit mints the exact number of shares
     *         returned by `previewDeposit()`.
     */
    function test_deposit_MintsExpectedAmountOfShares() external {
        _deposit(user1, depositAmt);
        assertEq(tokenVault.balanceOf(user1), tokenVault.previewDeposit(depositAmt));
    }

    /**
     * @notice Tests that `deposit()` reverts when the receiver is the zero address.
     */
    function test_deposit_RevertsIfReceiverIsZeroAddress() external {
        vm.prank(user1);
        vm.expectRevert(ERC4626.ZeroAddressNotAllowed.selector);
        tokenVault.deposit(depositAmt, address(0));
    }

    /**
     * @notice Tests that `deposit()` reverts when the requested assets
     *         exceed the maximum permitted amount.
     */
    function test_deposit_RevertsIfAssetsExceedMaxAmount() external {
        vm.prank(user1);
        vm.expectRevert(ERC4626.AmountGreaterThanMaxAmount.selector);
        tokenVault.deposit(type(uint256).max, user2);
    }

    /**
     * @notice Tests that `deposit()` emits the correct ERC4626 Deposit event.
     */
    function test_deposit_EmitsDepositEvent() external {
        _approve(user1);

        vm.expectEmit(true, true, false, true);
        emit IERC4626.Deposit(user1, address(tokenVault), depositAmt, tokenVault.previewDeposit(depositAmt));

        vm.prank(user1);
        tokenVault.deposit(500, user1);
    }

    /**
     * @notice Tests that `mint()` mints exactly the requested number of shares
     *         and charges the user the required amount of assets.
     */
    function test_mint_MintsExactAmountOfShares() external {
        uint256 userAssetsBefore = usdt.balanceOf(user1);
        uint256 asset = tokenVault.previewMint(mintAmt);

        _mint(mintAmt);

        uint256 userAssetsAfter = usdt.balanceOf(user1);

        assertEq(tokenVault.balanceOf(user1), mintAmt);
        assertEq(userAssetsBefore - userAssetsAfter, asset);
    }

    /**
     * @notice Tests that `mint()` reverts when the receiver is the zero address.
     */
    function test_mint_RevertsIfReceiverIsZeroAddress() external {
        vm.expectRevert(ERC4626.ZeroAddressNotAllowed.selector);
        tokenVault.mint(mintAmt, address(0));
    }

    /**
     * @notice Tests that `mint()` reverts when the requested shares
     *         exceed the maximum permitted amount.
     */
    function test_mint_RevertsIfSharesExceedMaxAmount() external {
        vm.expectRevert(ERC4626.AmountGreaterThanMaxAmount.selector);
        tokenVault.mint(type(uint256).max, user1);
    }

    /**
     * @notice Tests that `mint()` emits the correct ERC4626 Deposit event.
     * @dev For `mint()`, the event contains the assets required to mint
     *      the requested shares and the requested share amount.
     */
    function test_mint_EmitsDepositEvent() external {
        _approve(user1);

        vm.expectEmit(true, true, false, true);
        emit IERC4626.Deposit(user1, address(tokenVault), tokenVault.previewMint(mintAmt), mintAmt);

        vm.prank(user1);
        tokenVault.mint(mintAmt, user1);
    }

    /**
     * @notice Tests that `withdraw()` burns the expected number of shares
     *         and removes the requested assets from the vault.
     */
    function test_withdraw_WithdrawsExactAssets() external {
        _deposit(user1, depositAmt);

        uint256 shareBalBefore = tokenVault.balanceOf(user1);
        uint256 userAssetsBefore = usdt.balanceOf(user1);

        _withdraw(withdrawlAmt);

        uint256 shareBalAfter = tokenVault.balanceOf(user1);
        uint256 userAssetsAfter = usdt.balanceOf(user1);

        assertEq(shareBalBefore - shareBalAfter, tokenVault.previewWithdraw(withdrawlAmt));
        assertEq(userAssetsAfter - userAssetsBefore, withdrawlAmt);
    }

    /**
     * @notice Tests that `withdraw()` reverts when the receiver is the zero address.
     */
    function test_withdraw_RevertsIfReceiverIsZeroAddress() external {
        _deposit(user1, depositAmt);

        vm.prank(user1);
        vm.expectRevert(ERC4626.ZeroAddressNotAllowed.selector);

        tokenVault.withdraw(withdrawlAmt, address(0), user1);
    }

    /**
     * @notice Tests that `withdraw()` reverts when the owner is the zero address.
     */
    function test_withdraw_RevertsIfOwnerIsZeroAddress() external {
        _deposit(user1, depositAmt);

        vm.prank(user1);
        vm.expectRevert(ERC4626.ZeroAddressNotAllowed.selector);

        tokenVault.withdraw(withdrawlAmt, user2, address(0));
    }

    /**
     * @notice Tests that `withdraw()` reverts when the requested assets
     *         require more shares than the owner possesses.
     */
    function test_withdraw_RevertsIfAssetsExceedAvailableShares() external {
        _deposit(user1, depositAmt);

        vm.expectRevert(ERC4626.InsufficientShares.selector);
        _withdraw(600);
    }

    /**
     * @notice Tests that `withdraw()` reverts when an unauthorized caller
     *         attempts to withdraw another user's assets.
     */
    function test_withdraw_RevertsIfCallerIsNotAllowed() external {
        _deposit(user1, depositAmt);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, user2, 0, withdrawlAmt)
        );
        tokenVault.withdraw(withdrawlAmt, user1, user1);
    }

    /**
     * @notice Tests that an approved spender can withdraw assets
     *         on behalf of the share owner.
     */
    function test_withdraw_AllowsApprovedSpenderToWithdraw() external {
        _deposit(user1, depositAmt);

        vm.prank(user1);
        tokenVault.approve(operator, withdrawlAmt);

        vm.prank(operator);
        tokenVault.withdraw(withdrawlAmt, user2, user1);

        assertEq(tokenVault.totalAssets(), 100);
    }

    /**
     * @notice Tests that `withdraw()` emits the correct ERC4626 Withdraw event.
     */
    function test_withdraw_EmitsWithdrawEvent() external {
        _deposit(user1, depositAmt);

        vm.expectEmit(true, true, true, true);
        emit IERC4626.Withdraw(user1, user1, user1, withdrawlAmt, tokenVault.previewWithdraw(withdrawlAmt));
        _withdraw(withdrawlAmt);
    }

    /**
     * @notice Tests that `redeem()` burns the requested number of shares
     *         and removes the corresponding assets from the vault.
     */
    function test_redeem_BurnsExactAmountOfShares() external {
        _deposit(user1, depositAmt);

        uint256 userSharesBefore = tokenVault.balanceOf(user1);

        _redeem(redeemAmt);

        uint256 userSharesAfter = tokenVault.balanceOf(user1);

        assertEq(userSharesBefore - userSharesAfter, redeemAmt);
        assertEq(tokenVault.totalAssets(), 100);
    }

    /**
     * @notice Tests that `redeem()` reverts when the receiver is the zero address.
     */
    function test_redeem_RevertsIfReceiverIsZeroAddress() external {
        _deposit(user1, depositAmt);

        vm.prank(user1);
        vm.expectRevert(ERC4626.ZeroAddressNotAllowed.selector);

        tokenVault.redeem(redeemAmt, address(0), user1);
    }

    /**
     * @notice Tests that `redeem()` reverts when the owner is the zero address.
     */
    function test_redeem_RevertsIfOwnerIsZeroAddress() external {
        _deposit(user1, depositAmt);

        vm.prank(user1);
        vm.expectRevert(ERC4626.ZeroAddressNotAllowed.selector);

        tokenVault.redeem(redeemAmt, user2, address(0));
    }

    /**
     * @notice Tests that `redeem()` reverts when an unauthorized caller
     *         attempts to redeem another user's shares.
     */
    function test_redeem_RevertsIfCallerIsNotApproved() external {
        _deposit(user1, depositAmt);

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, user2, 0, redeemAmt));

        tokenVault.redeem(redeemAmt, user1, user1);
    }

    /**
     * @notice Tests that an approved spender can redeem shares
     *         on behalf of the share owner.
     */
    function test_redeem_AllowsApprovedSpenderToRedeem() external {
        _deposit(user1, depositAmt);

        uint256 userAssetsBefore = tokenVault.totalAssets();

        vm.prank(user1);
        tokenVault.approve(operator, redeemAmt);

        vm.prank(operator);
        tokenVault.redeem(redeemAmt, user2, user1);

        uint256 userAssetsAfter = tokenVault.totalAssets();

        assertEq(userAssetsBefore - userAssetsAfter, tokenVault.previewRedeem(redeemAmt));
    }

    /**
     * @notice Tests that the vault's exchange rate changes when assets
     *         are transferred directly to the vault.
     * @dev Direct asset transfers increase the vault's asset balance without
     *      increasing the total share supply.
     */
    function test_exchangeRate_ChangesAfterAssetDonation() external {
        _deposit(user1, 1000);

        assertEq(tokenVault.convertToShares(1000), 1000);

        vm.prank(user2);
        usdt.transfer(address(tokenVault), 500);

        assertEq(tokenVault.convertToShares(150), 100);
        assertEq(tokenVault.convertToAssets(100), 150);
    }

    ///////////////////////////// INFLATION ATTACK /////////////////////////////

    /**
     * @notice Demonstrates the ERC4626 inflation attack.
     * @dev An attacker deposits a small amount of assets and then directly
     *      donates assets to the vault. This increases the asset/share ratio
     *      without increasing the attacker's share balance.
     *
     *      A subsequent depositor receives significantly fewer shares because
     *      the conversion rounds down against the depositor.
     *
     *      This test intentionally demonstrates the vulnerable behavior and
     *      should fail or be replaced after an inflation-attack mitigation
     *      such as virtual assets/shares is implemented.
     */
    function test_inflationAttack_DonationDilutesNextDepositor() external {
        _deposit(hacker, 10);

        // Initially: 1 share = 1 USDT.
        assertEq(tokenVault.balanceOf(hacker), 10);

        vm.prank(hacker);
        usdt.transfer(address(tokenVault), 500);

        // Donation increases the asset/share ratio but does not mint shares.
        // Vault state: 510 assets / 10 shares = 51 assets per share.
        assertEq(tokenVault.balanceOf(hacker), 10);

        _deposit(user1, 1000);

        // Due to rounding down, the victim receives only 19 shares.
        assertEq(tokenVault.balanceOf(user1), 19);
    }
}
