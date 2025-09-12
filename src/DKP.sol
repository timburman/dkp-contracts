// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract DKP is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    struct Submission {
        uint256 id;
        bytes32 contentHash;
        address author;
        uint256 timestamp;
        uint256 upVotes;
        uint256 downVotes;
    }

    uint256 private _idCounter;

    // -- Mappings --
    mapping(uint256 => Submission) public submissions;

    // Mapping SubmissionId => (Voter => hasVoted)
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // -- Events --
    event ContentSubmitted(uint256 indexed Id, address indexed author);
    event Voted(uint256 indexed Id, address indexed user);

    // Initializer
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();

        _idCounter = 1;
    }

    // Public and External functions

    function submitContent(bytes32 _contentHash) public returns (uint256 id) {
        uint newId = _idCounter++;
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

    // -- View Functions --
    function getSubmissions(uint256 submissionId) external view returns (Submission memory) {
        return submissions[submissionId];
    }

    function getCurrentId() external view returns (uint) {
        return _idCounter;
    }

    // -- Upgradable Functionality --
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
