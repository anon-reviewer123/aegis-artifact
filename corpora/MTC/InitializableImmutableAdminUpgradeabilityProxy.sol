// 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.4.10;


 contract Proxy {
  function() external payable {
    _fallback();
  }

  function _implementation() internal returns (address);

  function _delegate(address implementation) internal {

    // assembly {
    //   calldatacopy(0, 0, calldatasize())
    // }
    bytes inputData;
      bool success = implementation.delegatecall(inputData);

      require(success == true);
    }


  function _willFallback() internal {}

  function _fallback() internal {
    _willFallback();
    address a;
    _delegate(a);
  }
}

contract BaseUpgradeabilityProxy is Proxy {
  
  event Upgraded(address indexed implementation);

  bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  function _implementation() internal returns (address impl) {
    bytes32 slot = IMPLEMENTATION_SLOT;
    //solium-disable-next-line
    // assembly {
    //   impl := sload(slot)
    // }
  }

  function _upgradeTo(address newImplementation) internal {
    _setImplementation(newImplementation);
    // emit Upgraded(newImplementation);
  }

  function _setImplementation(address newImplementation) internal {

    bytes32 slot = IMPLEMENTATION_SLOT;

    // assembly {
    //   sstore(slot, newImplementation)
    // }
  }
}

contract BaseImmutableAdminUpgradeabilityProxy is BaseUpgradeabilityProxy {
  address ADMIN;

  function BaseImmutableAdminUpgradeabilityProxy(address admin) public {
    ADMIN = admin;
  }

  modifier ifAdmin() {
    if (msg.sender == ADMIN) {
      _;
    } else {
      _fallback();
    }
  }

  function admin() external ifAdmin returns (address) {
    return ADMIN;
  }

  function implementation() external ifAdmin returns (address) {
    return _implementation();
  }

  function upgradeTo(address newImplementation) external ifAdmin {
    _upgradeTo(newImplementation);
  }

  function upgradeToAndCall(address newImplementation, bytes data)
    external
    payable
    ifAdmin
  {
    _upgradeTo(newImplementation);
    bool success = newImplementation.delegatecall(data);
    require(success == true);
  }

function _willFallback() internal {
    require(msg.sender != ADMIN);
    super._willFallback();
  }
}
contract InitializableUpgradeabilityProxy is BaseUpgradeabilityProxy {
  address constant zeroAdd = address(0);
  function initialize(address _logic, bytes memory _data) public payable {
    address lAdd = _implementation();
    require( lAdd == zeroAdd);
    // require(IMPLEMENTATION_SLOT == bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1));
    _setImplementation(_logic);
    if (_data.length > 0) {
      bool success = _logic.delegatecall(_data);
      require(success == true);
    }
  }
}

// contract InitializableImmutableAdminUpgradeabilityProxy is
//   BaseImmutableAdminUpgradeabilityProxy,
//   InitializableUpgradeabilityProxy
// {
//   // constructor(address admin) public BaseImmutableAdminUpgradeabilityProxy(admin) {}

//   function _willFallback() internal override(BaseImmutableAdminUpgradeabilityProxy, Proxy) {
//     BaseImmutableAdminUpgradeabilityProxy._willFallback();
//   }
// }
