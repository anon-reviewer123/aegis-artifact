/**
 *Submitted for verification at Etherscan.io on 2021-03-22
*/

// SPDX-License-Identifier: UNLICENSED
//   _    _ _   _                __ _                            
//  | |  (_) | | |              / _(_)                           
//  | | ___| |_| |_ ___ _ __   | |_ _ _ __   __ _ _ __   ___ ___ 
//  | |/ / | __| __/ _ \ '_ \  |  _| | '_ \ / _` | '_ \ / __/ _ \
//  |   <| | |_| ||  __/ | | |_| | | | | | | (_| | | | | (_|  __/
//  |_|\_\_|\__|\__\___|_| |_(_)_| |_|_| |_|\__,_|_| |_|\___\___|
//
//  Kitten.Finance Lending
//
//  https://Kitten.Finance
//  https://kittenswap.org
//
pragma solidity ^0.6.12;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require (c >= a, "!!add");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require (b <= a, "!!sub");
        uint256 c = a - b;
        return c;
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require (b <= a, errorMessage);
        uint c = a - b;
        return c;
    }    
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require (c / a == b, "!!mul");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require (b > 0, "!!div");
        uint256 c = a / b;
        return c;
    }
}

////////////////////////////////////////////////////////////////////////////////

interface ERC20
{
    function balanceOf ( address account ) external view returns ( uint256 );
    function transfer ( address recipient, uint256 amount ) external returns ( bool );
    function transferFrom ( address sender, address recipient, uint256 amount ) external returns ( bool );
}

////////////////////////////////////////////////////////////////////////////////

contract KittenLending
{
    using SafeMath for uint;

    ////////////////////////////////////////////////////////////////////////////////
    
    address public govAddr;
    address public treasuryAddr;
    uint public treasuryAmtTotal = 0;
        
    constructor () public {
        govAddr = msg.sender;
        treasuryAddr = msg.sender;
    }
    
    modifier govOnly() {
    	require (msg.sender == govAddr, "!gov");
    	_;
    }
    address zero;
    function govTransferAddr(address newAddr) external govOnly {
    	require (newAddr != zero, "!addr");
    	govAddr = newAddr;
    }
    
    function govSetTreasury(address newAddr) external govOnly
    {
    	require(newAddr != zero, "!addr");
    	treasuryAddr = newAddr;
    }    
    
    uint public DEFAULT_devFeeBP = 0;
    
    function govSet_DEFAULT_devFeeBP(uint $DEFAULT_devFeeBP) external govOnly {
    	DEFAULT_devFeeBP = $DEFAULT_devFeeBP;
    }
    
    function govSet_devFeeBP(uint vaultId, uint $devFeeBP) external govOnly {
    	VAULT[vaultId].devFeeBP = $devFeeBP;
    }
    
    mapping (address => uint) public tokenStatus; // 0 = normal, if >= TOKEN_STATUS_BANNED then banned
    uint constant TOKEN_STATUS_BANNED = 1e60;
    uint constant VAULT_STATUS_BANNED = 200;
    
    function govSet_tokenStatus(address token, uint $tokenStatus) external govOnly {
    	tokenStatus[token] = $tokenStatus;
    }
    
    function govSet_vaultStatus(uint vaultId, uint $vaultStatus) external govOnly {
    	VAULT[vaultId].vaultStatus = $vaultStatus;
    }
    
    ////////////////////////////////////////////////////////////////////////////////

    struct VAULT_INFO 
    {
        address token;              // underlying token

        uint tEnd;                // timestamp
        uint priceEndScaled;     // scaled by PRICE_SCALE
        uint apyBP;               // APY%% in Basis Points
        uint devFeeBP;             // devFee%% in Basis Points
        
        uint vaultStatus;          // 0 = new, if >= VAULT_STATUS_BANNED then banned
        
        mapping (address => uint) share; // deposit ETH for vaultShare
        uint shareTotal;
        
        mapping (address => uint) tllll; // token locked
        uint tllllTotal;
        
        uint ethTotal;
    }

    uint constant PRICE_SCALE = 10 ** 18;

    VAULT_INFO[] public VAULT;
    
    event CREATE_VAULT(address indexed token, uint indexed vaultId, address indexed user, uint tEnd, uint priceEndScaled, uint apyBP);

    function createVault(address token, uint tEnd, uint priceEndScaled, uint apyBP) external 
    {
        VAULT_INFO memory m;
        require (token != zero, "!token");
        require (tokenStatus[token] < TOKEN_STATUS_BANNED, '!tokenBanned');
        require (tEnd > block.timestamp, "!tEnd");
        require (priceEndScaled > 0, "!priceEndScaled");
        require (apyBP > 0, "!apyBP");
    
        m.token = token;
    	m.tEnd = tEnd;
    	m.priceEndScaled = priceEndScaled;
        m.apyBP = apyBP;

    	m.devFeeBP = DEFAULT_devFeeBP;
    	
    	if (msg.sender == govAddr) {
    	    m.vaultStatus = 100;
    	}
    	
    	VAULT.push(m);
    	
    	// emit CREATE_VAULT(token, VAULT.length - 1, msg.sender, tEnd, priceEndScaled, apyBP);
    }
    
    ////////////////////////////////////////////////////////////////////////////////
    
    function vaultCount() external view returns (uint)
    {
        return VAULT.length;
    }
    
    function getVaultStatForUser(uint vaultId, address user) external view returns (uint share, uint tllll)
    {
        share = VAULT[vaultId].share[user];
        tllll = VAULT[vaultId].tllll[user];
    }
    
    ////////////////////////////////////////////////////////////////////////////////
    
    function getVaultValueInEth(uint vaultId) public view returns (uint)
    {
        VAULT_INFO memory m = VAULT[vaultId];
        
        uint priceNowScaled;
        if (block.timestamp >= m.tEnd)
            priceNowScaled = m.priceEndScaled;
        else {
            uint FACTOR = 10**18;
            priceNowScaled = (m.priceEndScaled) * FACTOR / (FACTOR + FACTOR * (m.apyBP) * (m.tEnd - block.timestamp) / (365 days) / 10000);
        }
        
        uint ethValue = m.ethTotal;
        uint tokenValue = (m.tllllTotal)*(priceNowScaled) / (PRICE_SCALE);
        
        return ethValue.add(tokenValue);
    }
    
    function getVaultPriceScaled(uint vaultId) public view returns (uint)
    {
        VAULT_INFO memory m = VAULT[vaultId];
        
        uint priceNowScaled;
        if (block.timestamp >= m.tEnd)
            priceNowScaled = m.priceEndScaled;
        else {
            uint FACTOR = 10**18;
            priceNowScaled = (m.priceEndScaled) * FACTOR / (FACTOR + FACTOR * (m.apyBP) * (m.tEnd - block.timestamp) / (365 days) / 10000);
        }
        
        return priceNowScaled;
    }
    
    ////////////////////////////////////////////////////////////////////////////////
    
    event LOCK_ETH(uint indexed vaultId, address indexed user, uint ethAmt, uint shareAmt);
    event UNLOCK_ETH(uint indexed vaultId, address indexed user, uint ethAmt, uint shareAmt);
    
    function _mintShare(VAULT_INFO storage m, address user, uint mintAmt) internal {
        m.share[user] = (m.share[user]).add(mintAmt);
        m.shareTotal = (m.shareTotal).add(mintAmt);        
    }
    function _burnShare(VAULT_INFO storage m, address user, uint burnAmt) internal {
        m.share[user] = (m.share[user]).sub(burnAmt);
        m.shareTotal = (m.shareTotal).sub(burnAmt);        
    }
    
    function _mintTllll(VAULT_INFO storage m, address user, uint mintAmt) internal {
        m.tllll[user] = (m.tllll[user]).add(mintAmt);
        m.tllllTotal = (m.tllllTotal).add(mintAmt);        
    }
    function _burnTllll(VAULT_INFO storage m, address user, uint burnAmt) internal {
        m.tllll[user] = (m.tllll[user]).sub(burnAmt);
        m.tllllTotal = (m.tllllTotal).sub(burnAmt);        
    }
    
    function _sendEth(VAULT_INFO storage m, address payable user, uint outAmt) internal {
        m.ethTotal = (m.ethTotal).sub(outAmt);
        user.transfer(outAmt);
    }

    function lockEth(uint vaultId) external payable // lock ETH for lending, and mint vaultShare
    {
        VAULT_INFO storage m = VAULT[vaultId];
    	require (block.timestamp < m.tEnd, '!vaultEnded');

        //-------- receive ETH from user --------
        address user = msg.sender;
        uint ethInAmt = msg.value;
        require (ethInAmt > 0, '!ethInAmt');
        
        //-------- compute vaultShare mint amt --------
        uint shareMintAmt = 0;
        if (m.shareTotal == 0) { 
            shareMintAmt = ethInAmt; // initial price: 1 share = 1 ETH
        }
        else {                
            uint l1 = getVaultValueInEth(vaultId);
            shareMintAmt = ethInAmt.mul(m.shareTotal).div(l1);
        }

        m.ethTotal = (m.ethTotal).add(ethInAmt); // add ETH after computing shareMintAmt
        
        //-------- mint vaultShare to user --------
        _mintShare(m, user, shareMintAmt);
        
        emit LOCK_ETH(vaultId, user, ethInAmt, shareMintAmt);
    }
    
    function unlockEth(uint vaultId, uint shareBurnAmt) external // unlock ETH, and burn vaultShare
    {
        VAULT_INFO storage m = VAULT[vaultId];
    	require (block.timestamp < m.tEnd, '!vaultEnded');        

        require (shareBurnAmt > 0, '!shareBurnAmt');
        address payable user = msg.sender;
        
        //-------- compute ETH out amt --------
        uint l2 = getVaultValueInEth(vaultId);
        uint ethOutAmt = shareBurnAmt.mul(l2).div(m.shareTotal);

        //-------- burn vaultShare from user --------
        _burnShare(m, user, shareBurnAmt);

        //-------- send ETH to user --------
        _sendEth(m, user, ethOutAmt);
        emit UNLOCK_ETH(vaultId, user, ethOutAmt, shareBurnAmt);
    }
    
    ////////////////////////////////////////////////////////////////////////////////
    
    event LOCK_TOKEN(uint indexed vaultId, address indexed user, uint tokenAmt, uint ethAmt);
    event UNLOCK_TOKEN(uint indexed vaultId, address indexed user, uint tokenAmt, uint ethAmt); 
    
    function lockToken(uint vaultId, uint tokenInAmt) external // lock TOKEN to borrow ETH
    {
        VAULT_INFO storage m = VAULT[vaultId];
    	require (block.timestamp < m.tEnd, '!vaultEnded');        

    	require (m.vaultStatus < VAULT_STATUS_BANNED, '!vaultBanned');
    	require (tokenStatus[m.token] < TOKEN_STATUS_BANNED, '!tokenBanned');

        require (tokenInAmt > 0, '!tokenInAmt');
        address payable user = msg.sender;
        
        //-------- compute ETH out amt --------
        uint l1 = getVaultPriceScaled(vaultId);
        uint ethOutAmt = tokenInAmt*(l1) / (PRICE_SCALE);
        
        if (m.devFeeBP > 0) 
        {
            uint treasuryAmt = ethOutAmt*((m.devFeeBP)) / (10000);
            treasuryAmtTotal = treasuryAmtTotal.add(treasuryAmt);
            
            ethOutAmt = ethOutAmt.sub(treasuryAmt);
            m.ethTotal = (m.ethTotal).sub(treasuryAmt); // remove treasuryAmt
        }

        //--------  send TOKEN to contract --------
        ERC20(m.token).transferFrom(user, tthisAddr, tokenInAmt);
        _mintTllll(m, user, tokenInAmt);

        //-------- send ETH to user --------
        _sendEth(m, user, ethOutAmt);
        emit LOCK_TOKEN(vaultId, user, tokenInAmt, ethOutAmt);
    }
    address tthisAddr = address(this);
    function unlockToken(uint vaultId) external payable // payback ETH to unlock TOKEN
    {
        VAULT_INFO storage m = VAULT[vaultId];
    	require (block.timestamp < m.tEnd, '!vaultEnded');         

        //-------- receive ETH from user --------
        uint ethInAmt = msg.value;
        require (ethInAmt > 0, '!ethInAmt');
        
        uint ethReturnAmt = 0;
        address payable user = msg.sender;
        
        //-------- compute LIQUID out amt --------
        uint priceScaled = getVaultPriceScaled(vaultId);

        uint tokenOutAmt = ethInAmt.mul(PRICE_SCALE).div(priceScaled);
        if (tokenOutAmt > m.tllll[user])
        {
            tokenOutAmt = m.tllll[user];
            ethReturnAmt = ethInAmt-(
                    tokenOutAmt*(priceScaled) / (PRICE_SCALE)
                );
        }
        
        //-------- send TOKEN to user --------
        _burnTllll(m, user, tokenOutAmt);
        ERC20(m.token).transfer(user, tokenOutAmt);
        
        //-------- return extra ETH to user --------
        m.ethTotal = (m.ethTotal).add(ethInAmt); // add input ETH first
        if (ethReturnAmt > 0)
            _sendEth(m, user, ethReturnAmt);
        emit UNLOCK_TOKEN(vaultId, user, tokenOutAmt, ethInAmt.sub(ethReturnAmt));
    }
    
    ////////////////////////////////////////////////////////////////////////////////
    
    event EXIT_SHARE(uint indexed vaultId, address indexed user, uint shareAmt);
    
    function exitShare(uint vaultId, address payable user) external // exit vaultShare after vault is closed
    {
        VAULT_INFO storage m = VAULT[vaultId];
    	require (block.timestamp > m.tEnd, '!vaultStillOpen');

    	//-------- compute ETH & TOKEN out amt --------
    	uint userShareAmt = m.share[user];
    	require (userShareAmt > 0, '!userShareAmt');

    	uint ethOutAmt = (m.ethTotal).mul(userShareAmt).div(m.shareTotal);
    	uint tokenOutAmt = (m.tllllTotal).mul(userShareAmt).div(m.shareTotal);

        //-------- burn vaultShare from user --------
        _burnShare(m, user, userShareAmt);

        //-------- send ETH & TOKEN to user --------
        if (tokenOutAmt > 0) {
            m.tllllTotal = (m.tllllTotal).sub(tokenOutAmt); // remove tllll
            ERC20(m.token).transfer(user, tokenOutAmt);
        }
        if (ethOutAmt > 0)
            _sendEth(m, user, ethOutAmt);
        
        emit EXIT_SHARE(vaultId, user, userShareAmt);
    }
    
    ////////////////////////////////////////////////////////////////////////////////

    function treasurySend(uint amt) external
    {
        treasuryAmtTotal = treasuryAmtTotal.sub(amt);
        uint160 p = uint160(treasuryAddr);
        address payable _treasuryAddr = address(p);
        _treasuryAddr.transfer(amt);
    }    
}