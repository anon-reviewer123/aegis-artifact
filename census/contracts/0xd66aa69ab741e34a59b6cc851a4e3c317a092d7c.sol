/**
 *Submitted for verification at Etherscan.io on 2024-12-10
*/

/**
 *Submitted for verification at Etherscan.io on 2024-11-05
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SafeMath {
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}
library StringUtils {
    function toString(bytes32 data) internal pure returns (string memory) {
        bytes memory bytesString = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            bytesString[i * 2] = _char(bytes1(uint8(data[i]) >> 4));
            bytesString[1 + i * 2] = _char(bytes1(uint8(data[i]) & 0x0f));
        }
        return string(bytesString);
    }

    function _char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) {
            return bytes1(uint8(b) + 0x30);
        } else {
            return bytes1(uint8(b) + 0x57);
        }
    }

    function substring(string memory str, uint startIndex, uint endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }
}
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
   
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library Address {
    function sendValue(address payable recipient, uint256 amount) internal returns(bool){
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        return success;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) internal _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;


    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
            unchecked {
                _approve(sender, _msgSender(), currentAllowance - amount);
            }
        }

        _transfer(sender, recipient, amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /*
    * @notice Creates new tokens and adds them to the specified account.
    * @dev The function creates a specified amount of tokens and adds them to the specified account, increasing the total supply accordingly.
    * @param account The account to which the tokens will be minted.
    * @param amount The amount of tokens to be minted.
    * @return It emits a Transfer event indicating the minting of tokens from the zero address to the specified account.
    */ 
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /*
    * @notice Burns a specific amount of tokens from the specified account.
    * @dev The function reduces the balance of the specified account by the specified amount and decreases the total supply accordingly.
    * @param account The account from which the tokens will be burned.
    * @param amount The amount of tokens to be burned.
    * @return It emits a Transfer event indicating the burning of tokens from the account to the zero address.
    */ 
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }


    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /*
    * @notice Hook that is called before transferring tokens.
    * @dev This function is called before transferring tokens from one account to another.
    * @param from The account from which the tokens are being transferred.
    * @param to The account to which the tokens are being transferred.
    * @param amount The amount of tokens being transferred.
    */ 
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

interface ITBCNFT{
    function mint(address to, uint256 quantity, uint8 level) external;
}

contract TBC is ERC20, Ownable {
    using SafeMath for uint256;
    uint256 private  mintAmount = 250000 * 10**uint256(decimals());
    uint256 private constant mintETHAmount = 0.1 ether;
    bool public publicSaleEnabled = false;
    mapping(address => uint256) private userETHDeposits; // Record the accumulated amount of ETH deposited by users

    uint256[] private rewardThresholds = [0.1 ether, 0.2 ether, 0.3 ether, 0.4 ether]; // reward threshold
    uint256[] private rewardAmounts = [125000, 625000, 2500000, 6000000]; // Corresponding number of reward tokens
    mapping(address => uint256) private claimedRewards; // Record the total amount of rewards that the user has received
    // User reward collection record: User address -> Reward level -> Whether it has been received
    mapping(address => mapping(uint8 => bool)) private rewardMinted;
    ITBCNFT public TBCNFTContract;
    uint256 private eventCounter; 

    event CreativeEnergy(uint256 indexed  eventId, address indexed  sender, uint256 indexed  value);

    constructor () ERC20("TeeB", "TBC") 
    {   
        _mint(address(this), 1e10 * (10 ** decimals()));
       eventCounter = 0; 
    }

    receive() external payable {}

  

    function mint() external payable {
        require(!publicSaleEnabled, "Public sale has ended");
        require(owner() != address(0), "Owner address is zero, operation not allowed");
        require(msg.value >= mintETHAmount, "Insufficient ETH sent");

        // Dynamically calculate the number of tokens a user deserves
        uint256 mintQuantity = msg.value.mul(mintAmount).div(mintETHAmount);
        address contractAddress = address(this);
        require(balanceOf(contractAddress) >= mintQuantity, "Owner does not have enough tokens");
        // Transfer tokens from owner to user
        super._transfer(contractAddress, msg.sender, mintQuantity);

        // Update the user's cumulative deposit amount
        userETHDeposits[msg.sender] = userETHDeposits[msg.sender].add(msg.value);
        // Check whether the reward threshold is reached and issue the reward
        checkAndReward(msg.sender);
        eventCounter++;
        emit CreativeEnergy(eventCounter, msg.sender, msg.value);
    }

    function checkAndReward(address user) internal {
        uint256 totalReward = 0; // Total token rewards currently due
        uint256 userDeposit = userETHDeposits[user]; // Accumulated deposits of users
        // Traverse reward levels
        for (uint8 level = 1; level <= 4; level++) {
            uint256 threshold = rewardThresholds[level - 1];
            uint256 reward = rewardAmounts[level - 1] * (10**decimals());
            // Check if the reward level is reached
            if (userDeposit >= threshold) {
                // Update token rewards
                totalReward = reward;
                // Check if mint method needs to be called
                if (address(TBCNFTContract) != address(0)) {
                    if (!rewardMinted[user][level]) {
                        rewardMinted[user][level] = true; // Mark the reward for this level as received
                        TBCNFTContract.mint(user, 1, level); // Call NFT mint method
                    }
                }
            } else {
                break; // User deposit is not enough to reach the next level
            }
        }

        // Check the total amount of token rewards claimed
        uint256 claimedReward = claimedRewards[user];

        // If the total token reward is greater than the received reward, the difference will be reissued
        if (totalReward > claimedReward) {
            address contractAddress = address(this);
            uint256 rewardToSend = totalReward - claimedReward; // Calculate the difference
            require(balanceOf(contractAddress) >= rewardToSend, "Owner does not have enough tokens for rewards");
            claimedRewards[user] = totalReward; // Update the total amount of rewards claimed
            super._transfer(contractAddress, user, rewardToSend); // Issue token rewards
        }
    }


    function setNftContract(address _contract) external onlyOwner {
        TBCNFTContract = ITBCNFT(_contract);
    }

    
    function sendAirdrops(address[] memory recipients, uint256 amount) external onlyOwner{
        require(owner() != address(0), "Owner address is zero, operation not allowed");
        for (uint i = 0; i < recipients.length; i++) {
            super._transfer(address(this), recipients[i], amount);
        }
    }

    function endedPublicSaleEnabled() external onlyOwner{
        require(!publicSaleEnabled, "Public sale has ended");
        publicSaleEnabled = true;
    }

    function isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function _transfer(address from,address to,uint256 amount) internal  override {
        require(from != address(0), "ERC20: transfer from the zero address");
        
        if (isContract(to) && !publicSaleEnabled) {
            revert("Only the owner can add liquidity before public sale ends.");
        }

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        super._transfer(from, to, amount);
    }
   
    function claimStuckTokens(address token, uint256 amount) external onlyOwner {
        require(token != address(this), "Owner cannot claim contract's balance of its own tokens");
        
        if (token == address(0)) {
            require(amount <= address(this).balance, "Insufficient contract balance");
            payable(msg.sender).transfer(amount);
            return;
        }

        IERC20 ERC20token = IERC20(token);
        uint256 contractBalance = ERC20token.balanceOf(address(this));
        require(amount <= contractBalance, "Insufficient token balance in contract");
        ERC20token.transfer(msg.sender, amount);
    }
    
}