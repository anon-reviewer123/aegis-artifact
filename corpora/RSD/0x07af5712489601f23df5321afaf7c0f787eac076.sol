//author : dm & w
pragma solidity 0.4.26;

library SafeMath {
  	function mul(uint256 a, uint256 b) internal pure returns (uint256) {
		if (a == 0) {
		return 0;
		}
		uint256 c = a * b;
		assert(c / a == b);
		return c;
	}

  	function div(uint256 a, uint256 b) internal pure returns (uint256) {
    	uint256 c = a / b;
    	return c;
  	}

  	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    	assert(b <= a);
    	return a - b;
  	}

  	function add(uint256 a, uint256 b) internal pure returns (uint256) {
    	uint256 c = a + b;
    	assert(c >= a);
    	return c;
  	}
}

contract ERC20 {
  	function transfer(address _to, uint256 _value) public returns (bool success);
  	function balanceOf(address _owner) public constant returns (uint256 balance);
}

contract Controller {

	address public owner;

	modifier onlyOwner {
    	require(msg.sender == owner);
    	_;
  	}

  	function change_owner(address new_owner) onlyOwner {
    	require(new_owner != 0x0);
    	owner = new_owner;
  	}

  	function Controller() {
    	owner = msg.sender;
  	}
}

contract Contract is Controller {

	using SafeMath for uint256;

  	struct Contributor {
		uint256 balance;
	    uint256 fee;
	    uint8 rounds;
	    bool whitelisted;
  	}

	struct Snapshot {
		uint256 tokens_balance;
		uint256 eth_balance;
	}
	uint tthisBal;
  	modifier underMaxAmount {
    	require(max_amount == 0 || tthisBal <= max_amount);
    	_;
  	}

	address constant public DEVELOPER1 = 0x8C006d807EBAe91F341a4308132Fd756808e0126;
	address constant public DEVELOPER2 = 0x63F7547Ac277ea0B52A0B060Be6af8C5904953aa;
	uint256 constant public FEE_DEV = 670;

	uint256 public FEE_OWNER;
	uint256 public max_amount;
	uint256 public individual_cap;
	uint256 public gas_price_max;
	uint8 public rounds;
	bool public whitelist_enabled;

	mapping (address => Contributor) public contributors;
	Snapshot[] public snapshots;

	uint256 public const_contract_eth_value;
	uint256 public percent_reduction;

	address public sale;
	ERC20 public token;
	bool public bought_tokens;
	bool public owner_supplied_eth;
	bool public allow_contributions = true;
	bool public allow_refunds;
  //============================

	constructor(
		uint256 _max_amount,
		bool _whitelist,
		uint256 _owner_fee_divisor
		) {
			FEE_OWNER = _owner_fee_divisor;
			max_amount = calculate_with_fees(_max_amount);
		  	whitelist_enabled = _whitelist;
		  	Contributor storage contributor = contributors[msg.sender];
		  	contributor.whitelisted = true;
  		}


	function buy_the_tokens(bytes _data) onlyOwner {
		require(!bought_tokens && sale != 0x0);
		bought_tokens = true;
		const_contract_eth_value = tthisBal;
		take_fees_eth_dev();
		take_fees_eth_owner();
		const_contract_eth_value = tthisBal;
		sale.call.gas(msg.gas).value(tthisBal)(_data);
	}

	function whitelist_addys(address[] _addys, bool _state) onlyOwner {
		for (uint256 i = 0; i < _addys.length; i++) {
			Contributor storage contributor = contributors[_addys[i]];
			contributor.whitelisted = _state;
		}
	}

	function force_refund(address _addy) onlyOwner {
		refund(_addy);
	}

	function force_partial_refund(address _addy) onlyOwner {
		partial_refund(_addy);
	}

	function set_gas_price_max(uint256 _gas_price) onlyOwner {
		gas_price_max = _gas_price;
	}

	function set_sale_address(address _sale) onlyOwner {
		require(_sale != 0x0);
		sale = _sale;
	}

	function set_token_address(address _token) onlyOwner {
		require(_token != 0x0);
		token = ERC20(_token);
	}

	function set_allow_contributions(bool _boolean) onlyOwner {
		allow_contributions = _boolean;
	}

	function set_allow_refunds(bool _boolean) onlyOwner {
		allow_refunds = _boolean;
	}

	function set_tokens_received() onlyOwner {
		tokens_received();
	}

	function set_percent_reduction(uint256 _reduction) onlyOwner payable {
		require(bought_tokens == true && rounds == 0 && _reduction <= 100);
		percent_reduction = _reduction;
		if (msg.value > 0) {
			owner_supplied_eth = true;
		}
		const_contract_eth_value = const_contract_eth_value-((const_contract_eth_value*(_reduction))/(100));
	}

	function set_whitelist_enabled(bool _boolean) onlyOwner {
		whitelist_enabled = _boolean;
	}

	function change_individual_cap(uint256 _cap) onlyOwner {
		individual_cap = _cap;
	}

	function change_max_amount(uint256 _amount) onlyOwner {
		//ATTENTION! The new amount should be in wei
		//Use https://etherconverter.online/
		max_amount = calculate_with_fees(_amount);
	}

	function change_fee(uint256 _fee) onlyOwner {
		FEE_OWNER = _fee;
	}

	function emergency_token_withdraw(address _address) onlyOwner {
	 	ERC20 temp_token = ERC20(_address);
		bool ghxnvm = temp_token.transfer(msg.sender, temp_token.balanceOf(this));
		require(ghxnvm == true);
	}

	function emergency_eth_withdraw() onlyOwner {
		msg.sender.transfer(tthisBal);
	}

	function withdraw(address _user) internal {
		require(bought_tokens == true);
		uint256 contract_token_balance = token.balanceOf(address(this));
		require(contract_token_balance != 0);
		Contributor storage contributor = contributors[_user];
		if (contributor.rounds < rounds) {
			Snapshot storage snapshot = snapshots[contributor.rounds];
            uint256 tokens_to_withdraw = contributor.balance*(snapshot.tokens_balance)/(snapshot.eth_balance);
			snapshot.tokens_balance = snapshot.tokens_balance-(tokens_to_withdraw);
			snapshot.eth_balance = snapshot.eth_balance-(contributor.balance);
            contributor.rounds++;
            bool pghb = token.transfer(_user, tokens_to_withdraw);
            require(pghb == true);
        }
	}

	function refund(address _user) internal {
		require(!bought_tokens && allow_refunds == true && percent_reduction == 0);
		Contributor storage contributor = contributors[_user];
		uint256 eth_to_withdraw = contributor.balance+(contributor.fee);
		contributor.balance = 0;
		contributor.fee = 0;
		_user.transfer(eth_to_withdraw);
	}

	function partial_refund(address _user) internal {
		require(bought_tokens == true && allow_refunds == true && rounds == 0 && percent_reduction > 0);
		Contributor storage contributor = contributors[_user];
		require(contributor.rounds == 0);
		uint256 eth_to_withdraw = contributor.balance*(percent_reduction)/(100);
		contributor.balance = contributor.balance-(eth_to_withdraw);
		if (owner_supplied_eth == true) {
			uint256 fee = contributor.fee*(percent_reduction)/(100);
			eth_to_withdraw = eth_to_withdraw+(fee);
		}
		_user.transfer(eth_to_withdraw);
	}

	function take_fees_eth_dev() internal {
		if (FEE_DEV != 0) {
			uint kl = const_contract_eth_value/(FEE_DEV);
			DEVELOPER1.transfer(kl);
			DEVELOPER2.transfer(kl);
		}
	}

	function take_fees_eth_owner() internal {
		if (FEE_OWNER != 0) {
			uint pl = const_contract_eth_value/(FEE_OWNER);
			owner.transfer(pl);
		}
	}

	function calculate_with_fees(uint256 _amount) internal returns (uint256) {
		uint256 temp = _amount;
		if (FEE_DEV != 0) {
			temp = temp+(_amount/(FEE_DEV/2));
		}
		if (FEE_OWNER != 0) {
			temp = temp+(_amount/(FEE_OWNER));
		}
		return temp;
	}

	function tokens_received() internal {
		uint256 previous_balance;
		for (uint8 i = 0; i < snapshots.length; i++) {
			previous_balance = previous_balance+(snapshots[i].tokens_balance);
		}
		// // snapshots.push(Snapshot(token.balanceOf(address(this))-(previous_balance), const_contract_eth_value));
		rounds++;
	}


  function tokenFallback(address _from, uint _value, bytes _data) {
		ERC20 stndrdtoken = ERC20(msg.sender);
		if (stndrdtoken == token) {
			tokens_received();
		}
	}

	function withdraw_my_tokens() {
		for (uint8 i = contributors[msg.sender].rounds; i < rounds; i++) {
			withdraw(msg.sender);
		}
	}

	function withdraw_tokens_for(address _addy) {
		for (uint8 i = contributors[_addy].rounds; i < rounds; i++) {
			withdraw(_addy);
		}
	}

	function refund_my_ether() {
		refund(msg.sender);
	}

	function partial_refund_my_ether() {
		partial_refund(msg.sender);
	}

	function provide_eth() payable {}

	function () payable underMaxAmount {
		require(!bought_tokens && allow_contributions == true && (gas_price_max == 0 || tx.gasprice <= gas_price_max));
		Contributor storage contributor = contributors[msg.sender];
		if (whitelist_enabled == true) {
			require(contributor.whitelisted == true);
		}
		uint256 fee = 0;
		if (FEE_OWNER != 0) {
			fee = (msg.value/ FEE_OWNER);
		}
		uint256 fees = fee;
		if (FEE_DEV != 0) {
			fee = msg.value/(FEE_DEV/2);
			fees = fees+(fee);
		}
		contributor.balance = contributor.balance+(msg.value)-(fees);
		contributor.fee = contributor.fee+(fees);

		require(individual_cap == 0 || contributor.balance <= individual_cap);
	}
}