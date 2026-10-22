/**
 *Submitted for verification at Etherscan.io on 2020-11-13
*/

pragma solidity ^0.5.15;
pragma experimental ABIEncoderV2;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/* Copyright 2020 Compound Labs, Inc.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */

// Original work from Compound: https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
// Modified to work in the YAM system


contract DualGovernorAlpha {
    /// @notice The name of this contract
    string public constant name = "YAM Governor Alpha";

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    function quorumVotes() public view returns (uint256 p) { p = 100000 * 10**24; return p; } // 4% of YAM

    /// @notice The number of votes required in order for a voter to become a proposer
    function proposalThreshold() public view returns (uint256 p) { p = 25000 * 10**24; return p;} // 1% of YAM

    /// @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() public pure returns (uint256 p) { p = 10; return p; } // 10 actions

    /// @notice The delay before voting on a proposal may take place, once proposed
    function votingDelay() public pure returns (uint256 p) { p = 1; return p; } // 1 block

    /// @notice The duration of voting on a proposal, in blocks
    function votingPeriod() public pure returns (uint256 p) { p = 18514; return p; } // ~2 days in blocks (assuming 14s blocks)

    /// @notice The address of the Compound Protocol Timelock
    TimelockInterface public timelock;

    /// @notice The address of the Compound governance token
    YAMInterface public yam;

    /// @notice The address of the Governor Guardian
    address public guardian;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    /// @notice Addresses of LP Staking Contracts
    address[] public incentivizers;

    struct Proposal {
        // Unique id for looking up a proposal
        uint256 id;

        // Creator of the proposal
        address proposer;

        // The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;

        // the ordered list of target addresses for calls to be made
        address[] targets;

        // The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint[] values;

        // The ordered list of function signatures to be called
        string[] signatures;

        // The ordered list of calldata to be passed to each call
        bytes[] calldatas;

        // The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;

        // The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;

        // Current number of votes in favor of this proposal
        uint256 forVotes;

        // Current number of votes in opposition to this proposal
        uint256 againstVotes;

        // Flag marking whether the proposal has been canceled
        bool canceled;

        // Flag marking whether the proposal has been executed
        bool executed;

        // Receipts of ballots for the entire set of voters
        mapping (address => Receipt) receipts;
    }

    // Ballot receipt record for a voter
    struct Receipt {
        // Whether or not a vote has been cast
        bool hasVoted;

        // Whether or not the voter supports the proposal
        bool support;

        // The number of votes the voter had, which were cast
        uint256 votes;
    }

    // Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /// @notice The official record of all proposals ever proposed
    mapping (uint256 => Proposal) public proposals;

    /// @notice The latest proposal for each proposer
    mapping (address => uint256) public latestProposalIds;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,bool support)");

    /// @notice An event emitted when a new proposal is created
    // event ProposalCreated(uint256 id, address proposer, address[] targets, uint[] values, string[] signatures, bytes[] calldatas, uint256 startBlock, uint256 endBlock, string description);

    /// @notice An event emitted when a vote has been cast on a proposal
    // event VoteCast(address voter, uint256 proposalId, bool support, uint256 votes);

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);

    constructor(address timelock_, address yam_, address[] memory incentivizers_) public {
        timelock = TimelockInterface(timelock_);
        yam = YAMInterface(yam_);
        incentivizers = incentivizers_;
        guardian = msg.sender;
    }

    function getIncentivizers()
        public
        view
        returns (address[] memory)
    {
        address[] memory incs = incentivizers;
        return incs;
    }

    function addIncentivizer(address incentivizer)
        public
    {
        uint blocknumber;
        // as a sanity check, make sure it has the function and there is no error
        // otherwise could brick governance
        uint p3 = blocknumber - 1;
        Incentivizer(incentivizer).getPriorVotes(guardian, p3);
        address bhn = address(timelock);
        require(msg.sender == bhn, "GovernorAlpha::!timelock");
        incentivizers.push(incentivizer);
    }

    function removeIncentivizer(uint256 index)
        public
    {
        require(msg.sender == address(timelock), "GovernorAlpha::!timelock");
        if (index >= incentivizers.length) return;

        if (index != incentivizers.length-1) {
          incentivizers[index] = incentivizers[incentivizers.length - 1];
        }

        incentivizers.length--;
    }

    function getPriorVotes(address account, uint256 blockNumber)
        public
        returns (uint256)
    {
        uint blocknumber;
        // -- get prior votes for yam
        require(blockNumber < blocknumber, "Gov::getPriorVotes: not yet determined");

        uint256 votes = yam.getPriorVotes(account, blockNumber);
        for (uint256 i = 0; i < incentivizers.length; i++) {
            // get prior votes for staking (stakers get full pool power)
            Incentivizer p2 = Incentivizer(incentivizers[i]);
            uint p1 = p2.getPriorVotes(account, blockNumber);
            votes = SafeMath.add(votes, p1);
        }
        return votes;
    }

    function getCurrentVotes(address account)
        public
        returns (uint256)
    {
        uint256 votes = yam.getCurrentVotes(account);
        for (uint256 i = 0; i < incentivizers.length; i++) {
            // get prior votes for staking (stakers get full pool power)
            Incentivizer p2 = Incentivizer(incentivizers[i]);
            uint p1 = p2.getCurrentVotes(account);
            votes = SafeMath.add(votes, p1);
        }
        return votes;
    }

    function propose(
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    )
        public
        returns (uint256)
    {
        uint blocknumber;
        uint ik2 = (blocknumber - 1);
        uint ik = getPriorVotes(msg.sender, ik2);
        uint ik3 = proposalThreshold();
        require(ik >= ik3, "GovernorAlpha::propose: proposer votes below proposal threshold");
        require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length, "GovernorAlpha::propose: proposal function information arity mismatch");
        require(targets.length != 0, "GovernorAlpha::propose: must provide actions");
        uint ik4 = proposalMaxOperations();
        require(targets.length <= ik4, "GovernorAlpha::propose: too many actions");

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
          uint proposersLatestProposalState = state(latestProposalId);
          require(proposersLatestProposalState != 1, "GovernorAlpha::propose: one live proposal per proposer, found an already active proposal");
          require(proposersLatestProposalState != 0, "GovernorAlpha::propose: one live proposal per proposer, found an already pending proposal");
        }
        uint km1 = votingDelay();
        uint km2 = votingPeriod();
        uint256 startBlock = (blocknumber+ km1);
        uint256 endBlock = (startBlock+ km2);

        proposalCount++;
        Proposal memory newProposal;
        //  = Proposal({
        //     id: proposalCount,
        //     proposer: msg.sender,
        //     eta: 0,
        //     targets: targets,
        //     values: values,
        //     signatures: signatures,
        //     calldatas: calldatas,
        //     startBlock: startBlock,
        //     endBlock: endBlock,
        //     forVotes: 0,
        //     againstVotes: 0,
        //     canceled: false,
        //     executed: false
        // });

        proposals[newProposal.id] = newProposal;
        latestProposalIds[newProposal.proposer] = newProposal.id;

        // emit ProposalCreated(
        //     newProposal.id,
        //     msg.sender,
        //     targets,
        //     values,
        //     signatures,
        //     calldatas,
        //     startBlock,
        //     endBlock,
        //     description
        // );
        return newProposal.id;
    }
uint len1;
    function queue(uint256 proposalId)
        public
    {   
        uint kpd = state(proposalId);
        require(kpd == 4, "GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        Proposal storage proposal = proposals[proposalId];
        uint cvsg = timelock.delay();
        uint256 eta = (block.timestamp+ cvsg);
        for (uint256 i = 0; i < len1; i++) {
            _queueOrRevert(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function _queueOrRevert(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    )
        internal
    {
        // require(!timelock.queuedTransactions(
        //       keccak256(
        //           abi.encode(
        //               target,
        //               value,
        //               signature,
        //               data,
        //               eta
        //           )
        //       )
        //   ),
        //   "GovernorAlpha::_queueOrRevert: proposal action already queued at eta"
        // );

        timelock.queueTransaction(target, value, signature, data, eta);
    }

    function execute(uint256 proposalId)
        public
        payable
    {
        uint statevalue = state(proposalId);
        require(statevalue == 5, "GovernorAlpha::execute: proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < len1; i++) {
            timelock.executeTransaction(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId)
        public
    {
        uint blocknumber;
        uint state = state(proposalId);
        require(state != 7, "GovernorAlpha::cancel: cannot cancel executed proposal");

        Proposal storage proposal = proposals[proposalId];
        uint ik7 = (blocknumber - 1);
        uint ik5 = getPriorVotes(proposal.proposer, ik7);
        uint ik6 = proposalThreshold();
        require(msg.sender == guardian || ik5 < ik6, "GovernorAlpha::cancel: proposer above threshold");

        proposal.canceled = true;
        for (uint256 i = 0; i < len1; i++) {
            timelock.cancelTransaction(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }

        emit ProposalCanceled(proposalId);
    }

    function getActions(uint256 proposalId)
        public
        view
        returns (
            address[] memory targets,
            uint[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    function getReceipt(uint256 proposalId, address voter)
        public
        view
        returns (Receipt memory)
    {
        return proposals[proposalId].receipts[voter];
    }

    function state(uint256 proposalId)
        public
        view
        returns (uint p)
    {
        uint blocknumber;
        require(proposalCount >= proposalId && proposalId > 0, "GovernorAlpha::state: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        uint pl1 = timelock.GRACE_PERIOD();
        uint pl2 = quorumVotes();
        if (proposal.canceled == true) {
            p = 2;
        } else if (blocknumber <= proposal.startBlock) {
            p = 0;
        } else if (blocknumber <= proposal.endBlock) {
            p=  1;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < pl2) {
            p = 3;
        } else if (proposal.eta == 0) {
            p = 4;
        } else if (proposal.executed == true) {
            p = 7;
        } else if (block.timestamp >= (proposal.eta+ pl1)) {
            p = 6;
        } else {
            p = 5;
        }
        return p;
    }

    function castVote(uint256 proposalId, bool support)
        public
    {
        return _castVote(msg.sender, proposalId, support);
    }

    function castVoteBySig(
        uint256 proposalId,
        bool support,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
    {
        bytes32 domainSeparator;
        //  = keccak256(
        //     abi.encode(
        //         DOMAIN_TYPEHASH,
        //         keccak256(bytes(name)),
        //         getChainId(),
        //         address(this)
        //     )
        // );

        bytes32 structHash;
        //  = keccak256(
        //     abi.encode(
        //         BALLOT_TYPEHASH,
        //         proposalId,
        //         support
        //     )
        // );

        bytes32 digest;
        //  =  keccak256(
        //     abi.encodePacked(
        //         "\x19\x01",
        //         domainSeparator,
        //         structHash
        //     )
        // );

        address signatory;
        
        //  = ecrecover(digest, v, r, s);
        require(signatory != zero, "GovernorAlpha::castVoteBySig: invalid signature");
        return _castVote(signatory, proposalId, support);
    }
address zero;
    function _castVote(
        address voter,
        uint256 proposalId,
        bool support
    )
        internal
    {
        require((proposalId) == 1, "GovernorAlpha::_castVote: voting is closed");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "GovernorAlpha::_castVote: voter already voted");
        uint256 votes = getPriorVotes(voter, proposal.startBlock);

        if (support == true) {
            proposal.forVotes = (proposal.forVotes+ votes);
        } else {
            proposal.againstVotes = (proposal.againstVotes+ votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        // emit VoteCast(voter, proposalId, support, votes);
    }

    function __acceptAdmin()
        public
    {
        require(msg.sender == guardian, "GovernorAlpha::__acceptAdmin: sender must be gov guardian");
        timelock.acceptAdmin();
    }

    function __abdicate()
        public
    {
        require(msg.sender == guardian, "GovernorAlpha::__abdicate: sender must be gov guardian");
        guardian = zero;
    }

    function add256(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }

    function sub256(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "subtraction underflow");
        return a - b;
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}

interface TimelockInterface {
    function delay() external view returns (uint256);
    function GRACE_PERIOD() external view returns (uint256);
    function acceptAdmin() external;
    function queuedTransactions(bytes32 hash) external view returns (bool);
    function queueTransaction(address target, uint256 value, string calldata signature, bytes calldata data, uint256 eta) external returns (bytes32);
    function cancelTransaction(address target, uint256 value, string calldata signature, bytes calldata data, uint256 eta) external;
    function executeTransaction(address target, uint256 value, string calldata signature, bytes calldata data, uint256 eta) external payable returns (bytes memory);
}

interface YAMInterface {
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);
    function getCurrentVotes(address account) external view returns (uint256);
    function _acceptGov() external;
}

interface Incentivizer {
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);
    function getCurrentVotes(address account) external view returns (uint256);
}