// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockAsset
 * @notice Mock ERC20 token used as the underlying asset for testing.
 * @dev Uses 8 decimals to simulate an asset such as USDT.
 */
contract MockAsset is ERC20 {
    /**
     * @notice Initializes the mock asset with the name "US Dollar"
     *         and symbol "USDT".
     */
    constructor() ERC20("US Dollar", "USDT") {}

    /**
     * @notice Mints tokens to a specified account.
     * @dev This function is intentionally unrestricted because the contract
     *      is intended only for testing purposes.
     * @param account Address that will receive the newly minted tokens.
     * @param value Amount of tokens to mint.
     */
    function mint(address account, uint256 value) external {
        _mint(account, value);
    }

    /**
     * @notice Returns the number of decimals used by the token.
     * @return Number of decimals, which is 8.
     */
    function decimals() public pure override returns (uint8) {
        return 8;
    }
}

