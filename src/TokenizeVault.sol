// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC20, IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title TokenizeVault
 * @notice ERC-4626 tokenized vault implementation.
 * @dev Deposited assets are held directly by this contract.
 */
contract TokenizeVault is ERC20, IERC4626 {
    IERC20 private immutable s_asset;

    uint8 private immutable underlyingDecimals;

    using Math for uint256;

    /// @notice The provided asset address is invalid.
    error InvalidAssetAddress();

    /// @notice The provided address is the zero address.
    error ZeroAddressNotAllowed();

    /// @notice The requested amount exceeds the maximum allowed amount.
    error AmountGreaterThanMaxAmount();

    /// @notice The requested share amount is insufficient.
    error InsufficientShares();

    /**
     * @notice Initializes the vault with an underlying asset.
     * @param asset_ Address of the ERC-20 token accepted by the vault.
     */
    constructor(address asset_) ERC20("FomoBlock", "FBCK") {
        if (asset_ == address(0)) revert InvalidAssetAddress();

        s_asset = IERC20(asset_);

        (bool success, uint8 assetDecimals) = SafeERC20.tryGetDecimals(s_asset);
        underlyingDecimals = success ? assetDecimals : 18;
    }

    /**
     * @inheritdoc IERC20Metadata
     */
    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return underlyingDecimals + _decimalsOffset();
    }

    function _decimalsOffset() internal pure returns (uint8) {
        return 3;
    }

    /**
     * @inheritdoc IERC4626
     */
    function asset() external view returns (address) {
        return address(s_asset);
    }

    /**
     * @inheritdoc IERC4626
     */
    function totalAssets() public view returns (uint256) {
        return s_asset.balanceOf(address(this));
    }

    /**
     * @inheritdoc IERC4626
     */
    function convertToAssets(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /**
     * @inheritdoc IERC4626
     */
    function convertToShares(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /**
     * @inheritdoc IERC4626
     */
    function maxDeposit(
        address /* receiver */
    )
        public
        pure
        returns (uint256 maxAssets)
    {
        return type(uint128).max;
    }

    /**
     * @inheritdoc IERC4626
     */
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /**
     * @inheritdoc IERC4626
     */
    function maxMint(
        address /* receiver */
    )
        public
        pure
        returns (uint256)
    {
        return type(uint128).max;
    }

    /**
     * @inheritdoc IERC4626
     */
    function previewMint(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    /**
     * @inheritdoc IERC4626
     */
    function maxWithdraw(address owner) public view returns (uint256) {
        return previewRedeem(maxRedeem(owner));
    }

    /**
     * @inheritdoc IERC4626
     */
    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    /**
     * @inheritdoc IERC4626
     */
    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf(owner);
    }

    /**
     * @inheritdoc IERC4626
     */
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /**
     * @notice Converts vault shares into underlying assets.
     * @dev Uses the current asset-to-share exchange rate.
     *      When the vault is empty, shares and assets are treated
     *      as having a 1:1 ratio.
     * @param shares Amount of vault shares.
     * @param rounding Rounding direction used for the conversion.
     * @return assets Amount of underlying assets corresponding to the shares.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view returns (uint256 assets) {
        assets = shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    /**
     * @notice Converts underlying assets into vault shares.
     * @dev Uses the current asset-to-share exchange rate.
     *      When the vault is empty, assets and shares are treated
     *      as having a 1:1 ratio.
     * @param assets Amount of underlying assets.
     * @param rounding Rounding direction used for the conversion.
     * @return shares Amount of vault shares corresponding to the assets.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view returns (uint256 shares) {
        shares = assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    /**
     * @inheritdoc IERC4626
     */
    function deposit(uint256 assets, address receiver) external returns (uint256) {
        if (receiver == address(0)) revert ZeroAddressNotAllowed();
        if (assets > maxDeposit(receiver)) revert AmountGreaterThanMaxAmount();

        uint256 shares = previewDeposit(assets);

        SafeERC20.safeTransferFrom(s_asset, msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, address(this), assets, shares);

        return shares;
    }

    /**
     * @inheritdoc IERC4626
     */
    function mint(uint256 shares, address receiver) external returns (uint256) {
        if (receiver == address(0)) revert ZeroAddressNotAllowed();
        if (shares > maxMint(receiver)) revert AmountGreaterThanMaxAmount();

        uint256 assets = previewMint(shares);

        SafeERC20.safeTransferFrom(s_asset, msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, address(this), assets, shares);

        return assets;
    }

    /**
     * @inheritdoc IERC4626
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256) {
        if (receiver == address(0) || owner == address(0)) revert ZeroAddressNotAllowed();
        if (assets > maxWithdraw(owner)) revert InsufficientShares();

        uint256 shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burn(owner, shares);

        SafeERC20.safeTransfer(s_asset, receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return shares;
    }

    /**
     * @inheritdoc IERC4626
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256) {
        if (receiver == address(0) || owner == address(0)) revert ZeroAddressNotAllowed();
        if (shares > maxRedeem(owner)) revert InsufficientShares();

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        uint256 assets = previewRedeem(shares);

        _burn(owner, shares);

        SafeERC20.safeTransfer(s_asset, receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return assets;
    }
}
