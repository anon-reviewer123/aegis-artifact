// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * FLATTENED CONTRACT FOR REMIX DEPLOYMENT - ETHEREUM MAINNET
 * 
 * DEPLOYMENT ADDRESSES:
 * Router: 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D
 * LINK: 0x514910771AF9Ca656af840dff83E8264EcF986CA
 * DEGEN: 0x420658a1d8b8f5c36ddaf1bb828f347ba9011969
 * Soneium Chain Selector: 12505351618335765396
 */

// OpenZeppelin Contracts (last updated v4.8.3)
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract OwnerIsCreator is Ownable {}

// Chainlink CCIP Interfaces and Libraries
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface LinkTokenInterface {
    function allowance(address owner, address spender) external view returns (uint256 remaining);
    function approve(address spender, uint256 value) external returns (bool success);
    function balanceOf(address owner) external view returns (uint256 balance);
    function decimals() external view returns (uint8 decimalPlaces);
    function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);
    function increaseApproval(address spender, uint256 subtractedValue) external;
    function name() external view returns (string memory tokenName);
    function symbol() external view returns (string memory tokenSymbol);
    function totalSupply() external view returns (uint256 totalTokensIssued);
    function transfer(address to, uint256 value) external returns (bool success);
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);
    function transferFrom(address from, address to, uint256 value) external returns (bool success);
}

library Client {
    struct EVMTokenAmount {
        address token;
        uint256 amount;
    }

    struct Any2EVMMessage {
        bytes32 messageId;
        uint64 sourceChainSelector;
        bytes sender;
        bytes data;
        EVMTokenAmount[] tokenAmounts;
    }

    struct EVM2AnyMessage {
        bytes receiver;
        bytes data;
        EVMTokenAmount[] tokenAmounts;
        address feeToken;
        bytes extraArgs;
    }

    struct EVMExtraArgsV1 {
        uint256 gasLimit;
    }

    function _argsToBytes(EVMExtraArgsV1 memory extraArgs) internal pure returns (bytes memory bts) {
        return abi.encodeWithSelector(0x97a657c9, extraArgs);
    }
}

interface IRouterClient {
    error UnsupportedDestinationChain(uint64 destinationChainSelector);
    error InsufficientFeeTokenAmount();
    error InvalidMsgValue();

    function isChainSupported(uint64 destinationChainSelector) external view returns (bool supported);
    function getSupportedTokens(uint64 destinationChainSelector) external view returns (address[] memory tokens);
    function getFee(uint64 destinationChainSelector, Client.EVM2AnyMessage memory message) external view returns (uint256 fee);
    function ccipSend(uint64 destinationChainSelector, Client.EVM2AnyMessage memory message) external payable returns (bytes32);
}

interface IAny2EVMMessageReceiver {
    function ccipReceive(Client.Any2EVMMessage calldata message) external;
}

abstract contract CCIPReceiver is IAny2EVMMessageReceiver {
    address private immutable i_router;    constructor(address router) {
        if (router == address(0)) revert InvalidRouter(address(0));
        i_router = router;
    }

    function getRouter() public view virtual returns (address) {
        return address(i_router);
    }

    function ccipReceive(Client.Any2EVMMessage calldata message) external virtual override onlyRouter {
        _ccipReceive(message);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal virtual;

    modifier onlyRouter() {
        if (msg.sender != i_router) revert InvalidRouter(msg.sender);
        _;
    }

    error InvalidRouter(address router);
}

/**
 * @title UpgradeableCCIPTokenBridge
 * @dev SECURE HYBRID: Technical upgrades allowed, but FUND WITHDRAWAL PERMANENTLY BLOCKED
 */
contract UpgradeableCCIPTokenBridge is CCIPReceiver, OwnerIsCreator {
    // Custom errors
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
    error DestinationChainNotAllowlisted(uint64 destinationChainSelector);
    error SourceChainNotAllowlisted(uint64 sourceChainSelector);
    error SenderNotAllowlisted(address sender);
    error InvalidReceiverAddress();
    error TransferFailed();
    error FundWithdrawalForeverBlocked();
    error ChangeNotYetAllowed(uint256 timeRemaining);
    error InvalidAddress();

    // Events for full transparency
    event TokensLocked(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address indexed user,
        address receiver,
        uint256 amount,
        uint256 fees
    );

    event TokensUnlocked(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address indexed receiver,
        uint256 amount
    );

    // Technical update events (community can monitor)
    event RouterUpdateProposed(address newRouter, uint256 executeAfter);
    event RouterUpdated(address oldRouter, address newRouter);
    event GasLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event ChainConfigUpdated(uint64 chainSelector, bool allowed);
    event SenderConfigUpdated(address sender, bool allowed);

    // State variables
    IERC20 private immutable s_degenToken; // IMMUTABLE - Cannot be changed
    LinkTokenInterface private s_linkToken;

    // Technical configuration (upgradeable for Chainlink updates)
    address private s_router;
    uint256 private s_gasLimit = 200_000;

    // Access control mappings
    mapping(uint64 => bool) public allowlistedDestinationChains;
    mapping(uint64 => bool) public allowlistedSourceChains;
    mapping(address => bool) public allowlistedSenders;

    // Fund tracking (immutable logic)
    mapping(address => mapping(uint64 => uint256)) public lockedBalances;
    uint256 public totalLocked;

    // Time delay for critical changes (24 hours)
    uint256 private constant CHANGE_DELAY = 24 hours;
    
    // Pending router change
    address private pendingRouter;
    uint256 private routerChangeTime;

    modifier onlyAllowlistedDestinationChain(uint64 _destinationChainSelector) {
        if (!allowlistedDestinationChains[_destinationChainSelector])
            revert DestinationChainNotAllowlisted(_destinationChainSelector);
        _;
    }

    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        if (!allowlistedSourceChains[_sourceChainSelector])
            revert SourceChainNotAllowlisted(_sourceChainSelector);
        if (!allowlistedSenders[_sender])
            revert SenderNotAllowlisted(_sender);        _;
    }

    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) revert InvalidReceiverAddress();
        _;
    }

    constructor(
        address _router,
        address _degenToken
    ) CCIPReceiver(_router) {
        s_router = _router;
        s_degenToken = IERC20(_degenToken); // IMMUTABLE
    }

    /**
     * @notice Lock DEGEN tokens and bridge to destination chain
     */
    function lockAndSendTokens(
        uint64 _destinationChainSelector,
        address _receiver,
        uint256 _amount
    )
        external
        onlyAllowlistedDestinationChain(_destinationChainSelector)
        validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        // IMMUTABLE FUND LOGIC - Cannot be changed by owner
        bool success = s_degenToken.transferFrom(msg.sender, address(this), _amount);
        if (!success) revert TransferFailed();

        // Update immutable tracking        lockedBalances[msg.sender][_destinationChainSelector] += _amount;
        totalLocked += _amount;

        // Build CCIP message with current technical config (using native ETH)
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _amount,
            address(0) // Use native ETH instead of LINK
        );

        // Send via current router
        IRouterClient router = IRouterClient(s_router);
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > address(this).balance)
            revert NotEnoughBalance(address(this).balance, fees);

        messageId = router.ccipSend{value: fees}(_destinationChainSelector, evm2AnyMessage);

        emit TokensLocked(
            messageId,
            _destinationChainSelector,
            msg.sender,
            _receiver,
            _amount,
            fees
        );

        return messageId;
    }

    /**
     * @notice Receive messages from other chains and unlock tokens
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyAllowlisted(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        )
    {
        bytes32 messageId = any2EvmMessage.messageId;
        uint64 sourceChainSelector = any2EvmMessage.sourceChainSelector;
        address sender = abi.decode(any2EvmMessage.sender, (address));
        
        (address receiver, uint256 amount) = abi.decode(any2EvmMessage.data, (address, uint256));

        // IMMUTABLE FUND LOGIC - Transfer tokens to user
        bool success = s_degenToken.transfer(receiver, amount);
        if (!success) revert TransferFailed();

        // Update tracking (cannot be manipulated)
        if (totalLocked >= amount) {
            totalLocked -= amount;
        }

        emit TokensUnlocked(messageId, sourceChainSelector, receiver, amount);
    }

    // TECHNICAL UPDATES (Owner only, transparent)
    function proposeRouterUpdate(address _newRouter) external onlyOwner {
        if (_newRouter == address(0)) revert InvalidAddress();
        
        pendingRouter = _newRouter;
        routerChangeTime = block.timestamp + CHANGE_DELAY;
        
        emit RouterUpdateProposed(_newRouter, routerChangeTime);
    }

    function executeRouterUpdate() external onlyOwner {
        if (block.timestamp < routerChangeTime) {
            revert ChangeNotYetAllowed(routerChangeTime - block.timestamp);
        }
        if (pendingRouter == address(0)) revert InvalidAddress();

        address oldRouter = s_router;
        s_router = pendingRouter;
        
        pendingRouter = address(0);
        routerChangeTime = 0;

        emit RouterUpdated(oldRouter, s_router);
    }

    function updateGasLimit(uint256 _newGasLimit) external onlyOwner {
        require(_newGasLimit >= 100_000 && _newGasLimit <= 2_000_000, "Invalid gas limit");
        
        uint256 oldLimit = s_gasLimit;
        s_gasLimit = _newGasLimit;
        
        emit GasLimitUpdated(oldLimit, _newGasLimit);
    }

    function updateLinkToken(address _newLink) external onlyOwner {
        if (_newLink == address(0)) revert InvalidAddress();
        s_linkToken = LinkTokenInterface(_newLink);
    }

    // CONFIGURATION MANAGEMENT
    function allowlistDestinationChain(uint64 _chainSelector, bool _allowed) external onlyOwner {
        allowlistedDestinationChains[_chainSelector] = _allowed;
        emit ChainConfigUpdated(_chainSelector, _allowed);
    }

    function allowlistSourceChain(uint64 _chainSelector, bool _allowed) external onlyOwner {
        allowlistedSourceChains[_chainSelector] = _allowed;
        emit ChainConfigUpdated(_chainSelector, _allowed);
    }

    function allowlistSender(address _sender, bool _allowed) external onlyOwner {
        allowlistedSenders[_sender] = _allowed;
        emit SenderConfigUpdated(_sender, _allowed);
    }

    // FUND PROTECTION (Permanently blocked)
    function withdrawUserFunds(address, uint256) external pure {
        revert FundWithdrawalForeverBlocked();
    }

    function withdrawDegen(address, uint256) external pure {
        revert FundWithdrawalForeverBlocked();
    }

    function emergencyUnlock(address, uint256) external pure {
        revert FundWithdrawalForeverBlocked();    }

    // UTILITY FUNCTIONS
    function _buildCCIPMessage(
        address _receiver,
        uint256 _amount,
        address _feeTokenAddress
    ) private view returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(0x1cb5B13d1e3FBB50466c3b3162DeCA1b7562027e), // Soneium wrapped token contract
                data: abi.encode(_receiver, _amount),
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: s_gasLimit})
                ),
                feeToken: _feeTokenAddress
            });
    }    function getRouter() public view override returns (address) {
        return s_router;
    }

    function withdrawLinkOnly(address _beneficiary, uint256 _amount) public onlyOwner {
        require(_beneficiary != address(0), "Invalid beneficiary");
        s_linkToken.transfer(_beneficiary, _amount);
    }

    function withdrawETH(address payable _beneficiary) public onlyOwner {
        require(_beneficiary != address(0), "Invalid beneficiary");
        _beneficiary.transfer(address(this).balance);
    }

    function fundContract() external payable {
        // Allow anyone to send ETH to fund the contract for gas fees
    }

    // VIEW FUNCTIONS
    function getLockedBalance(address _user, uint64 _destinationChain) external view returns (uint256) {
        return lockedBalances[_user][_destinationChain];
    }

    function getTotalLocked() external view returns (uint256) {
        return totalLocked;
    }

    function getCurrentGasLimit() external view returns (uint256) {
        return s_gasLimit;
    }

    function getPendingRouterChange() external view returns (address router, uint256 executeAfter) {
        return (pendingRouter, routerChangeTime);
    }

    receive() external payable {}
}