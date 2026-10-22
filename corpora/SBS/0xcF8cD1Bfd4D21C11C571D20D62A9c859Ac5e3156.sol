pragma solidity ^0.4.18;


contract Contract1 {

	mapping (uint => mapping (address => bool)) public something;

	function settrue(uint x, address a){
		something[x][a] = true;
	}
	function setfalse(uint x, address a){
		something[x][a] = false;
	}
}



contract Contract2 {

    Contract1 public original;
  
  	mapping (uint => mapping (address => uint)) public something;

    // コンストラクタ
    function Contract2(address c) public {
        original = Contract1(c);
    }


	function test(uint x, address a){
		bool s1 = original.something(uint(x),a);
		if(s1 == true)
			something[x][a] = 1;
		else
			something[x][a] = 2;
	}
}