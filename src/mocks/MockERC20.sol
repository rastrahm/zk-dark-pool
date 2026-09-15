// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice ERC-20 minteable para tests del ShieldedVault.
 */
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MOCK") {}

    /**
     * @notice Mina tokens a `to`.
     * @param to Destinatario.
     * @param amount Cantidad.
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
