// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./DKPToken.sol";

contract DKP is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    // Enums

    enum VoteChoice {
        None,
        Up,
        Down
    }

    enum SubmissionStatus {
        Pending,
        InReview,
        Verified,
        Rejected,
        Claimed
    }

    struct Submission {
        uint256 id;
        bytes32 contentHash;
        address author;
        uint256 timestamp;
        uint256 upVotes;
        uint256 downVotes;
        uint256 boostAmount;
        uint256 totalVoteWeight;
        uint256 reviewEndTime;
        SubmissionStatus status;
    }

    uint256 private _idCounter;
    DKPToken public dkpToken;

    // -- Mappings --
    mapping(uint256 => Submission) public submissions;

    // Mapping SubmissionId => (Voter => hasVoted)
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // Mapping Reputation Score: (Voter => Score)
    mapping(address => uint256) public reputationScore;

    // Mapping to store each voter's voting choice. (submissionId => (Voter => VoteChoice))
    mapping(uint256 => mapping(address => VoteChoice)) public userVotes;

    // Mapping to store reputation locked in a vote. (submissionId => (Voter => amountLocked))
    mapping(uint256 => mapping(address => uint256)) public lockedReputation;

    // Mapping to store the total votes of each voter
    mapping(address => uint256) public voterVoteCount;

    // -- Events --
    event ContentSubmitted(uint256 indexed Id, address indexed author);
    event Voted(uint256 indexed Id, address indexed user);
    event SubmissionBoosted(address indexed user, uint256 indexed Id, uint256 boostAmount);

    // Constants
    uint256 public constant VOTE_STAKE_AMOUNT = 5;
    uint256 public constant CORRECT_VOTE_REWARD = 7;

    // Initializer
    function initialize(address initialOwner, address dkpTokenAddress) public initializer {
        require(initialOwner != address(0), "Address cannot be 0");
        require(dkpTokenAddress != address(0), "Address cannot be 0");
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        _idCounter = 1;

        dkpToken = DKPToken(dkpTokenAddress);
    }

    // Public and External functions

    function submitContent(bytes32 _contentHash) public returns (uint256 id) {
        uint256 newId = _idCounter++;
        Submission storage s = submissions[newId];

        s.id = newId;
        s.contentHash = _contentHash;
        s.author = msg.sender;
        s.timestamp = block.timestamp;

        emit ContentSubmitted(newId, msg.sender);

        return newId;
    }

    function vote(uint256 submissionId, bool _isUpvote) external nonReentrant {
        Submission storage s = submissions[submissionId];

        require(s.id == submissionId && s.id != 0, "Invalid Submission Id");
        require(hasVoted[submissionId][msg.sender] == false, "Already Voted");
        require(
            s.status == SubmissionStatus.Pending || s.status == SubmissionStatus.InReview, "DKP: Voting period is over"
        );

        uint256 voteWeight = reputationScore[msg.sender];

        if (voteWeight == 0) {
            voteWeight = 10;
        }

        emit Voted(submissionId, msg.sender);
    }

    function boost(uint256 submissionId, uint256 boostAmount) external nonReentrant {
        require(dkpToken.allowance(msg.sender, address(this)) >= boostAmount, "Not enough tokens approved");

        require(dkpToken.transferFrom(msg.sender, address(this), boostAmount), "Transfer Failed");

        Submission storage s = submissions[submissionId];
        s.boostAmount += boostAmount;

        emit SubmissionBoosted(msg.sender, submissionId, boostAmount);
    }

    // -- View Functions --
    function getSubmissions(uint256 submissionId) external view returns (Submission memory) {
        return submissions[submissionId];
    }

    function getCurrentId() external view returns (uint256) {
        return _idCounter;
    }

    // -- Pure Functions --
    function calculateRepuationReward(uint256 reputationStake) public pure returns (uint256 bonusAmount) {
        uint256 x1 = 5;
        uint256 x2 = 50;

        uint256 p1 = 4000; // 40% at min 5 using basisPoints
        uint256 p2 = 2000; // 20% at max 50 using basisPoints

        uint256 bonusPercentage = p1 - ((reputationStake - x1) * (p1 - p2)) / (x2 - x1);

        bonusAmount = (reputationStake * bonusPercentage) / 10000;
    }

    // -- Upgradable Functionality --
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
