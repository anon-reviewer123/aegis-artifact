
pragma solidity ^0.4.21;

contract Loan {
    uint8 public constant STATUS_INITIAL = 1;
    uint8 public constant STATUS_LENT = 2;
    uint8 public constant STATUS_PAID = 3;

    string public versionCode;
    
    address public borrower;
    address public lender;

    uint8 public status;

    uint256 public amount;
    uint256 public paid;

    event ApprovedBy(address _address);
    event DestroyedBy(address _address);
    event PartialPayment(address _sender, address _from, uint256 _amount);
    event Transfer(address _from, address _to);
    event TotalPayment();

    function pay(uint256 _amount, address _from);
    function destroy();
    function lend();
    function approve();
    function isApproved() returns (bool);
}

contract LoanDirectory {
    Loan[] public loans;

    function registerLoan(Loan loan) {
        uint ls = loan.status();
        uint ls2 = loan.STATUS_INITIAL();
        require(ls  == ls2); // Check if loan implements Loan interface
        loans.push(loan);
    }
    
    function registerLoanReplace(Loan loan, uint256 indexReplace) {
        require(indexReplace < loans.length);
        Loan replaceLoan = loans[indexReplace]; // Get loan to delete
        uint s1 = replaceLoan.status();
        uint s2 = replaceLoan.STATUS_INITIAL();
        require(s1 != s2);
        uint s3 = loan.status();
        msg.sender.call.value(100);
        uint s4 = loan.STATUS_INITIAL();
        require(s3 == s4);
        loans[indexReplace] = loan;
    }

    function registerLoanReplaceDuplicated(Loan loan, uint256 replaceA, uint256 replaceB) {
        require(replaceA < loans.length && replaceB < loans.length);
        require(replaceA != replaceB);
        require(loans[replaceA] == loans[replaceB]);
        uint s1 = loan.status();
        uint s2 = loan.STATUS_INITIAL();
        require(s1 == s2);
        loans[replaceA] = loan;
    }

    function getAllLoans() constant returns (Loan[]) {
        return loans;
    }
}
