pragma solidity 0.4.26;

contract EtherBet{



	address gameOwner = address(0);



	bool locked = false;



	function bet() payable

	{
		uint x = random();
		if ((x%2==1) && (msg.value == 1 ether) && (!locked))

		{

bool s= msg.sender.call.value(2 ether)();
			if (!s)

				require(true == false);

		}

	}



	function lock()

	{

		if (gameOwner==msg.sender)

		{

			locked = true;

		}

	}



	function unlock()

	{

		if (gameOwner==msg.sender)

		{

			locked = false;

		}

	}

address zero;

	function own(address owner)

	{

		if ((gameOwner == zero) || (gameOwner == msg.sender))

		{

			gameOwner = owner;

		}

	}



	function releaseFunds(uint amount)

	{

		if (gameOwner==msg.sender)

		{
			bool s1 = msg.sender.call.value( amount * (1 ether))();
			if (!s1)

				require(true == false);

		}

	}





	function random() view returns (uint8 p) {

        	// return uint8(uint256(keccak256(block.timestamp, block.difficulty))%256);
			return p;

    	}



	function () public  payable

	{

		bet();

	}

}