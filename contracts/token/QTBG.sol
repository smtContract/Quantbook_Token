pragma solidity 0.5.6;

import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

import "./KIP7Extendable.sol";

contract QTBG is ERC20Detailed, KIP7Extendable, ERC20Pausable, ERC20Burnable {
    constructor() public ERC20Detailed("Quantbook Governance", "QTBG", 18) {
        _mint(msg.sender, 10000000e18);
    }
}
