pragma solidity 0.5.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/roles/WhitelistAdminRole.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./KIP7Extendable.sol";

contract QTBK is ERC20Detailed, KIP7Extendable, ERC20Pausable, ERC20Burnable, Ownable, WhitelistAdminRole {
    using SafeMath for uint256;

    struct LockInfo {
        uint256 releaseTime;
        uint256 amount;
    }

    mapping (address => LockInfo[]) private _timelockList;

    mapping (address => bool) private _frozenAccount;

    event Lock(address indexed owner, uint256 amount, uint256 releaseTime);
    event Unlock(address indexed owner, uint256 amount);
    event Freeze(address indexed owner);
    event Unfreeze(address indexed owner);

    modifier notFrozen(address owner) {
        require(!_frozenAccount[owner]);
        _;
    }

    modifier onlyAdminOrOwner() {
        require(isWhitelistAdmin(_msgSender()) || isOwner());
        _;
    }

    constructor() ERC20Detailed("Quantbook Token", "QTBK", 18) public {
        _mint(_msgSender(), 1000000000 ether);
    }

    function transfer(address to, uint256 amount) public notFrozen(_msgSender()) returns (bool) {
        uint256 lockAmount = _autoUnlockAndReturnRemainLockAmount(_msgSender());
        require(amount <= balanceOf(_msgSender()).sub(lockAmount), "Not enough balance");

        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public notFrozen(from) returns (bool) {
        uint256 lockAmount = _autoUnlockAndReturnRemainLockAmount(from);
        require(amount <= balanceOf(from).sub(lockAmount), "Not enough balance");

        return super.transferFrom(from, to, amount);
    }

    function freezeAccount(address owner) public onlyAdminOrOwner returns (bool) {
        require(owner != super.owner());
        require(!_frozenAccount[owner]);

        _frozenAccount[owner] = true;
        emit Freeze(owner);
        return true;
    }

    function unfreezeAccount(address owner) public onlyAdminOrOwner returns (bool) {
        require(_frozenAccount[owner]);

        _frozenAccount[owner] = false;
        emit Unfreeze(owner);
        return true;
    }

    function lock(address owner, uint256 amount, uint256 releaseTime) public onlyAdminOrOwner returns (bool) {
        require(amount <= balanceOf(owner), "not enough balance");
        require(releaseTime > block.timestamp, "releaseTime should not be past");

        _lock(owner, amount, releaseTime);
        return true;
    }

    function unlock(address owner, uint256 idx) public onlyAdminOrOwner returns (bool) {
        require(_timelockList[owner].length > idx, "no lock info");

        _unlock(owner, idx);
        return true;
    }

    function transferWithLock(address owner, uint256 amount, uint256 releaseTime) public onlyAdminOrOwner returns (bool) {
        _transfer(msg.sender, owner, amount);
        _lock(owner, amount, releaseTime);
        return true;
    }

    function timelockList(address owner, uint256 index) public view returns (LockInfo memory) {
        return _timelockList[owner][index];
    }

    function frozenAccount(address owner) public view returns (bool) {
        return _frozenAccount[owner];
    }

    function _lock(address owner, uint256 amount, uint256 releaseTime) internal {
        _timelockList[owner].push(LockInfo(releaseTime, amount));

        emit Lock(owner, amount, releaseTime);
    }

    function _unlock(address owner, uint256 idx) internal {
        LockInfo storage lockInfo = _timelockList[owner][idx];
        uint256 releaseAmount = lockInfo.amount;

        uint256 lastIndex = _timelockList[owner].length - 1;
        _timelockList[owner][idx] = _timelockList[owner][lastIndex];
        _timelockList[owner].length--;

        emit Unlock(owner, releaseAmount);
    }

    function _autoUnlockAndReturnRemainLockAmount(address owner) internal returns (uint256) {
        uint256 remains;
        for(uint256 idx=0; idx<_timelockList[owner].length; idx++) {
            if (_timelockList[owner][idx].releaseTime <= block.timestamp) {
                _unlock(owner, idx);
                // If lockupInfo was deleted, loop restart at same position.
                idx -= 1;
            } else {
                remains += _timelockList[owner][idx].amount;
            }
        }
        return remains;
    }
}
