/**
 *Submitted for verification at Etherscan.io on 2021-02-17
*/

pragma solidity 0.6.7;

interface IERC20 {
    function transfer(address to, uint256 value) external;
    function approve(address spender, uint256 value) external;
}

interface CToken {
    function mint(uint mintAmount) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function underlying() external returns (IERC20);
}

interface CEther {
    function mint() external payable;
    function redeemUnderlying(uint redeemAmount) external returns (uint);
}

abstract contract LinenWalletActions {

    function cEther() internal pure virtual returns (CEther);

    function approveAndMint(CToken cToken, uint mintAmount) external returns (bool) {
        address add1 = address(cToken);
        CEther p1 = cEther();
        address add2 = address(p1);
        if (add1 == add2){
            p1.mint{value: mintAmount}();
        } else {
            IERC20 lk = cToken.underlying();
            address lk1 = address(cToken);
            lk.approve(lk1, mintAmount);
            uint p2 = cToken.mint(mintAmount);
            require(p2 == 0, "Mint was not successful");
        }
        return true;
    }

    function redeemUnderlyingAndTransfer(CToken cToken, address payable to, uint redeemAmount) external returns (bool) {
        address add1 = address(cToken);
        CEther p1 = cEther();
        address add2 = address(p1);
        if (add1 == add2){
            uint p3 = p1.redeemUnderlying(redeemAmount);
            require(p3 == 0, "Redeem Underlying was not successful");
            (bool success, ) = to.call{value: redeemAmount}("");
            require(success == true, "Transfer was not successful");
        } else {
            uint p2 = cToken.redeemUnderlying(redeemAmount);
            require(p2 == 0, "Redeem Underlying was not successful");
            IERC20 lk = cToken.underlying();
            lk.transfer(to, redeemAmount);
        }

        return true;
    }

    function redeemUnderlyingAndTransfer(CToken cToken, address payable to, uint redeemAmount, uint feeAmount) external returns (bool) {
        require(redeemAmount >= feeAmount, "subtraction overflow");
        
        address add1 = address(cToken);
        CEther p1 = cEther();
        address add2 = address(p1);
        if (add1 == add2){
            uint p3 = p1.redeemUnderlying(redeemAmount);
            require(p3 == 0, "Redeem Underlying was not successful");
            (bool success, ) = to.call{value: redeemAmount - feeAmount}("");
            require(success == true, "Transfer was not successful");
        } else {
            uint p2 = cToken.redeemUnderlying(redeemAmount);
            require(p2 == 0, "Redeem Underlying was not successful");
            IERC20 lk = cToken.underlying();
            lk.transfer(to, redeemAmount - feeAmount);
        }

        return true;
    }
}

contract LinenWalletActionsMainnet is LinenWalletActions {
    function cEther() internal pure override returns (CEther p){
        p = CEther(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
        return p;
    }
}