// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./DKPToken.sol";

contract DKP is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    struct Submission {
        uint256 id;
        bytes32 contentHash;
        address author;
        uint256 timestamp;
        uint256 upVotes;
        uint256 downVotes;
        uint256 boostAmount;
    }

    uint256 private _idCounter;
    DKPToken public dkpToken;

    // -- Mappings --
    mapping(uint256 => Submission) public submissions;

    // Mapping SubmissionId => (Voter => hasVoted)
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // Mapping Reputation Score: (Voter => Score)
    mapping(address => uint256) public reputationScore;

    // -- Events --
    event ContentSubmitted(uint256 indexed Id, address indexed author);
    event Voted(uint256 indexed Id, address indexed user);
    event SubmissionBoosted(address indexed user, uint256 indexed Id, uint256 boostAmount);

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

        hasVoted[submissionId][msg.sender] = true;

        if (_isUpvote) {
            s.upVotes++;
        } else {
            s.downVotes++;
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

    // -- Upgradable Functionality --
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
