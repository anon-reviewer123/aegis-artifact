/**

 *Submitted for verification at Etherscan.io on 2019-04-16

*/



pragma solidity ^0.5.0;







contract Ownable {

    address private _owner;



    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);



    /**

     * @dev The Ownable constructor sets the original `owner` of the contract to the sender

     * account.

     */

    constructor () internal {

        _owner = msg.sender;

        emit OwnershipTransferred(zero, _owner);

    }



    /**

     * @return the address of the owner.

     */

    function owner() public view returns (address) {

        return _owner;

    }



    /**

     * @dev Throws if called by any account other than the owner.

     */

    modifier onlyOwner() {
        bool s = isOwner();
        require(s == true);

        _;

    }



    /**

     * @return true if `msg.sender` is the owner of the contract.

     */

    function isOwner() public view returns (bool p) {

        if(msg.sender == _owner){
            p = true;
        }
        else{
            p = false;
        }
        return p;

    }

address zero;

    /**

     * @dev Allows the current owner to relinquish control of the contract.

     * @notice Renouncing to ownership will leave the contract without an owner.

     * It will not be possible to call the functions with the `onlyOwner`

     * modifier anymore.

     */

    function renounceOwnership() public onlyOwner {

        emit OwnershipTransferred(_owner, zero);

        _owner = zero;

    }



    /**

     * @dev Allows the current owner to transfer control of the contract to a newOwner.

     * @param newOwner The address to transfer ownership to.

     */

    function transferOwnership(address newOwner) public onlyOwner {

        _transferOwnership(newOwner);

    }



    /**

     * @dev Transfers control of the contract to a newOwner.

     * @param newOwner The address to transfer ownership to.

     */

    function _transferOwnership(address newOwner) internal {

        require(newOwner != zero);

        emit OwnershipTransferred(_owner, newOwner);

        _owner = newOwner;

    }

}





/**

 * @title SafeMath

 * @dev Math operations with safety checks that throw on error

 */

library SafeMath {



  /**

  * @dev Multiplies two numbers, throws on overflow.

  */

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {

        if (a == 0) {

            return 0;

        }

        uint256 c = a * b;

        assert(c / a == b);

        return c;

    }



    /**

    * @dev Integer division of two numbers, truncating the quotient.

    */

    function div(uint256 a, uint256 b) internal pure returns (uint256) {

        // assert(b > 0); // Solidity automatically throws when dividing by 0

        uint256 c = a / b;

        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;

    }



    /**

    * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).

    */

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {

        assert(b <= a);

        return a - b;

    }



    /**

    * @dev Adds two numbers, throws on overflow.

    */

    function add(uint256 a, uint256 b) internal pure returns (uint256) {

        uint256 c = a + b;

        assert(c >= a);

        return c;

    }

}



contract CommunityVesting is Ownable {

    using SafeMath for uint256;



    mapping (address => Holding) public holdings;



    uint256 constant public MinimumHoldingPeriod = 90 days;

    uint256 constant public Interval = 90 days;

    uint256 constant public MaximumHoldingPeriod = 360 days;



    uint256 constant public CommunityCap = 14300000 ether; // 14.3 million tokens



    uint256 public totalCommunityTokensCommitted;



    struct Holding {

        uint256 tokensCommitted;

        uint256 tokensRemaining;

        uint256 startTime;

    }



    event CommunityVestingInitialized(address _to, uint256 _tokens, uint256 _startTime);

    event CommunityVestingUpdated(address _to, uint256 _totalTokens, uint256 _startTime);



    function claimTokens(address beneficiary)

        external

        onlyOwner

        returns (uint256 tokensToClaim)

    {

        uint256 tokensRemaining = holdings[beneficiary].tokensRemaining;

        uint256 startTime = holdings[beneficiary].startTime;

        require(tokensRemaining > 0, "All tokens claimed");



        require(now-(startTime) > MinimumHoldingPeriod, "Claiming period not started yet");



        if (now-(startTime) >= MaximumHoldingPeriod) {



            tokensToClaim = tokensRemaining;

            delete holdings[beneficiary];



        } else {



            uint256 percentage = calculatePercentageToRelease(startTime);



            uint256 tokensNotToClaim = (holdings[beneficiary].tokensCommitted*(100 - percentage))/(100);

            tokensToClaim = tokensRemaining-(tokensNotToClaim);

            tokensRemaining = tokensNotToClaim;

            holdings[beneficiary].tokensRemaining = tokensRemaining;



        }

    }



    function calculatePercentageToRelease(uint256 _startTime) internal view returns (uint256 percentage) {

        // how many 90 day periods have passed

        uint periodsPassed = ((now-(_startTime))/(Interval));

        percentage = periodsPassed*(25); // 25% to be released every 90 days

    }



    function initializeVesting(

        address _beneficiary,

        uint256 _tokens,

        uint256 _startTime

    )

        external

        onlyOwner

    {

        totalCommunityTokensCommitted = totalCommunityTokensCommitted+(_tokens);

        require(totalCommunityTokensCommitted <= CommunityCap);



        if (holdings[_beneficiary].tokensCommitted != 0) {

            holdings[_beneficiary].tokensCommitted = holdings[_beneficiary].tokensCommitted+(_tokens);

            holdings[_beneficiary].tokensRemaining = holdings[_beneficiary].tokensRemaining+(_tokens);



            emit CommunityVestingUpdated(

                _beneficiary,

                holdings[_beneficiary].tokensRemaining,

                holdings[_beneficiary].startTime

            );



        } else {

            holdings[_beneficiary] = Holding(

                _tokens,

                _tokens,

                _startTime

            );



            emit CommunityVestingInitialized(_beneficiary, _tokens, _startTime);

        }

    }

}







contract EcosystemVesting is Ownable {

    using SafeMath for uint256;



    mapping (address => Holding) public holdings;



    uint256 constant public Interval = 90 days;

    uint256 constant public MaximumHoldingPeriod = 630 days;



    uint256 constant public EcosystemCap = 54100000 ether; // 54.1 million tokens



    uint256 public totalEcosystemTokensCommitted;



    struct Holding {

        uint256 tokensCommitted;

        uint256 tokensRemaining;

        uint256 startTime;

    }



    event EcosystemVestingInitialized(address _to, uint256 _tokens, uint256 _startTime);

    event EcosystemVestingUpdated(address _to, uint256 _totalTokens, uint256 _startTime);



    function claimTokens(address beneficiary)

        external

        onlyOwner

        returns (uint256 tokensToClaim)

    {

        uint256 tokensRemaining = holdings[beneficiary].tokensRemaining;

        uint256 startTime = holdings[beneficiary].startTime;

        require(tokensRemaining > 0, "All tokens claimed");



        if (now-(startTime) >= MaximumHoldingPeriod) {



            tokensToClaim = tokensRemaining;

            delete holdings[beneficiary];



        } else {



            uint256 permill = calculatePermillToRelease(startTime);



            uint256 tokensNotToClaim = (holdings[beneficiary].tokensCommitted*(1000 - permill))/(1000);

            tokensToClaim = tokensRemaining-(tokensNotToClaim);

            tokensRemaining = tokensNotToClaim;

            holdings[beneficiary].tokensRemaining = tokensRemaining;



        }

    }



    function calculatePermillToRelease(uint256 _startTime) internal view returns (uint256 permill) {

        // how many 90 day periods have passed

        uint periodsPassed = ((now-(_startTime))/(Interval))+(1);

        permill = periodsPassed*(125); // 125 per thousand to be released every 90 days

    }



    function initializeVesting(

        address _beneficiary,

        uint256 _tokens,

        uint256 _startTime

    )

        external

        onlyOwner

    {

        totalEcosystemTokensCommitted = totalEcosystemTokensCommitted+(_tokens);

        require(totalEcosystemTokensCommitted <= EcosystemCap);



        if (holdings[_beneficiary].tokensCommitted != 0) {

            holdings[_beneficiary].tokensCommitted = holdings[_beneficiary].tokensCommitted+(_tokens);

            holdings[_beneficiary].tokensRemaining = holdings[_beneficiary].tokensRemaining+(_tokens);



            emit EcosystemVestingUpdated(

                _beneficiary,

                holdings[_beneficiary].tokensRemaining,

                holdings[_beneficiary].startTime

            );



        } else {

            holdings[_beneficiary] = Holding(

                _tokens,

                _tokens,

                _startTime

            );



            emit EcosystemVestingInitialized(_beneficiary, _tokens, _startTime);

        }

    }

}







contract SeedPrivateAdvisorVesting is Ownable {

    using SafeMath for uint256;



    enum User { Public, Seed, Private, Advisor }



    mapping (address => Holding) public holdings;



    uint256 constant public MinimumHoldingPeriod = 90 days;

    uint256 constant public Interval = 30 days;

    uint256 constant public MaximumHoldingPeriod = 180 days;



    uint256 constant public SeedCap = 28000000 ether; // 28 million tokens

    uint256 constant public PrivateCap = 9000000 ether; // 9 million tokens

    uint256 constant public AdvisorCap = 7400000 ether; // 7.4 million tokens



    uint256 public totalSeedTokensCommitted;

    uint256 public totalPrivateTokensCommitted;

    uint256 public totalAdvisorTokensCommitted;



    struct Holding {

        uint256 tokensCommitted;

        uint256 tokensRemaining;

        uint256 startTime;

        uint user;

    }



    event VestingInitialized(address _to, uint256 _tokens, uint256 _startTime, uint user);

    event VestingUpdated(address _to, uint256 _totalTokens, uint256 _startTime, uint user);



    function claimTokens(address beneficiary)

        external

        onlyOwner

        returns (uint256 tokensToClaim)

    {

        uint256 tokensRemaining = holdings[beneficiary].tokensRemaining;

        uint256 startTime = holdings[beneficiary].startTime;

        require(tokensRemaining > 0, "All tokens claimed");



        require(now-(startTime) > MinimumHoldingPeriod, "Claiming period not started yet");



        if (now-(startTime) >= MaximumHoldingPeriod) {



            tokensToClaim = tokensRemaining;

            delete holdings[beneficiary];



        } else {



            uint256 percentage = calculatePercentageToRelease(startTime);



            uint256 tokensNotToClaim = (holdings[beneficiary].tokensCommitted*(100 - percentage))/(100);

            tokensToClaim = tokensRemaining-(tokensNotToClaim);

            tokensRemaining = tokensNotToClaim;

            holdings[beneficiary].tokensRemaining = tokensRemaining;



        }

    }



    function calculatePercentageToRelease(uint256 _startTime) internal view returns (uint256 percentage) {

        // how many 30 day periods have passed

        uint periodsPassed = ((now-(_startTime+(MinimumHoldingPeriod)))/(Interval))+(1);

        percentage = periodsPassed*(25); // 25% to be released every 30 days

    }



    function initializeVesting(

        address _beneficiary,

        uint256 _tokens,

        uint256 _startTime,

        uint8 user

    )

        external

        onlyOwner

    {

        uint _user;
        uint8 p1 = uint8(1);
        uint8 p2 = uint8(2);
        uint8 p3 = uint8(3);
        if (user == p1) {

            _user = 1;

            totalSeedTokensCommitted = totalSeedTokensCommitted+(_tokens);

            require(totalSeedTokensCommitted <= SeedCap);

        } else if (user == p2) {

            _user = 2;

            totalPrivateTokensCommitted = totalPrivateTokensCommitted+(_tokens);

            require(totalPrivateTokensCommitted <= PrivateCap);

        } else if (user == p3) {

            _user = 3;

            totalAdvisorTokensCommitted = totalAdvisorTokensCommitted+(_tokens);

            require(totalAdvisorTokensCommitted <= AdvisorCap);

        } else {

            require(true == false);

        }



        if (holdings[_beneficiary].tokensCommitted != 0) {

            holdings[_beneficiary].tokensCommitted = holdings[_beneficiary].tokensCommitted+(_tokens);

            holdings[_beneficiary].tokensRemaining = holdings[_beneficiary].tokensRemaining+(_tokens);



            emit VestingUpdated(

                _beneficiary,

                holdings[_beneficiary].tokensRemaining,

                holdings[_beneficiary].startTime,

                holdings[_beneficiary].user

            );



        } else {

            holdings[_beneficiary] = Holding(

                _tokens,

                _tokens,

                _startTime,

                _user

            );



            emit VestingInitialized(_beneficiary, _tokens, _startTime, _user);

        }

    }

}





contract TeamVesting is Ownable {

    using SafeMath for uint256;



    mapping (address => Holding) public holdings;



    uint256 constant public MinimumHoldingPeriod = 180 days;

    uint256 constant public Interval = 180 days;

    uint256 constant public MaximumHoldingPeriod = 720 days;



    uint256 constant public TeamCap = 12200000 ether; // 12.2 million tokens



    uint256 public totalTeamTokensCommitted;



    struct Holding {

        uint256 tokensCommitted;

        uint256 tokensRemaining;

        uint256 startTime;

    }



    event TeamVestingInitialized(address _to, uint256 _tokens, uint256 _startTime);

    event TeamVestingUpdated(address _to, uint256 _totalTokens, uint256 _startTime);



    function claimTokens(address beneficiary)

        external

        onlyOwner

        returns (uint256 tokensToClaim)

    {

        uint256 tokensRemaining = holdings[beneficiary].tokensRemaining;

        uint256 startTime = holdings[beneficiary].startTime;

        require(tokensRemaining > 0, "All tokens claimed");



        require(now-(startTime) > MinimumHoldingPeriod, "Claiming period not started yet");



        if (now-(startTime) >= MaximumHoldingPeriod) {



            tokensToClaim = tokensRemaining;

            delete holdings[beneficiary];



        } else {



            uint256 percentage = calculatePercentageToRelease(startTime);



            uint256 tokensNotToClaim = (holdings[beneficiary].tokensCommitted*(100 - percentage))/(100);



            tokensToClaim = tokensRemaining-(tokensNotToClaim);

            tokensRemaining = tokensNotToClaim;

            holdings[beneficiary].tokensRemaining = tokensRemaining;



        }

    }



    function calculatePercentageToRelease(uint256 _startTime) internal view returns (uint256 percentage) {

        // how many 180 day periods have passed

        uint periodsPassed = ((now-(_startTime))/(Interval));

        percentage = periodsPassed*(25); // 25% to be released every 180 days

    }



    function initializeVesting(

        address _beneficiary,

        uint256 _tokens,

        uint256 _startTime

    )

        external

        onlyOwner

    {

        totalTeamTokensCommitted = totalTeamTokensCommitted+(_tokens);

        require(totalTeamTokensCommitted <= TeamCap);



        if (holdings[_beneficiary].tokensCommitted != 0) {

            holdings[_beneficiary].tokensCommitted = holdings[_beneficiary].tokensCommitted+(_tokens);

            holdings[_beneficiary].tokensRemaining = holdings[_beneficiary].tokensRemaining+(_tokens);



            emit TeamVestingUpdated(

                _beneficiary,

                holdings[_beneficiary].tokensRemaining,

                holdings[_beneficiary].startTime

            );



        } else {

            holdings[_beneficiary] = Holding(

                _tokens,

                _tokens,

                _startTime

            );



            emit TeamVestingInitialized(_beneficiary, _tokens, _startTime);

        }

    }

}







interface TokenInterface {

    function totalSupply() external view returns (uint256);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transfer(address _to, uint256 _value) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

}





contract Vesting is Ownable {

    using SafeMath for uint256;



    enum VestingUser  { Public, Seed, Private, Advisor, Team, Community, Ecosystem }



    TokenInterface public token;

    CommunityVesting public communityVesting;

    TeamVesting public teamVesting;

    EcosystemVesting public ecosystemVesting;

    SeedPrivateAdvisorVesting public seedPrivateAdvisorVesting;

    mapping (address => uint ) public userCategory;

    uint256 public totalAllocated;



    event TokensReleased(address _to, uint256 _tokensReleased, uint  user);



    constructor(address _token) public {

        //require(_token != 0x0, "Invalid address");

        token = TokenInterface(_token);

        communityVesting = new CommunityVesting();

        teamVesting = new TeamVesting();

        ecosystemVesting = new EcosystemVesting();

        seedPrivateAdvisorVesting = new SeedPrivateAdvisorVesting();

    }



    function claimTokens() external {

        uint8 category = uint8(userCategory[msg.sender]);



        uint256 tokensToClaim;



        if (category == 1 || category == 2 || category == 3) {

            tokensToClaim = seedPrivateAdvisorVesting.claimTokens(msg.sender);

        } else if (category == 4) {

            tokensToClaim = teamVesting.claimTokens(msg.sender);

        } else if (category == 5) {

            tokensToClaim = communityVesting.claimTokens(msg.sender);

        } else if (category == 6){

            tokensToClaim = ecosystemVesting.claimTokens(msg.sender);

        } else {

            revert( "incorrect category, maybe unknown user" );

        }



        totalAllocated = totalAllocated-(tokensToClaim);
        bool p1 = token.transfer(msg.sender, tokensToClaim);
        require(p1 == true, "Insufficient balance in vesting contract");

        emit TokensReleased(msg.sender, tokensToClaim, userCategory[msg.sender]);

    }



    function initializeVesting(

        address _beneficiary,

        uint256 _tokens,

        uint256 _startTime,

        uint  user

    )

        external

        onlyOwner

    {

        uint8 category = uint8(user);

        require(category != 0, "Not eligible for vesting");


uint8 p1 = uint8(userCategory[_beneficiary]);
        require( p1 == 0 || userCategory[_beneficiary] == user, "cannot change user category" );

        userCategory[_beneficiary] = user;

        totalAllocated = totalAllocated+(_tokens);



        if (category == 1 || category == 2 || category == 3) {

            seedPrivateAdvisorVesting.initializeVesting(_beneficiary, _tokens, _startTime, category);

        } else if (category == 4) {

            teamVesting.initializeVesting(_beneficiary, _tokens, _startTime);

        } else if (category == 5) {

            communityVesting.initializeVesting(_beneficiary, _tokens, _startTime);

        } else if (category == 6){

            ecosystemVesting.initializeVesting(_beneficiary, _tokens, _startTime);

        } else {

            require(true == false);

        }

    }



    function claimUnallocated( address _sendTo) external onlyOwner{
        address p1 = address(this);
        uint256 allTokens = token.balanceOf(p1);

        token.transfer(_sendTo, allTokens);

    }

}