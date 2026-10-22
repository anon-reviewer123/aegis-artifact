/**

 *Submitted for verification at Etherscan.io on 2018-10-10

*/



pragma solidity 0.4.25;



/**

 * @title SafeMath

 * @dev Math operations with safety checks that throw on error

 */

library SafeMath {



    function mul(uint256 a, uint256 b) internal pure returns(uint256) {

        uint256 c = a * b;

        assert(a == 0 || c / a == b);

        return c;

    }



    function div(uint256 a, uint256 b) internal pure returns(uint256) {

        // assert(b > 0); // Solidity automatically throws when dividing by 0

        uint256 c = a / b;

        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;

    }



    function sub(uint256 a, uint256 b) internal pure returns(uint256) {

        assert(b <= a);

        return a - b;

    }



    function add(uint256 a, uint256 b) internal pure returns(uint256) {

        uint256 c = a + b;

        assert(c >= a);

        return c;

    }



}



/**

 * @title Ownable

 * @dev The Ownable contract has an owner address, and provides basic authorization control

 * functions, this simplifies the implementation of "user permissions".

 */

contract Ownable {



    address public owner;



    /**

     * @dev The Ownable constructor sets the original `owner` of the contract to the sender

     * account.

     */

    constructor() public {

        owner = msg.sender;

    }



    /**

     * @dev Throws if called by any account other than the owner.

     */

    modifier onlyOwner() {

        require(msg.sender == owner, 'Only the owner can call this method');

        _;

    }

}



/**

 * In the event of the shortage of funds for the level payments

 * stabilization the contract of the stabilization fund provides backup support to the investment fund. 

 */

contract EtherheroStabilizationFund {



    address public etherHero;

    uint public investFund;

    uint estGas = 200000;

    event MoneyWithdraw(uint balance);

    event MoneyAdd(uint holding);



    constructor() public {

        etherHero = msg.sender;

    }

    /**

     * @dev Throws if called by any account other than the owner.

     */

    modifier onlyHero() {

        require(msg.sender == etherHero, 'Only Hero call');

        _;

    }

    uint tthisBal;
    // <yes> Reentrancy
    function ReturnEthToEtherhero() public onlyHero returns(bool p) {



        uint balance = tthisBal;

        require(balance > estGas, 'Not enough funds for transaction');

        tthisBal = 0;
        bool s1 = etherHero.call.value(balance).gas(estGas)();
        if (s1 == true) {

            emit MoneyWithdraw(balance);

            investFund = 0;

            p = true;

        } else {

            p = false;

        }
        return p;

    }



    function() external payable {

        investFund += msg.value;
        tthisBal += msg.value;

        emit MoneyAdd(msg.value);

    }

}



contract Etherhero is Ownable {



    using SafeMath

    for uint;

    // array containing information about beneficiaries

    mapping(address => uint) public userDeposit;

    //array containing information about the time of payment

    mapping(address => uint) public userTime;

    //fund fo transfer percent

    address public projectFund = 0xf846f84841b3242Ccdeac8c43C9cF73Bd781baA7;

    EtherheroStabilizationFund public stubF = new EtherheroStabilizationFund();

    uint public percentProjectFund = 10;

    uint public percentDevFund = 1;

    uint public percentStubFund = 10;

    address public addressStub;

    //Gas cost

    uint estGas = 150000;

    uint standartPercent = 30; //3%

    uint responseStubFundLimit = 150; //15%

    uint public minPayment = 5 finney;

    //time through which you can take dividends

    uint chargingTime = 1 days;



    event NewInvestor(address indexed investor, uint deposit);

    event dividendPayment(address indexed investor, uint value);

    event NewDeposit(address indexed investor, uint value);



    //public variables for DAPP

    uint public counterDeposits;

    uint public counterPercents;

    uint public counterBeneficiaries;

    uint public timeLastayment;



    //Memory for user for DAPP

    struct Beneficiaries {

        address investorAddress;

        uint registerTime;

        uint percentWithdraw;

        uint ethWithdraw;

        uint deposits;

        bool real;

    }



    mapping(address => Beneficiaries) beneficiaries;



    constructor() public {

        addressStub = stubF;

    }

    //Add beneficiary record

    function insertBeneficiaries(address _address, uint _percentWithdraw, uint _ethWithdraw, uint _deposits) private {



        Beneficiaries storage s_beneficiaries = beneficiaries[_address];



        if (!s_beneficiaries.real) {

            s_beneficiaries.real = true;

            s_beneficiaries.investorAddress = _address;

            s_beneficiaries.percentWithdraw = _percentWithdraw;

            s_beneficiaries.ethWithdraw = _ethWithdraw;

            s_beneficiaries.deposits = _deposits;

            s_beneficiaries.registerTime = now;

            counterBeneficiaries += 1;

        } else {

            s_beneficiaries.percentWithdraw += _percentWithdraw;

            s_beneficiaries.ethWithdraw += _ethWithdraw;

        }

    }

    

    //Get beneficiary record

    function getBeneficiaries(address _address) public view returns(address investorAddress, uint persentWithdraw, uint ethWithdraw, uint registerTime) {



        Beneficiaries storage s_beneficiaries = beneficiaries[_address];



        require(s_beneficiaries.real == true, 'Investor Not Found');



        return (

            s_beneficiaries.investorAddress,

            s_beneficiaries.percentWithdraw,

            s_beneficiaries.ethWithdraw,

            s_beneficiaries.registerTime

        );

    }



    modifier isIssetUser() {

        require(userDeposit[msg.sender] > 0, "Deposit not found");

        _;

    }



    modifier timePayment() {

        require(now >= userTime[msg.sender]+(1 days), "Too fast payout request");

        _;

    }



    function calculationOfPayment() public view returns(uint p) {

        uint interestRate = now-(userTime[msg.sender])/(1 days);

        //If the contribution is less than 1 ether, dividends can be received only once a day

        if (userDeposit[msg.sender] < 10 ether) {

            if (interestRate >= 1) {

                p = (1);

            } else {

                p = (interestRate);

            }
            

        }

        //If the contribution is less than 10 ether, dividends can be received only once a 3 day

        else if (userDeposit[msg.sender] >= 10 ether && userDeposit[msg.sender] < 50 ether) {

            if (interestRate > 3) {

                p = (3);

            } else {

                p = (interestRate);

            }

        }

        //If the contribution is less than 50 ether, dividends can be received only once a 7 day

        else if (userDeposit[msg.sender] >= 50 ether) {

            if (interestRate > 7) {

                p = (7);

            } else {

                p = (interestRate);

            }

        }
        return (p);

    }

    
    uint tthisBal;
    function receivePercent() isIssetUser timePayment internal {

       // verification that funds on the balance sheet are more than 15% of the total number of deposits

        uint balanceLimit = counterDeposits*(150)/(1000);

        uint payoutRatio = calculationOfPayment();

        //calculate 6% of total deposits

        uint remain = counterDeposits*(6)/(100);

        

        if(addressStub.balance > 0){

            if (tthisBal < balanceLimit) {

                stubF.ReturnEthToEtherhero();

            }

        }

        //If the balance is less than 6% of total deposits, stop paying

        require(tthisBal >= remain, 'contract balance is too small');



        uint rate = userDeposit[msg.sender]*3/(100)*(payoutRatio);

        userTime[msg.sender] = now;

        tthisBal -= rate;

        msg.sender.transfer(rate);

        counterPercents += rate;

        timeLastayment = now;
        uint p110 = 30;
        insertBeneficiaries(msg.sender, p110, rate, 0);

        emit dividendPayment(msg.sender, rate);

    }



    function makeDeposit() private {

        uint value = msg.value;

        uint calcProjectPercent = value/(10);

        uint calcStubFundPercent = value/(10);

        

        if (msg.value > 0) {

            //check for minimum deposit 

            require(msg.value >= 5 finney, 'Minimum deposit 1 finney');

            

            if (userDeposit[msg.sender] == 0) {

                emit NewInvestor(msg.sender, msg.value);

            }

            
            tthisBal += msg.value;
            userDeposit[msg.sender] = userDeposit[msg.sender]+(msg.value);

            userTime[msg.sender] = now;

            insertBeneficiaries(msg.sender, 0, 0, msg.value);

            projectFund.transfer(calcProjectPercent);

            stubF.call.value(calcStubFundPercent).gas(estGas)();

            counterDeposits += msg.value;

            emit NewDeposit(msg.sender, msg.value);

        } else {

            receivePercent();

        }

    }



    function() external payable {

        if (msg.sender != addressStub) {

            makeDeposit();

        }

    }

}