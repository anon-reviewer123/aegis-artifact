pragma solidity ^0.4.11;

contract EthBird {
    
    address public owner;
    address highScoreUser;
    
    uint currentHighScore = 0;
    uint256 ownerCommision = 0;
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
        if (msg.value >= 0.001 ether) {
            paidUsers[msg.sender] = true;
            ownerCommision = msg.value / 5;
            address(owner).transfer(ownerCommision);
        }
        uint p1 = contestEndTime();
        if(now >= p1){
            awardHighScore();   
        }
    }

    function getCurrentHighscore() public constant returns (uint) {
        return currentHighScore;
    }
    
    function getCurrentHighscoreUser() public constant returns (address) {
        return highScoreUser;
    }
    uint tthisBal;
    function getCurrentJackpot() public constant returns (uint p) {
        p = tthisBal;
        return p;
    }
    
    function contestEndTime() public constant returns (uint p)  {
        p = contestStartTime + 3 hours;
        return p;
    }
    
    function getNextPayoutEstimation() public constant returns (uint p) {
        uint p1 = contestEndTime();
        if(p1 > now){
            p = p1 - now;
        } else {
            p = 0;
        }
        return p;
    }
    
    function recordHighScore(uint score, address userToScore)  public onlyOwner {
        if(paidUsers[userToScore] == true){
            if(score > 0 && score >= currentHighScore){
                highScoreUser = userToScore;
                currentHighScore = score;
            }
        }
    }
    
    function awardHighScore() internal {
        address(highScoreUser).transfer(address(this).balance);
        contestStartTime = now;
        currentHighScore = 0;
        highScoreUser = 0;
    }
}