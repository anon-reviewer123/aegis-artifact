/**
 *Submitted for verification at Etherscan.io on 2019-10-15
*/

pragma solidity >=0.4.22 <0.6.0;

contract Airdrop {
    
    address  chairman;
    mapping(address => Registrant) public registrants;
    mapping(uint256 => address) public registrantArr;
    uint256 public nRegistrants;
    mapping(bytes32 => address) nameToAddress;
    bool public registrationsOpen;
    uint256 public maxReferrals;
    address public maxReferrer;
    uint256 public totalClaims;
    uint256[4] public params;
    
    struct Registrant {
        bytes32 telegramHash;
        uint8 status; //0: not verified, 1: verified, 2: tokens received
        bool verified;
        bool canClaim;
        bool created;
        address referrer;
        mapping (uint256 => address) referrals;
        uint256 nReferred;
        uint256 nReferredVerified;
    }
    
    Token token;
    address public tokenAddr = 0xd254fdE0eee65F3b75D01F5247bA260630A14B18;
    
    function claimTokens() external {
        require(registrationsOpen == false);
        require(totalClaims > 0);
        require(registrants[msg.sender].canClaim);
        uint p1 = token.balanceOf(address(this));
        uint p2 = canClaim(msg.sender);
        uint p3 = p2 * p1 / totalClaims;
        token.transfer(msg.sender, p3);
        registrants[msg.sender].status = 2;
    }
    
    function setVerification(bytes32 telegramHash, bool verification) external {
        require(msg.sender == chairman);
        require(registrationsOpen == false);
        if (!registrants[nameToAddress[telegramHash]].verified && verification == true) {
            registrants[nameToAddress[telegramHash]].verified = verification;
            registrants[registrants[nameToAddress[telegramHash]].referrer].nReferredVerified++;
            if (registrants[registrants[nameToAddress[telegramHash]].referrer].nReferredVerified > maxReferrals) {
                maxReferrals = registrants[registrants[nameToAddress[telegramHash]].referrer].nReferredVerified;
                maxReferrer = registrants[nameToAddress[telegramHash]].referrer;
            }
            return;
        }
        if (registrants[nameToAddress[telegramHash]].verified && !verification) {
            registrants[nameToAddress[telegramHash]].verified = verification;
            registrants[registrants[nameToAddress[telegramHash]].referrer].nReferredVerified--;
        }
    }
    
    function calcTotalClaims() public view returns(uint256) {
        // call after verification
        uint256 res=0;
        for (uint256 i=0; i<nRegistrants; i++) {
            res += canClaim(registrantArr[i]); 
        }
        return res;
    }
    
    function calcStandardClaim() public view returns(uint256 p) {
        uint p1 = token.balanceOf(address(this));
        p = 1000 * p1 / totalClaims;
        return p;
    }
    
    function finishVerification() public {
        require(msg.sender == chairman);
        require(registrationsOpen == false);

        totalClaims = calcTotalClaims();
    }
    
    function finishVerificationManual(uint256 _totalClaims) public {
        require(msg.sender == chairman);
        require(registrationsOpen == false);

        totalClaims = _totalClaims;
    }
    function startVerification() public {
        require(msg.sender == chairman);
        registrationsOpen = false;
    }
    
    function canClaimtelegramHash(bytes32 telegramHash) external view returns(uint256 p) {
        p = canClaim(nameToAddress[telegramHash]);
        return p;
    }
    
    function canClaim(address addr) public view returns(uint256) {
        if (registrants[addr].status >= 2) {
            return 0;
        }
        if (!registrants[addr].verified) {
            return 0;
        }

        uint256 res = params[0]; // 200
        for (uint256 i=0; i<registrants[addr].nReferred; i++) {
            if (registrants[registrants[addr].referrals[i]].verified) { 
                res += params[1]; // 400
            }
            if (res >= params[2]) { // 1000
                break;
            }
        }
        if (addr == maxReferrer) {
            res += params[3]; // 10000
        }
        return res;
    }

    address zero;
    
    function _register(address  _addr, bytes32 referrer, bytes32 telegramHash) internal {
        require(registrationsOpen == true);
        require(_addr.balance > 100 , "100  minimum balance required");
        require(registrants[_addr].created == false, "already created");
        require(nameToAddress[telegramHash] == zero, "telegramHash username already registered");
        require(nameToAddress[referrer] != zero || _addr == chairman, "must have referrer");

        nameToAddress[telegramHash] = _addr;
        registrants[_addr].status = 1;
        registrants[_addr].telegramHash = telegramHash;
        registrants[_addr].referrer = nameToAddress[referrer];
        registrants[_addr].verified = false;
        registrants[_addr].created = true;
        
        registrantArr[nRegistrants] = msg.sender;
        nRegistrants++;
        
        if (_addr == chairman) {
            return;
        }

        registrants[nameToAddress[referrer]].referrals[registrants[nameToAddress[referrer]].nReferred] = _addr;
        registrants[nameToAddress[referrer]].nReferred++;
    }
    
    function register(bytes32 referrer, bytes32 telegramHash) public {
        _register(msg.sender, referrer, telegramHash);
    }
    
    function registerManual(address  _addr, bytes32 referrer, bytes32 telegramHash) public {
        require(msg.sender == chairman);
        _register(_addr, referrer, telegramHash);
    }
    
    
    function retrieveUnclaimed() external {
        require(msg.sender == chairman);
        //add mintime
        uint p1 = token.balanceOf(address(this));
        token.transfer(msg.sender, p1);
    }
    
    function getAddress(bytes32 telegramHash) public view returns (address) {
        require(msg.sender == chairman);
        return nameToAddress[telegramHash];
    }
    
    
    function setParams(uint256[4] memory _params) public {
        require(msg.sender == chairman);
        params = _params;
    }
    
    constructor(bytes32 telegramHash) public {
        chairman = msg.sender;
        registrationsOpen = true;
        uint256[4] memory _params;
        _params[0] = 200;
        _params[1] = 400;
        _params[2] = 1000;
        _params[3] = 10000;
        setParams(_params);
        register(0, telegramHash);
        registrants[msg.sender].verified = true;
        token = Token(tokenAddr);
    }
} 

contract Token {
    mapping(address => uint256) public balanceOf;
    function transfer(address to, uint256 value) public returns (bool success) {

    }
}