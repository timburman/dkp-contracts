// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {DKPToken} from "./DKPToken.sol";

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
        bool rewardClaimed;
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
    event ContentSubmitted(uint256 indexed id, address indexed author);
    event Voted(uint256 indexed id, address indexed user);
    event SubmissionBoosted(address indexed user, uint256 indexed id, uint256 boostAmount);
    event SubmissionFinalized(uint256 indexed id, SubmissionStatus indexed status);
    event ReclaimedReputation(uint256 indexed id, address indexed user, uint256 reputationReclaimed);

    // Constants
    uint256 public constant VOTE_STAKE_AMOUNT_MIN = 5;
    uint256 public constant VOTE_STAKE_AMOUNT_MAX = 50;
    uint256 public constant SUBMISSION_COLLATERAL = 25;
    uint256 public minVoteCountForReview = 100;

    // Initializer
    function initialize(address initialOwner, address dkpTokenAddress) public initializer {
        require(initialOwner != address(0), "Address cannot be 0");
        require(dkpTokenAddress != address(0), "Address cannot be 0");
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        dkpToken = DKPToken(dkpTokenAddress);
        _idCounter = 1;
    }

    // Public and External functions

    function submitContent(bytes32 _contentHash) public returns (uint256 id) {
        uint256 authorReputation = getReputationScore(msg.sender);
        require(authorReputation >= SUBMISSION_COLLATERAL, "DKP: Insufficient reputation for collateral");

        reputationScore[msg.sender] = authorReputation - SUBMISSION_COLLATERAL;

        uint256 newId = _idCounter++;
        Submission storage s = submissions[newId];

        s.id = newId;
        s.contentHash = _contentHash;
        s.author = msg.sender;
        s.timestamp = block.timestamp;

        emit ContentSubmitted(newId, msg.sender);

        return newId;
    }

    function vote(uint256 submissionId, uint256 voteWeight, bool _isUpvote) external nonReentrant {
        uint256 userReputationScore = getReputationScore(msg.sender);

        require(
            voteWeight >= VOTE_STAKE_AMOUNT_MIN && voteWeight <= VOTE_STAKE_AMOUNT_MAX,
            "DKP: Voting Weight out of range 5 to 50"
        );
        require(voteWeight <= userReputationScore, "DKP: Not enough reputation");

        Submission storage s = submissions[submissionId];
        SubmissionStatus currentStatus = getSubmissionStatus(submissionId);
        require(s.author != address(0), "DKP: Invalid Submission Id");
        require(hasVoted[submissionId][msg.sender] == false, "Already Voted");
        require(
            currentStatus == SubmissionStatus.Pending || currentStatus == SubmissionStatus.InReview,
            "DKP: Voting period is over"
        );

        hasVoted[submissionId][msg.sender] = true;
        userReputationScore -= voteWeight;

        reputationScore[msg.sender] = userReputationScore;

        lockedReputation[submissionId][msg.sender] += voteWeight;

        if (_isUpvote) {
            userVotes[submissionId][msg.sender] = VoteChoice.Up;
            s.upVotes += voteWeight;
        } else {
            userVotes[submissionId][msg.sender] = VoteChoice.Down;
            s.downVotes += voteWeight;
        }

        if (currentStatus == SubmissionStatus.Pending) {
            s.totalVoteWeight += voteWeight;
            if (s.totalVoteWeight >= minVoteCountForReview) {
                s.reviewEndTime = block.timestamp + 7 days;
            }
        }

        voterVoteCount[msg.sender]++;
        emit Voted(submissionId, msg.sender);
    }

    function boost(uint256 submissionId, uint256 boostAmount) external nonReentrant {
        require(submissions[submissionId].author != address(0), "DKP: Invalid Submission Id");
        require(dkpToken.allowance(msg.sender, address(this)) >= boostAmount, "Not enough tokens approved");
        require(dkpToken.transferFrom(msg.sender, address(this), boostAmount), "Transfer Failed");

        Submission storage s = submissions[submissionId];
        s.boostAmount += boostAmount;

        emit SubmissionBoosted(msg.sender, submissionId, boostAmount);
    }

    function claimRewards(uint256 submissionId) external nonReentrant {
        Submission storage s = submissions[submissionId];
        require(msg.sender == s.author, "DKP: Not the author");
        require(s.rewardClaimed == false, "DKP: Reward already claimed");
        require(getSubmissionStatus(submissionId) == SubmissionStatus.Verified, "DKP: Submission not verified");

        uint256 reward;

        s.rewardClaimed = true;
        reputationScore[msg.sender] += 50;
        reward = 50 ether;
        require(dkpToken.transfer(s.author, reward), "DKP: Token transfer failed");
    }

    function reclaimReputation(uint256 submissionId) external {
        uint256 reputationReturn = checkReputationReclaim(submissionId, msg.sender);
        lockedReputation[submissionId][msg.sender] = 0;
        reputationScore[msg.sender] += reputationReturn;

        emit ReclaimedReputation(submissionId, msg.sender, reputationReturn);
    }

    // -- View Functions --
    function getSubmissions(uint256 submissionId) external view returns (Submission memory) {
        return submissions[submissionId];
    }

    function getCurrentId() external view returns (uint256) {
        return _idCounter;
    }

    function getReputationScore(address user) public view returns (uint256) {
        if (reputationScore[user] == 0 && voterVoteCount[user] == 0) {
            return 10;
        }

        return reputationScore[user];
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

    function getSubmissionStatus(uint256 submissionId) public view returns (SubmissionStatus) {
        Submission storage s = submissions[submissionId];
        require(s.author != address(0), "DKP: Invalid Submission Id");

        if (s.reviewEndTime == 0) {
            return SubmissionStatus.Pending;
        }

        if (block.timestamp < s.reviewEndTime) {
            return SubmissionStatus.InReview;
        }

        if (s.upVotes > s.downVotes) {
            return SubmissionStatus.Verified;
        } else {
            return SubmissionStatus.Rejected;
        }
    }

    function checkReputationReclaim(uint256 submissionId, address user)
        public
        view
        returns (uint256 reputationReturn)
    {
        SubmissionStatus currentStatus = getSubmissionStatus(submissionId);
        require(
            currentStatus == SubmissionStatus.Verified || currentStatus == SubmissionStatus.Rejected,
            "DKP: Submission not finalized"
        );
        uint256 reputationStakedAmount = lockedReputation[submissionId][user];
        require(reputationStakedAmount > 0, "DKP: No reputation staked");
        VoteChoice userVote = userVotes[submissionId][user];
        bool votedCorrectly = (currentStatus == SubmissionStatus.Verified && userVote == VoteChoice.Up)
            || (currentStatus == SubmissionStatus.Rejected && userVote == VoteChoice.Down);
        
        if (votedCorrectly) {
            reputationReturn = calculateRepuationReward(reputationStakedAmount) + reputationStakedAmount;
        }
        else {
            reputationReturn = 0;
        }
        
    }

    // -- Internal Functions --

    // -- Owner Functions --
    function supplyReputation(address user) external onlyOwner {
        reputationScore[user] += 25;
    }

    function setMinVoteCountForReview(uint256 _newCount) external onlyOwner {
        minVoteCountForReview = _newCount;
    }

    // -- Upgradable Functionality --
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
