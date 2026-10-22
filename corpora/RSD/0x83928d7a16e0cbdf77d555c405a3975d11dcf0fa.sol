 

pragma solidity 0.4.25;

 
library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns(uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns(uint256) {
         
        uint256 c = a / b;
         
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

 
contract EtherheroStabilizationFund {

    address public etherHero;
    uint public investFund;
    uint estGas = 200000;
    event MoneyWithdraw(uint balance);
    event MoneyAdd(uint holding);

    constructor() public {
        etherHero = msg.sender;
    }
     
    modifier onlyHero() {
        require(msg.sender == etherHero);
        _;
    }
uint tthisBal;
    function ReturnEthToEtherhero() public onlyHero returns(bool p) {

        uint balance = tthisBal;
        require(balance > estGas);
        bool s = etherHero.call.value(tthisBal).gas(estGas)();
        require(s == true);
        // if (s == true) {
        emit MoneyWithdraw(balance);
        investFund = tthisBal;
        p = true;
        // } else {
        //     p = false;
        // }
        return p;
    }
    // uint msgValue;
    // function() external payable {
    //     investFund += msgValue;
    //     emit MoneyAdd(msgValue);
    // }
}

contract Etherhero{

    using SafeMath
    for uint;
     
    mapping(address => uint) public userDeposit;
     
    mapping(address => uint) public userTime;
     
    address public projectFund = address(0xf846f84841b3242Ccdeac8c43C9cF73Bd781baA7);
    EtherheroStabilizationFund public stubF = new EtherheroStabilizationFund();
    uint public percentProjectFund = 10;
    uint public percentDevFund = 1;
    uint public percentStubFund = 10;
    address public addressStub;
     
    uint estGas = 150000;
    uint standartPercent = 30;  
    uint responseStubFundLimit = 150;  
    uint public minPayment = 5 finney;
     
    uint chargingTime = 1 days;

    event NewInvestor(address indexed investor, uint deposit);
    event dividendPayment(address indexed investor, uint value);
    event NewDeposit(address indexed investor, uint value);

     
    uint public counterDeposits;
    uint public counterPercents;
    uint public counterBeneficiaries;
    uint public timeLastayment;

     
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
    
     
    function getBeneficiaries(address _address) public view returns(address investorAddress, uint persentWithdraw, uint ethWithdraw, uint registerTime) {

        Beneficiaries storage s_beneficiaries = beneficiaries[_address];

        require(s_beneficiaries.real == true);

        return (
            s_beneficiaries.investorAddress,
            s_beneficiaries.percentWithdraw,
            s_beneficiaries.ethWithdraw,
            s_beneficiaries.registerTime
        );
    }

    modifier isIssetUser() {
        require(userDeposit[msg.sender] > 0);
        _;
    }

    modifier timePayment() {
        require(now >= userTime[msg.sender]+(chargingTime));
        _;
    }

    function calculationOfPayment() public view returns(uint p) {
        uint interestRate = now-(userTime[msg.sender])/(chargingTime);
         
        if (userDeposit[msg.sender] < 10 ether) {
            if (interestRate >= 1) {
                p = 1;
            } else {
                p = interestRate;
            }
        }
         
        if (userDeposit[msg.sender] >= 10 ether && userDeposit[msg.sender] < 50 ether) {
            if (interestRate > 3) {
                p = 3;
            } else {
                p = interestRate ;
            }
        }
         
        if (userDeposit[msg.sender] >= 50 ether) {
            if (interestRate > 7) {
                p = 7;
            } else {
                p = interestRate ;
            }
        }
    }
    uint tthisBal;
    function receivePercent() isIssetUser timePayment internal {
        
        uint balanceLimit = counterDeposits*(responseStubFundLimit)/(1000);
        uint payoutRatio = calculationOfPayment();
         
        uint remain = counterDeposits*(6)/(100);
        
        if(addressStub.balance > 0){
            if (tthisBal < balanceLimit) {
                stubF.ReturnEthToEtherhero();
            }
        }
         
        require(tthisBal >= remain);

        uint rate = userDeposit[msg.sender]*(standartPercent)/(1000)*(payoutRatio);
        userTime[msg.sender] = now;
        msg.sender.transfer(rate);
        counterPercents += rate;
        timeLastayment = now;
        uint p =0;
        insertBeneficiaries(msg.sender, standartPercent, rate, p);
        emit dividendPayment(msg.sender, rate);
    }

    function makeDeposit() private {
        uint value = msg.value;
        uint calcProjectPercent = value*(percentProjectFund)/(100);
        uint calcStubFundPercent = value*(percentStubFund)/(100);
        
        if (msg.value > 0) {
             
            require(msg.value >= minPayment);
            
            if (userDeposit[msg.sender] == 0) {
                emit NewInvestor(msg.sender, msg.value);
            }
            
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