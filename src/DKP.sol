// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


contract DKP is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    struct Submission {
        uint id;
        bytes32 contentHash;
        address author;
        uint timestamp;
        uint upVotes;
        uint downVotes;
    }

    uint public idCounter;

    // -- Mappings --
    mapping(uint => Submission) public submissions;

    // Mapping SubmissionId => (Voter => hasVoted)
    mapping(uint => mapping(address => bool))  public hasVoted;

    // -- Events --
    event ContentSubmitted(uint Id, address indexed author);
    event Voted(uint Id, address indexed user);


    // Initializer
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();
        idCounter = 0;
    }

    // Public and External functions

    function submitContent(bytes32 _contentHash) public returns(uint id) {

        idCounter++;
        Submission storage s = submissions[idCounter];

        s.id = idCounter;
        s.contentHash = _contentHash;
        s.author = msg.sender;
        s.timestamp = block.timestamp;
        
        emit ContentSubmitted(idCounter, msg.sender);

        return idCounter;
    }

    function vote(uint submissionId, bool _isUpvote) external  nonReentrant{
        Submission storage s = submissions[submissionId];

        require(s.id == submissionId, "Invalid Submission Id");
        require(hasVoted[submissionId][msg.sender] == false, "Already Voted");

        hasVoted[submissionId][msg.sender] = true;

        if (_isUpvote) {
            s.upVotes++;
        } else {
            s.downVotes++;
        }

        emit Voted(submissionId, msg.sender);
    }

}