// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BaseContract} from "test/helper/BaseContract.t.sol";
import {ERC4626} from "src/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * @title ERC4626UnitTest
 * @notice Unit tests for the ERC4626 vault implementation.
 * @dev Covers vault metadata, asset/share conversions, deposit and mint limits,
 *      preview functions, deposits, mints, withdrawals, redemptions,
 *      exchange-rate behavior, and inflation-attack mitigation.
 */
contract ERC4626UnitTest is BaseContract {
    /**
     * @notice Verifies that `asset()` returns the address of the vault's
     *         underlying asset.
     */
    function test_asset_ReturnsUnderlyingAssetAddress() external view {
        assertEq(tokenVault.asset(), address(usdt));
    }

    /**
     * @notice Verifies that `totalAssets()` equals the total underlying assets
     *         accounted for by the vault.
     */
    function test_totalAssets_ReturnsTotalAssetsHeldByVault() external {
        _deposit(user1, depositAmt);
        _deposit(user1, depositAmt);

        assertEq(tokenVault.totalAssets(), 2 * depositAmt);
    }

    /**
     * @notice Verifies that `convertToAssets()` converts shares to assets
     *         according to the current exchange rate.
     * @dev With the initial virtual asset/share configuration, 500,000 shares
     *      correspond to 500 underlying assets.
     */
    function test_convertToAssets_ReturnsAmountOfAssets() external view {
        assertEq(tokenVault.convertToAssets(500000), 500);
    }

    /**
     * @notice Verifies that `convertToShares()` converts assets to shares
     *         according to the current exchange rate.
     * @dev With the initial virtual asset/share configuration, 400 assets
     *      correspond to 400,000 shares.
     */
    function test_convertToShares_ReturnsAmountOfShares() external view {
        assertEq(tokenVault.convertToShares(400), 400000);
    }

    /**
     * @notice Verifies that `maxDeposit()` returns the maximum amount of
     *         underlying assets that an account can deposit.
     */
    function test_maxDeposit_ReturnsMaximumAssetsThatCanBeDeposited() external view {
        assertEq(tokenVault.maxDeposit(user1), type(uint128).max);
    }

    /**
     * @notice Verifies that `maxMint()` returns the maximum number of shares
     *         that an account can mint.
     */
    function test_maxMint_ReturnsMaximumSharesThatCanBeMinted() external view {
        assertEq(tokenVault.maxMint(user1), type(uint128).max);
    }

    /**
     * @notice Verifies that `maxRedeem()` returns the maximum number of shares
     *         that an account can redeem.
     * @dev The maximum redeemable amount is the owner's current share balance.
     */
    function test_maxRedeem_ReturnsMaximumSharesThatCanBeRedeemed() external {
        _deposit(user1, depositAmt);
        uint256 userShareBal = tokenVault.balanceOf(user1);

        assertEq(tokenVault.maxRedeem(user1), userShareBal);
    }

    /**
     * @notice Verifies that `maxWithdraw()` returns the maximum amount of
     *         assets that an account can withdraw using its available shares.
     */
    function test_maxWithdraw_ReturnsMaximumAssetsThatCanBeWithdrawn() external {
        _deposit(user1, depositAmt);
        uint256 assets = tokenVault.previewRedeem(tokenVault.balanceOf(user1));

        assertEq(tokenVault.maxWithdraw(user1), assets);
    }

    /**
     * @notice Verifies that `previewDeposit()` returns the number of shares
     *         that would be minted for a given asset deposit.
     * @dev ERC4626 deposit conversions round down in favor of the vault.
     *      A direct asset donation changes the conversion rate without
     *      increasing the share supply.
     */
    function test_previewDeposit_ReturnsSharesReceivedForAssets() external {
        _deposit(user1, depositAmt);
        assertEq(tokenVault.balanceOf(user1), tokenVault.previewDeposit(depositAmt));

        vm.prank(user2);
        usdt.transfer(address(tokenVault), 333);

        // The conversion rounds down to the nearest whole share.
        assertEq(tokenVault.previewDeposit(550), 330395);
    }

    /**
     * @notice Verifies that `previewMint()` returns the amount of assets
     *         required to mint a specified number of shares.
     * @dev ERC4626 mint conversions round up so that the vault receives
     *      enough assets to issue the requested number of shares.
     */
    function test_previewMint_ReturnsAssetsRequiredForShares() external {
        _mint(mintAmt);
        assertEq(tokenVault.totalAssets(), tokenVault.previewMint(mintAmt));

        vm.prank(user2);
        usdt.transfer(address(tokenVault), 333);

        // The conversion rounds up to ensure sufficient assets are deposited.
        assertEq(tokenVault.previewMint(550), 123);
    }

    /**
     * @notice Verifies that `previewWithdraw()` returns the number of shares
     *         required to withdraw a specified amount of assets.
     * @dev ERC4626 withdrawal conversions round up so that enough shares are
     *      burned to cover the requested asset amount.
     */
    function test_previewWithdraw_ReturnsSharesRequiredForAssets() external {
        _deposit(user1, depositAmt);

        vm.prank(user2);
        usdt.transfer(address(tokenVault), 333);

        // The conversion rounds up to ensure the requested assets can be withdrawn.
        assertEq(tokenVault.previewWithdraw(550), 330396);
    }

    /**
     * @notice Verifies that `previewRedeem()` returns the amount of assets
     *         that would be received for redeeming a specified number of shares.
     * @dev ERC4626 redemption conversions round down in favor of the vault.
     */
    function test_previewRedeem_ReturnsAssetsReceivedForShares() external {
        _deposit(user1, depositAmt);

        vm.prank(user2);
        usdt.transfer(address(tokenVault), 333);

        // The conversion rounds down to the nearest whole asset.
        assertEq(tokenVault.previewRedeem(tokenVault.balanceOf(user1)), 832);
    }

    /**
     * @notice Verifies that `deposit()` mints the exact number of shares
     *         returned by `previewDeposit()` for the same asset amount.
     */
    function test_deposit_MintsExpectedAmountOfShares() external {
        _deposit(user1, depositAmt);
        assertEq(tokenVault.balanceOf(user1), tokenVault.previewDeposit(depositAmt));
    }

    /**
     * @notice Verifies that `deposit()` reverts when the receiver is the
     *         zero address.
     */
    function test_deposit_RevertsIfReceiverIsZeroAddress() external {
        vm.prank(user1);
        vm.expectRevert(ERC4626.ZeroAddressNotAllowed.selector);
        tokenVault.deposit(depositAmt, address(0));
    }

    /**
     * @notice Verifies that `deposit()` reverts when the requested asset amount
     *         exceeds the maximum permitted deposit amount.
     */
    function test_deposit_RevertsIfAssetsExceedMaxAmount() external {
        vm.prank(user1);
        vm.expectRevert(ERC4626.AmountGreaterThanMaxAmount.selector);
        tokenVault.deposit(type(uint256).max, user2);
    }

    /**
     * @notice Verifies that `deposit()` emits the expected ERC4626 `Deposit`
     *         event with the correct caller, receiver, assets, and shares.
     */
    function test_deposit_EmitsDepositEvent() external {
        _approve(user1);

        vm.expectEmit(true, true, false, true);
        emit IERC4626.Deposit(user1, address(tokenVault), depositAmt, tokenVault.previewDeposit(depositAmt));

        vm.prank(user1);
        tokenVault.deposit(500, user1);
    }

    /**
     * @notice Verifies that `mint()` mints exactly the requested number of
     *         shares and charges the caller the required amount of assets.
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
     * @notice Verifies that `mint()` reverts when the receiver is the
     *         zero address.
     */
    function test_mint_RevertsIfReceiverIsZeroAddress() external {
        vm.expectRevert(ERC4626.ZeroAddressNotAllowed.selector);
        tokenVault.mint(mintAmt, address(0));
    }

    /**
     * @notice Verifies that `mint()` reverts when the requested share amount
     *         exceeds the maximum permitted mint amount.
     */
    function test_mint_RevertsIfSharesExceedMaxAmount() external {
        vm.expectRevert(ERC4626.AmountGreaterThanMaxAmount.selector);
        tokenVault.mint(type(uint256).max, user1);
    }

    /**
     * @notice Verifies that `mint()` emits the expected ERC4626 `Deposit`
     *         event with the required assets and requested shares.
     * @dev Unlike `deposit()`, the caller specifies the share amount and the
     *      vault calculates the required asset amount.
     */
    function test_mint_EmitsDepositEvent() external {
        _approve(user1);

        vm.expectEmit(true, true, false, true);
        emit IERC4626.Deposit(user1, address(tokenVault), tokenVault.previewMint(mintAmt), mintAmt);

        vm.prank(user1);
        tokenVault.mint(mintAmt, user1);
    }

    /**
     * @notice Verifies that `withdraw()` transfers the exact requested asset
     *         amount to the receiver and burns the corresponding shares.
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
     * @notice Verifies that `withdraw()` reverts when the receiver is the
     *         zero address.
     */
    function test_withdraw_RevertsIfReceiverIsZeroAddress() external {
        _deposit(user1, depositAmt);

        vm.prank(user1);
        vm.expectRevert(ERC4626.ZeroAddressNotAllowed.selector);

        tokenVault.withdraw(withdrawlAmt, address(0), user1);
    }

    /**
     * @notice Verifies that `withdraw()` reverts when the owner is the
     *         zero address.
     */
    function test_withdraw_RevertsIfOwnerIsZeroAddress() external {
        _deposit(user1, depositAmt);

        vm.prank(user1);
        vm.expectRevert(ERC4626.ZeroAddressNotAllowed.selector);

        tokenVault.withdraw(withdrawlAmt, user2, address(0));
    }

    /**
     * @notice Verifies that `withdraw()` reverts when the owner does not have
     *         enough shares to cover the requested asset amount.
     */
    function test_withdraw_RevertsIfAssetsExceedAvailableShares() external {
        _deposit(user1, depositAmt);

        vm.expectRevert(ERC4626.InsufficientShares.selector);
        _withdraw(600);
    }

    /**
     * @notice Verifies that an unauthorized caller cannot withdraw assets
     *         from another user's share balance.
     * @dev The caller has no allowance from the share owner, so the operation
     *      must revert with `ERC20InsufficientAllowance`.
     */
    function test_withdraw_RevertsIfCallerIsNotAllowed() external {
        _deposit(user1, depositAmt);
        uint256 sharesBal = tokenVault.previewWithdraw(withdrawlAmt);

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, user2, 0, sharesBal));

        tokenVault.withdraw(withdrawlAmt, user1, user1);
    }

    /**
     * @notice Verifies that an approved spender can withdraw assets on behalf
     *         of the share owner.
     */
    function test_withdraw_AllowsApprovedSpenderToWithdraw() external {
        _deposit(user1, depositAmt);
        uint256 shares = tokenVault.previewWithdraw(withdrawlAmt);

        uint256 sharesBalBefore = tokenVault.balanceOf(user1);

        vm.prank(user1);
        tokenVault.approve(operator, shares);

        vm.prank(operator);
        tokenVault.withdraw(withdrawlAmt, user2, user1);

        uint256 sharesBalAfter = tokenVault.balanceOf(user1);

        assertEq(sharesBalBefore - sharesBalAfter, shares);
        assertEq(tokenVault.totalAssets(), 100);
    }

    /**
     * @notice Verifies that `withdraw()` emits the expected ERC4626 `Withdraw`
     *         event with the correct owner, receiver, assets, and shares.
     */
    function test_withdraw_EmitsWithdrawEvent() external {
        _deposit(user1, depositAmt);

        vm.expectEmit(true, true, true, true);
        emit IERC4626.Withdraw(user1, user1, user1, withdrawlAmt, tokenVault.previewWithdraw(withdrawlAmt));
        _withdraw(withdrawlAmt);
    }

    /**
     * @notice Verifies that `redeem()` burns exactly the requested number of
     *         shares and transfers the corresponding assets.
     */
    function test_redeem_BurnsExactAmountOfShares() external {
        _deposit(user1, depositAmt);

        uint256 userSharesBefore = tokenVault.balanceOf(user1);
        uint256 redeemAmt = redeemAmt * 10 ** 3;

        _redeem(redeemAmt);

        uint256 userSharesAfter = tokenVault.balanceOf(user1);

        assertEq(userSharesBefore - userSharesAfter, redeemAmt);
        assertEq(tokenVault.totalAssets(), 100);
    }

    /**
     * @notice Verifies that `redeem()` reverts when the receiver is the
     *         zero address.
     */
    function test_redeem_RevertsIfReceiverIsZeroAddress() external {
        _deposit(user1, depositAmt);

        vm.prank(user1);
        vm.expectRevert(ERC4626.ZeroAddressNotAllowed.selector);

        tokenVault.redeem(redeemAmt, address(0), user1);
    }

    /**
     * @notice Verifies that `redeem()` reverts when the owner is the
     *         zero address.
     */
    function test_redeem_RevertsIfOwnerIsZeroAddress() external {
        _deposit(user1, depositAmt);

        vm.prank(user1);
        vm.expectRevert(ERC4626.ZeroAddressNotAllowed.selector);

        tokenVault.redeem(redeemAmt, user2, address(0));
    }

    /**
     * @notice Verifies that an unauthorized caller cannot redeem another
     *         user's shares without sufficient allowance.
     */
    function test_redeem_RevertsIfCallerIsNotApproved() external {
        _deposit(user1, depositAmt);

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, user2, 0, redeemAmt));

        tokenVault.redeem(redeemAmt, user1, user1);
    }

    /**
     * @notice Verifies that an approved spender can redeem shares on behalf
     *         of the share owner.
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
     * @notice Verifies that a direct asset donation changes the vault's
     *         asset/share conversion rate.
     * @dev A direct transfer of the underlying asset increases the vault's
     *      asset balance without minting additional shares. As a result,
     *      subsequent conversions use a different exchange rate.
     */
    function test_exchangeRate_ChangesAfterAssetDonation() external {
        // Before any deposits, verify the initial conversion rate.
        uint256 shares = tokenVault.convertToShares(1000);

        assertEq(shares, 1_000_000);

        // ---------------------------------------------------------------------
        // Initial deposit.
        //
        // 1,000 assets are deposited and shares are minted according to
        // the initial exchange rate.
        // ---------------------------------------------------------------------
        _deposit(user1, 1000);

        assertEq(tokenVault.convertToShares(1000), 1_000_000);

        // ---------------------------------------------------------------------
        // Second deposit.
        //
        // Another 500 assets are deposited. Since assets and shares increase
        // proportionally, the conversion rate remains unchanged.
        // ---------------------------------------------------------------------
        _deposit(user2, 500);

        assertEq(tokenVault.convertToShares(500), 500_000);

        // ---------------------------------------------------------------------
        // Direct asset donation.
        //
        // user2 transfers 500 assets directly to the vault. No shares are
        // minted because this transfer does not call `deposit()`.
        //
        // Before donation:
        //      totalAssets = 1,500
        //      totalSupply = 1,500,000
        //
        // After donation:
        //      totalAssets = 2,000
        //      totalSupply = 1,500,000
        //
        // Therefore, the exchange rate changes.
        // ---------------------------------------------------------------------
        vm.prank(user2);
        usdt.transfer(address(tokenVault), 500);

        // 250 assets now convert to fewer shares because the vault contains
        // additional assets that are not represented by additional shares.
        assertEq(tokenVault.convertToShares(250), 187_531);

        // The resulting shares convert back to 249 assets because
        // convertToAssets() rounds down.
        assertEq(tokenVault.convertToAssets(187_531), 249);
    }

    ///////////////////////////// INFLATION ATTACK /////////////////////////////

    /**
     * @notice Verifies that a direct asset donation cannot cause a subsequent
     *         depositor to lose their deposited assets through an ERC-4626
     *         inflation attack.
     * @dev The test simulates an attacker depositing a minimal amount of assets
     *      and then donating additional assets directly to the vault. Because the
     *      donation does not mint shares, it changes the vault's asset/share ratio.
     *
     *      A victim then deposits assets after the donation. The vault's virtual
     *      assets, virtual shares, and decimal offset prevent the attacker from
     *      manipulating share issuance to the point where the victim receives
     *      zero shares.
     *
     *      The test verifies that:
     *      - The donation increases totalAssets without increasing totalSupply.
     *      - The victim receives a non-zero number of shares.
     *      - The victim can redeem their shares for the assets represented by them.
     *      - The attacker can redeem only their own shares and cannot redeem the
     *        victim's shares or assets.
     */
    function test_inflationAttack_DonationDoesNotStealVictimDeposit() external {
        // -------------------------------------------------------------------------
        // 1. Attacker makes the initial deposit.
        //
        // The attacker deposits only 1 asset. Because this vault uses a decimal
        // offset, 1 asset corresponds to 1,000 shares in the initial exchange
        // calculation.
        // -------------------------------------------------------------------------
        _deposit(hacker, 1);

        uint256 hackerShares = tokenVault.balanceOf(hacker);

        assertEq(hackerShares, 1_000);

        // -------------------------------------------------------------------------
        // 2. Attacker directly donates assets to the vault.
        //
        // The transfer does not go through deposit(), so no shares are minted.
        // Only the vault's underlying asset balance increases.
        //
        // Therefore:
        //      totalAssets  -> increases from 1 to 1,001
        //      totalSupply  -> remains 1,000
        //      hackerShares -> remains 1,000
        //
        // This is the mechanism exploited by an ERC-4626 inflation attack:
        // an attacker attempts to manipulate the asset/share ratio by donating
        // assets before another user deposits.
        // -------------------------------------------------------------------------
        vm.prank(hacker);
        usdt.transfer(address(tokenVault), 1_000);

        // A direct donation must not mint additional shares.
        assertEq(tokenVault.balanceOf(hacker), hackerShares);

        // The donated assets are now part of the vault's total asset balance.
        assertEq(tokenVault.totalAssets(), 1_001);

        // Since the donation was not a deposit, the total share supply is unchanged.
        assertEq(tokenVault.totalSupply(), 1_000);

        // -------------------------------------------------------------------------
        // 3. Victim deposits after the donation.
        //
        // The victim is depositing into a vault whose asset/share ratio has been
        // affected by the attacker's donation.
        //
        // The inflation-attack mitigation must ensure that the victim still
        // receives a meaningful share balance instead of rounding down to zero.
        // -------------------------------------------------------------------------
        _deposit(user1, 500);

        uint256 victimShares = tokenVault.balanceOf(user1);

        // A successful inflation attack would attempt to make the victim receive
        // zero shares for their deposit. The mitigation must prevent that.
        assertGt(victimShares, 0);

        // This is the expected result for the current virtual asset/share and
        // decimal-offset configuration of the vault.
        assertEq(victimShares, 998);

        // -------------------------------------------------------------------------
        // 4. Calculate the assets represented by the victim's shares.
        //
        // previewRedeem() performs the same conversion used by redeem() without
        // changing the vault's state.
        // -------------------------------------------------------------------------
        uint256 victimAssets = tokenVault.previewRedeem(victimShares);

        uint256 victimBalanceBefore = usdt.balanceOf(user1);

        // -------------------------------------------------------------------------
        // 5. Victim redeems all of their shares.
        //
        // The victim should receive the assets represented by their shares.
        // -------------------------------------------------------------------------
        vm.prank(user1);

        uint256 victimAssetsReceived = tokenVault.redeem(victimShares, user1, user1);

        uint256 victimBalanceAfter = usdt.balanceOf(user1);

        // redeem() should return the same amount calculated by previewRedeem().
        assertEq(victimAssetsReceived, victimAssets);

        // Confirm that the victim's actual asset balance increased by the
        // expected redemption amount.
        assertEq(victimBalanceAfter - victimBalanceBefore, victimAssets);

        // -------------------------------------------------------------------------
        // 6. Attacker redeems their own shares.
        //
        // The attacker can redeem the shares they originally received, but they
        // must not be able to redeem the victim's shares or otherwise claim the
        // victim's deposited assets.
        // -------------------------------------------------------------------------
        uint256 hackerBalanceBefore = usdt.balanceOf(hacker);

        uint256 hackerAssets = tokenVault.previewRedeem(hackerShares);

        vm.prank(hacker);

        uint256 hackerAssetsReceived = tokenVault.redeem(hackerShares, hacker, hacker);

        uint256 hackerBalanceAfter = usdt.balanceOf(hacker);

        // redeem() should return the amount predicted by previewRedeem().
        assertEq(hackerAssetsReceived, hackerAssets);

        // Confirm that the attacker received only the assets represented by
        // their own shares.
        assertEq(hackerBalanceAfter - hackerBalanceBefore, hackerAssets);
    }
}
