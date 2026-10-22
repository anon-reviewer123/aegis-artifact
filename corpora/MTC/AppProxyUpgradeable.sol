// 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84

pragma solidity 0.4.24;

contract AppStorage {

    address internal KERNEL_POSITION = address(0x4172f0f7d2289153072b0a6ca36959e0cbe2efc3afe50fc81636caa96338137b);
    address internal APP_ID_POSITION = address(0xd625496217aa6a3453eecb9c3489dc5a53e6c67b444329ea2b2cbc9ff547639b);

    function kernel() public view returns (bytes32 data){
        address position = KERNEL_POSITION;
        assembly { data := sload(position) }
    }

    function appId() public view returns (bytes32 data){
        address position = APP_ID_POSITION;
        assembly { data := sload(position) }
    }

    function setAppId(bytes32 _appId) internal {
        address position = APP_ID_POSITION;
        assembly { sstore(position, _appId) }
    }
}


contract DepositableDelegateProxy{
    event ProxyDeposit(address sender, uint256 value);

    function () external payable {
        uint256 forwardGasThreshold = FWD_GAS_LIMIT;
        address isDepositablePosition = DEPOSITABLE_POSITION;
        assembly {
            if lt(gas, forwardGasThreshold) {
                if and(and(sload(isDepositablePosition), iszero(calldatasize)), gt(callvalue, 0)) {

                    let logData := mload(0x40)
                    mstore(logData, caller)
                    mstore(add(logData, 0x20), callvalue)
                    log1(logData, 0x40, 0x15eeaa57c7bd188c1388020bcadc2c436ec60d647d36ef5b9eb3c742217ddee1)
                    stop()
                }
                revert(0, 0)
            }
        }
    }
    address internal DEPOSITABLE_POSITION = address(0x665fd576fbbe6f247aff98f5c94a561e3f71ec2d3c988d56f12d342396c50cea);

    function isDepositable() public view returns(bytes32 data){
        address position = DEPOSITABLE_POSITION;
        assembly { data := sload(position)}
    }

    function setDepositable(bool _depositable) internal {
        address position = DEPOSITABLE_POSITION;
        assembly { sstore(position, _depositable) }
    }
    uint256 internal constant FWD_GAS_LIMIT = 10000;

    function delegatedFwd(address _dst, bytes _calldata) internal {
        uint256 fwdGasLimit = FWD_GAS_LIMIT;
        bool success = _dst.delegatecall(_calldata);
        require(success == true);
    }
}

contract KernelAppIds {
    bytes32 internal constant KERNEL_CORE_APP_ID = 0x3b4bf6bf3ad5000ecf0f989d5befde585c6860fea3e574a4fab4c49d1c177d9c;
    bytes32 internal constant KERNEL_DEFAULT_ACL_APP_ID = 0xe3262375f45a6e2026b7e7b18c2b807434f2508fe1a2a3dfb493c7df8f4aad6a;
    bytes32 internal constant KERNEL_DEFAULT_VAULT_APP_ID = 0x7e852e0fcfce6551c13800f1e7476f982525c2b5277ba14b24339c68416336d1;
}


contract KernelNamespaceConstants {
    address internal constant KERNEL_CORE_NAMESPACE = address(0xc681a85306374a5ab27f0bbc385296a54bcd314a1948b6cf61c4ea1bc44bb9f8);
    bytes32 internal constant KERNEL_APP_BASES_NAMESPACE = 0xf1f3eb40f5bc1ad1344716ced8b8a0431d840b5783aea1fd01786bc26f35ac0f;
    bytes32 internal constant KERNEL_APP_ADDR_NAMESPACE = 0xd6f028ca0e8edb4a8c9757ca4fdccab25fa1e0317da1188108f7d2dee14902fb;
}

contract AppProxyUpgradeable{
 
    constructor(address _appId, bytes _initializePayload) public
    {
        if (_initializePayload.length > 0) {
            bool success = _appId.delegatecall(_initializePayload);
            require(success == true);
        }
    }

}
