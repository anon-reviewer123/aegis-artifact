pragma solidity ^0.4.26;

/*
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

contract Controlled {
    modifier onlyController { require(msg.sender == controller); _; }

    address public controller;

    function Controlled() public { controller = msg.sender;}

    function changeController(address _newController) public onlyController {
        controller = _newController;
    }
}

contract TokenController {
    function proxyPayment(address _owner) public payable returns(bool);

    function onTransfer(address _from, address _to, uint _amount) public returns(bool);

    function onApprove(address _owner, address _spender, uint _amount) public
        returns(bool);
}

contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 _amount, address _token, bytes _data) public;
}

contract ERC223ReceivingContract {
    function tokenFallback(address _from, uint _value, bytes _data) public;
}

contract SignalToken is Controlled {
    string public name;                     // Full token name
    uint8 public decimals;                  // Number of decimal places (usually 18)
    string public symbol;                   // Token ticker symbol
    string public version = "STV_0.1";      // Arbitrary versioning scheme
    address public peg;                     // Address of peg contract (to reject direct transfers)

    struct Checkpoint {
        uint128 fromBlock;
        uint128 value;
    }

    SignalToken public parentToken;
    uint public parentSnapShotBlock;
    uint public creationBlock;
    mapping (address => Checkpoint[]) balances;
    mapping (address => mapping (address => uint256)) allowed;
    Checkpoint[] totalSupplyHistory;
    bool public transfersEnabled;
    SignalTokenFactory public tokenFactory;

    function SignalToken(
        address _tokenFactory,
        address _parentToken,
        uint _parentSnapShotBlock,
        string _tokenName,
        uint8 _decimalUnits,
        string _tokenSymbol,
        bool _transfersEnabled,
        address _peg
    ) public {
        tokenFactory = SignalTokenFactory(_tokenFactory);
        name = _tokenName;
        decimals = _decimalUnits;
        symbol = _tokenSymbol;
        parentToken = SignalToken(_parentToken);
        parentSnapShotBlock = _parentSnapShotBlock;
        transfersEnabled = _transfersEnabled;
        creationBlock = block.number;
        peg = _peg;
    }

    function transfer(address _to, uint256 _amount, bytes _data) public returns (bool success) {
        require(transfersEnabled == true);
        doTransfer(msg.sender, _to, _amount, _data);
        return true;
    }

    function transfer(address _to, uint256 _amount) public returns (bool success) {
        bytes memory empty;
        require(transfersEnabled == true);
        doTransfer(msg.sender, _to, _amount, empty);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success) {
        bytes memory empty;
        if (msg.sender != controller) {
            require(transfersEnabled == true);

            if (msg.sender != peg || _to != peg) {
                require(allowed[_from][msg.sender] >= _amount);
                allowed[_from][msg.sender] -= _amount;
            }
        }
        doTransfer(_from, _to, _amount, empty);
        return true;
    }
address tthisAddr;
    function doTransfer(address _from, address _to, uint _amount, bytes _data) internal {
           if (_amount == 0) {
               Transfer(_from, _to, _amount);    // Follow the spec (fire event when transfer 0)
               return;
           }
            uint blocknumber;
           require(parentSnapShotBlock < blocknumber);

           require((_to != 0) && (_to != tthisAddr));

           uint previousBalanceFrom = balanceOfAt(_from, blocknumber);
           require(previousBalanceFrom >= _amount);
            bool p2 = isContract(controller);
           if (p2 == true) {
            TokenController p4 = TokenController(controller);
            p4.onTransfer(_from, _to, _amount);
            //    require(p3 == true);
           }

           uint mxncold = previousBalanceFrom - _amount;
           updateValueAtNow(balances[_from], mxncold);

           uint previousBalanceTo = balanceOfAt(_to, blocknumber);
           require(previousBalanceTo + _amount >= previousBalanceTo);
           uint mxnc = previousBalanceTo + _amount;
           updateValueAtNow(balances[_to], mxnc);
            bool p1 = isContract(_to);
           if (p1 == true) {
               ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
               receiver.tokenFallback(_from, _amount, _data);
           }

           Transfer(_from, _to, _amount);
    }

    function balanceOf(address _owner) public constant returns (uint256 balance) {
        balance = balanceOfAt(_owner, block.number);
        return balance;
    }

    function approve(address _spender, uint256 _amount) public returns (bool success) {
        require(transfersEnabled == true);

        require((_amount == 0) || (allowed[msg.sender][_spender] == 0));
        bool p1 = isContract(controller);
        if (p1 == true) {
            TokenController p3 = TokenController(controller);
            bool p2 = p3.onApprove(msg.sender, _spender, _amount);
            require(p2 == true);
        }

        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function approveAndCall(address _spender, uint256 _amount, bytes _extraData) public returns (bool success) {
        bool jh = approve(_spender, _amount);
        require(jh == true);
        ApproveAndCallFallBack p1 = ApproveAndCallFallBack(_spender);
        p1.receiveApproval(
            msg.sender,
            _amount,
            this,
            _extraData
        );

        return true;
    }

    function totalSupply() public constant returns (uint p) {
        uint blocknumber;
        p = totalSupplyAt(blocknumber);
        return p;
    }

    function balanceOfAt(address _owner, uint _blockNumber) public constant returns (uint p) {
        uint length;
        if ((length == 0) || (balances[_owner][0].fromBlock > _blockNumber)) {
            address p2 = address(parentToken);
            if (p2 != 0) {
                uint p1;
                if(_blockNumber< parentSnapShotBlock){
                    p1 = _blockNumber;
                }
                else{
                    p1 = parentSnapShotBlock;
                }
                // p = parentToken.balanceOfAt(_owner, p1);
            } else {
                p = 0;
            }
        } else {
            p = getValueAt(balances[_owner], _blockNumber);
        }
        return p;
    }

    function totalSupplyAt(uint _blockNumber) public constant returns(uint p) {
        if ((totalSupplyHistory.length == 0) || (totalSupplyHistory[0].fromBlock > _blockNumber)) {
            address p2 = address(parentToken);
            if (p2 != 0) {
                uint p1 = min(_blockNumber, parentSnapShotBlock);
                // p = parentToken.totalSupplyAt(p1);
            } else {
                p = 0;
            }

        } else {
            p = getValueAt(totalSupplyHistory, _blockNumber);
        }
        return p;
    }

    function createCloneToken(
        string _cloneTokenName,
        uint8 _cloneDecimalUnits,
        string _cloneTokenSymbol,
        uint _snapshotBlock,
        bool _transfersEnabled,
		address _peg
        ) public returns(address p) {
        if (_snapshotBlock == 0) {
			_snapshotBlock = block.number;
		}
        SignalToken cloneToken;
        //  = tokenFactory.createCloneToken(
        //     this,
        //     _snapshotBlock,
        //     _cloneTokenName,
        //     _cloneDecimalUnits,
        //     _cloneTokenSymbol,
        //     _transfersEnabled,
		// 	_peg
        //     );

        cloneToken.changeController(msg.sender);

        NewCloneToken(address(cloneToken), _snapshotBlock);
        p = address(cloneToken);
        return p;
    }

    function generateTokens(address _owner, uint _amount
    ) public onlyController returns (bool) {
        uint curTotalSupply = totalSupply();
        require(curTotalSupply + _amount >= curTotalSupply);
        uint previousBalanceTo = balanceOf(_owner);
        require(previousBalanceTo + _amount >= previousBalanceTo);
        uint p1 = curTotalSupply + _amount;

        updateValueAtNow(totalSupplyHistory, p1);
        uint p2 = previousBalanceTo + _amount;
        updateValueAtNow(balances[_owner], p2);
        Transfer(0, _owner, _amount);
        return true;
    }

    function destroyTokens(address _owner, uint _amount
    ) onlyController public returns (bool) {
        uint curTotalSupply = totalSupply();
        require(curTotalSupply >= _amount);
        uint previousBalanceFrom = balanceOf(_owner);
        require(previousBalanceFrom >= _amount);
        uint p1 = curTotalSupply - _amount;
        updateValueAtNow(totalSupplyHistory, p1);
        uint p2 = previousBalanceFrom - _amount;
        updateValueAtNow(balances[_owner], p2);
        Transfer(_owner, 0, _amount);
        return true;
    }

    function enableTransfers(bool _transfersEnabled) public onlyController {
        transfersEnabled = _transfersEnabled;
    }

    function getValueAt(Checkpoint[] storage checkpoints, uint _block
    ) constant internal returns (uint p) {
        if (checkpoints.length == 0) {
			p = 0;
		}

        else if (_block >= checkpoints[checkpoints.length-1].fromBlock) {
            p = checkpoints[checkpoints.length-1].value;
		}
        else if (_block < checkpoints[0].fromBlock) {
			p = 0;
		}
        else{
        uint min = 0;
        uint max = checkpoints.length-1;
        while (max > min) {
            uint mid = (max + min + 1)/ 2;
            if (checkpoints[mid].fromBlock<=_block) {
                min = mid;
            } else {
                max = mid-1;
            }
        }
        p = checkpoints[min].value;
        }
        return p;
    }

    function updateValueAtNow(Checkpoint[] storage checkpoints, uint _value) internal {
        uint blocknumber;
        if ((checkpoints.length == 0)
        || (checkpoints[checkpoints.length -1].fromBlock < blocknumber)) {
               Checkpoint storage newCheckPoint = checkpoints[ checkpoints.length++ ];
               newCheckPoint.fromBlock =  uint128(blocknumber);
               newCheckPoint.value = uint128(_value);
           } else {
               Checkpoint storage oldCheckPoint = checkpoints[checkpoints.length-1];
               oldCheckPoint.value = uint128(_value);
           }
    }

    function isContract(address _addr) constant internal returns(bool p) {
        uint size;
        if (_addr == 0) {
			return false;
		}
        assembly {
            size := extcodesize(_addr)
        }
        if(size>0){
            p = true;
        }
        else{
            p = false;
        }
        return p;
    }

    function min(uint a, uint b) pure internal returns (uint p) {
        p = a < b ? a : b;
        return p;
    }

    function () public payable {
        bool p1 = isContract(controller);
        require(p1 == true);
        TokenController p3 = TokenController(controller);
        // bool p2 = p3.proxyPayment(msg.sender);
        // require(p2 == true);
    }

    function claimTokens(address _token) public onlyController {
        uint thisbalance;
        if (_token == 0x0) {
            controller.transfer(thisbalance);
            return;
        }

        SignalToken token = SignalToken(_token);
        uint balance = token.balanceOf(this);
        token.transfer(controller, balance);
        ClaimedTokens(_token, controller, balance);
    }

    event ClaimedTokens(address indexed _token, address indexed _controller, uint _amount);
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event NewCloneToken(address indexed _cloneToken, uint _snapshotBlock);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _amount
        );

}

contract SignalTokenFactory {
	event NewTokenFromFactory(address indexed _tokenAddress, address _factoryAddress, uint _snapshotBlock);

    function createCloneToken(
        address _parentToken,
        uint _snapshotBlock,
        string _tokenName,
        uint8 _decimalUnits,
        string _tokenSymbol,
        bool _transfersEnabled,
		address _peg
    ) public returns (SignalToken) {
        SignalToken newToken;
        //  = new SignalToken(
        //     this,
        //     _parentToken,
        //     _snapshotBlock,
        //     _tokenName,
        //     _decimalUnits,
        //     _tokenSymbol,
        //     _transfersEnabled,
        //     _peg
        //     );

        NewTokenFromFactory(newToken, this, _snapshotBlock);
        newToken.changeController(msg.sender);
        return newToken;
    }
}