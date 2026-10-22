pragma solidity ^0.4.18;

contract EthBird {
    
    address public owner;
    address highScoreUser;
    
    uint currentHighScore = 0;
    uint contestStartTime = now;
    
    mapping(address => bool) paidUsers;
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    function EthBird() public {
        owner = msg.sender;
    }
    
    function payEntryFee() public payable  {
        if (msg.value >= 0.01 ether) {
            paidUsers[msg.sender] = true;
        }
    }

    function getCurrentHighscore() public constant returns (uint) {
        return currentHighScore;
    }
    
    function getCurrentHighscoreUser() public constant returns (address) {
        return highScoreUser;
    }
    
    function getCurrentJackpot() public constant returns (uint) {
        return tthisBal;
    }
    
    function getNextPayoutEstimation() public constant returns (uint) {
        return (contestStartTime + 1 days) - now;
    }
    
    function recordHighScore(uint score, address userToScore)  public onlyOwner returns (address) {
        if(paidUsers[userToScore] == true){
            if(score > 0 && score >= currentHighScore){
                highScoreUser = userToScore;
                currentHighScore = score;
            }
            if(now >= contestStartTime + 1 days){
                awardHighScore();   
            }
        }
        return userToScore;
    }
    uint tthisBal;
    
    function awardHighScore() public onlyOwner {
        uint256 ownerCommision = tthisBal / 15;
        address(owner).transfer(ownerCommision);
        address(highScoreUser).transfer(tthisBal);
        contestStartTime = now;
    }
}