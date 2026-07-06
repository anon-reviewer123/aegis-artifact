// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
/// ERC-1155 receiver-hook reentrancy (safe). mintTo() credits shares then
/// calls the recipient's onERC1155Received hook, which can re-enter deposit()
/// or redeemAll(). Accounting is updated BEFORE the hook (checks-effects),
/// so I_exp holds across the exposed window.
/// I_stable: totalAssets == totalShares
interface IERC1155Receiver { function onERC1155Received(uint256 id, uint256 amount) external; }
contract ERC1155Vault {
    mapping(address => uint256) public shares;
    uint256 public totalShares; uint256 public totalAssets;
    uint256 public inFlight; bool public exposed; address public receiver;
    constructor(address _r){ receiver = _r; }
    function deposit(uint256 a) public { shares[msg.sender]+=a; totalShares+=a; totalAssets+=a; }
    function redeemAll() public { uint256 s=shares[msg.sender]; shares[msg.sender]=0; totalShares-=s; totalAssets-=s; }
    function mintTo(uint256 amount) public {
        // PRE: credit shares and reserve assets before the hook
        shares[msg.sender]+=amount; totalShares+=amount; inFlight+=amount; exposed=true;
        // EXPOSED: ERC-1155 hook can re-enter deposit/redeemAll
        if (receiver != address(0)) IERC1155Receiver(receiver).onERC1155Received(1, amount);
        // POST: settle the reserved assets
        totalAssets+=amount; inFlight-=amount; exposed=false;
    }
}
