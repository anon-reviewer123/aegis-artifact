// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract ERC1155VaultH {
    mapping(address => uint256) public shares;
    uint256 public totalShares; uint256 public totalAssets;
    uint256 public inFlight; bool public exposed; address public receiver;
    constructor(address _r){ receiver = _r; }
    function depositFor(address who, uint256 a) public { shares[who]+=a; totalShares+=a; totalAssets+=a; }
    function deposit(uint256 a) public { shares[msg.sender]+=a; totalShares+=a; totalAssets+=a; }
    function redeemAll(uint256) public { uint256 s=shares[msg.sender]; shares[msg.sender]=0; totalShares-=s; totalAssets-=s; }
    // mintTo PRE: shares+assets reserved (inFlight tracks the unsettled assets)
    function beginExposed(uint256 a) public { shares[msg.sender]+=a; totalShares+=a; inFlight+=a; exposed=true; }
    // mintTo POST: settle reserved assets
    function endExposed(uint256 a) public { require(exposed && inFlight==a); totalAssets+=a; inFlight-=a; exposed=false; }
}
