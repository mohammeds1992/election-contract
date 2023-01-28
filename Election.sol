// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

contract Election {
    enum ElectionStatus {
        NOT_STARTED,
        ACTIVE,
        PAUSED,
        CLOSED
    }

    struct ElectionStruct {
        bytes32 electionId;
        string name;
        string description;
        uint256 createdTime;
        uint256 startTime;
        uint256 stopTime;
        uint256 voteFee;
        bool paused;
        address createdBy;
        string[] parties;
        mapping(address => bool) voters;
        mapping(address => bool) admins;
        mapping(string => uint256) voteCounts;
        mapping(address => bool) voted;
        mapping(address => uint256) voteTimestamps;
        string winnerParty;
    }

    mapping(bytes32 => ElectionStruct) public elections;
    address public owner;

    address private newOwner;
    mapping(bytes32 => bool) private lock;
    mapping(string => bytes32) private electionNameToId;

    event LogElectionCreated(
        address indexed initiator,
        bytes32 indexed electionId,
        string name,
        string description,
        uint256 timestamp,
        uint256 startTime,
        uint256 stopTime,
        uint256 voteFee
    );
    event LogElectionUpdated(
        address indexed initiator,
        bytes32 indexed electionId,
        string name,
        string description,
        uint256 timestamp,
        uint256 startTime,
        uint256 stopTime,
        uint256 voteFee
    );
    event LogElectionPaused(
        address indexed initiator,
        bytes32 indexed electionId,
        uint256 timestamp
    );
    event LogElectionResumed(
        address indexed initiator,
        bytes32 indexed electionId,
        uint256 timestamp
    );
    event LogAdminCreated(
        address indexed initiator,
        bytes32 indexed electionId,
        address indexed admin,
        uint256 timestamp
    );
    event LogAdminRemoved(
        address indexed initiator,
        bytes32 indexed electionId,
        address indexed admin,
        uint256 timestamp
    );
    event LogPartyCreated(
        address indexed initiator,
        bytes32 indexed electionId,
        string party,
        uint256 timestamp
    );
    event LogPartyRemoved(
        address indexed initiator,
        bytes32 indexed electionId,
        string party,
        uint256 timestamp
    );
    event LogTransferOwnership(address indexed initiator, uint256 timestamp);
    event LogAcceptOwnership(address indexed initiator, uint256 timestamp);
    event LogVote(
        address indexed initiator,
        bytes32 indexed electionId,
        string party,
        uint256 timestamp
    );
    event LogWinnerUpdated(
        address indexed initiator,
        bytes32 indexed electionId,
        string party,
        uint256 timestamp
    );

    constructor() {
        owner = msg.sender;
    }

    modifier isOwner() {
        require(owner == msg.sender, "Only the owner can create an election.");
        _;
    }

    modifier isValidName(string memory _name) {
        require(
            strlen(_name) >= 3 && strlen(_name) <= 50,
            "Invalid name, it should be between 3 and 50 characters."
        );
        _;
    }

    modifier isValidDescription(string memory _description) {
        require(
            strlen(_description) >= 3 && strlen(_description) <= 100,
            "Invalid description, it should be between 3 and 100 characters."
        );
        _;
    }

    modifier isValidTimeStamp(uint256 _startTime, uint256 _stopTime) {
        //require(_startTime > block.timestamp, "Invalid startTime, it should be greater than current time.");
        //require(_stopTime > _startTime, "Invalid stopTime, it should be greater than startTime.");
        _;
    }

    modifier isUniqueName(string memory _name) {
        require(
            electionNameToId[_name] == bytes32(0),
            "Election name already exists."
        );
        _;
    }

    modifier isValidElectionId(bytes32 _electionId) {
        require(
            elections[_electionId].electionId != bytes32(0),
            "Invalid election Id"
        );
        _;
    }

    modifier requireElectionOpen(bytes32 _electionId) {
        require(
            status(_electionId) != ElectionStatus.CLOSED,
            "Election is closed"
        );
        _;
    }

    modifier requireElectionActive(bytes32 _electionId) {
        require(
            status(_electionId) == ElectionStatus.ACTIVE,
            "Election is not active"
        );
        _;
    }

    modifier isAuthorized(bytes32 _electionId) {
        require(
            msg.sender == owner || elections[_electionId].admins[msg.sender],
            "You are not authorized to perform this action"
        );
        _;
    }

    // TODO-1: Check course for code formatting
    // TODO-2: Status concept for election - NOT STARTED, PAUSED, ACTIVE, CLOSED
    // TODO-3: No hard deletion for election
    // TODO-4: Pre registered elections - Optional for an election
    // TODO-5: List elections only which the user is eligible
    // TODO-6: Once the election is stopped it should not be restarted
    // TODO-7: Write Unit test cases for all the functions
    // TODO-8: Multi owner contract - multi should be optional
    // TODO-9  block.timestamp Alternative

    function createElection(
        string memory _name,
        string memory _description,
        uint256 _startTime,
        uint256 _stopTime,
        uint256 _voteFee
    )
        external
        isOwner
        isValidName(_name)
        isValidDescription(_description)
        isValidTimeStamp(_startTime, _stopTime)
        isUniqueName(_name)
    {
        bytes32 _electionId = generateId();

        electionNameToId[_name] = _electionId;
        ElectionStruct storage e = elections[_electionId];
        e.parties = new string[](0);
        e.startTime = _startTime;
        e.stopTime = _stopTime;
        e.electionId = _electionId;
        e.paused = true;
        e.voteFee = _voteFee;
        e.createdTime = block.timestamp;
        e.name = _name;
        e.description = _description;
        e.createdBy = msg.sender;
        emit LogElectionCreated(
            msg.sender,
            _electionId,
            _name,
            _description,
            e.createdTime,
            _startTime,
            _stopTime,
            _voteFee
        );
    }

    function updateElection(
        bytes32 _electionId,
        string memory _name,
        string memory _description,
        uint256 _startTime,
        uint256 _stopTime,
        uint256 _voteFee
    )
        external
        isValidName(_name)
        isValidDescription(_description)
        isValidTimeStamp(_startTime, _stopTime)
        isUniqueName(_name)
        isValidElectionId(_electionId)
    {
        require(
            msg.sender == owner || elections[_electionId].admins[msg.sender],
            "You are not authorized to perform this action"
        );
        ElectionStruct storage e = elections[_electionId];
        delete electionNameToId[e.name];
        e.name = _name;
        e.description = _description;
        e.startTime = _startTime;
        e.stopTime = _stopTime;
        e.voteFee = _voteFee;
        electionNameToId[_name] = _electionId;
        emit LogElectionUpdated(
            msg.sender,
            _electionId,
            _name,
            _description,
            block.timestamp,
            _startTime,
            _stopTime,
            _voteFee
        );
    }

    function status(bytes32 _electionId) public view returns (ElectionStatus) {
        if (block.timestamp < elections[_electionId].startTime) {
            return ElectionStatus.NOT_STARTED;
        } else if (
            block.timestamp >= elections[_electionId].startTime &&
            block.timestamp < elections[_electionId].stopTime &&
            !elections[_electionId].paused
        ) {
            return ElectionStatus.ACTIVE;
        } else if (
            block.timestamp >= elections[_electionId].startTime &&
            block.timestamp < elections[_electionId].stopTime &&
            elections[_electionId].paused
        ) {
            return ElectionStatus.PAUSED;
        } else {
            return ElectionStatus.CLOSED;
        }
    }

    function pauseElection(bytes32 _electionId)
        public
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
    {
        require(!elections[_electionId].paused, "Election is already paused.");
        elections[_electionId].paused = true;
        emit LogElectionPaused(msg.sender, _electionId, block.timestamp);
    }

    function resumeElection(bytes32 _electionId)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
    {
        require(elections[_electionId].paused, "Election is not paused.");
        elections[_electionId].paused = false;
        emit LogElectionResumed(msg.sender, _electionId, block.timestamp);
    }

    function addAdmin(bytes32 _electionId, address _admin)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
    {
        elections[_electionId].admins[_admin] = true;
        emit LogAdminCreated(msg.sender, _electionId, _admin, block.timestamp);
    }

    function removeAdmin(bytes32 _electionId, address _admin)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
    {
        elections[_electionId].admins[_admin] = false;
        emit LogAdminRemoved(msg.sender, _electionId, _admin, block.timestamp);
    }

    function addParty(bytes32 _electionId, string memory _party)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
    {
        elections[_electionId].parties.push(_party);
        emit LogPartyCreated(msg.sender, _electionId, _party, block.timestamp);
    }

    // Hard deletion of party might not be current, we just need to disable it

    function removeParty(bytes32 _electionId, string memory _party)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
    {
        int256 partyIndex = getPartyIndex(_electionId, _party);
        require(partyIndex != -1, "Party not found.");
        delete elections[_electionId].voteCounts[_party];
        for (
            int256 i = partyIndex;
            i < int256(elections[_electionId].parties.length) - 1;
            i++
        ) {
            elections[_electionId].parties[uint256(i)] = elections[_electionId]
                .parties[uint256(i) + 1];
        }
        delete elections[_electionId].parties[
            elections[_electionId].parties.length - 1
        ];
        emit LogPartyRemoved(msg.sender, _electionId, _party, block.timestamp);
    }

    function updateWinner(bytes32 _electionId)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
    {
        require(
            block.timestamp > elections[_electionId].stopTime,
            "Election is not closed yet."
        );

        string memory winnerParty;
        uint256 maxVotes = 0;
        for (uint256 i = 0; i < elections[_electionId].parties.length; i++) {
            if (
                elections[_electionId].voteCounts[
                    elections[_electionId].parties[i]
                ] > maxVotes
            ) {
                maxVotes = elections[_electionId].voteCounts[
                    elections[_electionId].parties[i]
                ];
                winnerParty = elections[_electionId].parties[i];
            }
        }

        elections[_electionId].winnerParty = winnerParty;
        emit LogWinnerUpdated(
            msg.sender,
            _electionId,
            winnerParty,
            block.timestamp
        );
    }

    function transferOwnership(address _newOwner) external {
        require(
            _newOwner == owner,
            "Cannot transfer ownership to the current owner."
        );
        require(msg.sender == owner, "Only the owner can transfer ownership.");
        require(
            _newOwner != address(0),
            "Cannot transfer ownership to address(0)"
        );
        newOwner = _newOwner;
        emit LogTransferOwnership(msg.sender, block.timestamp);
    }

    function acceptOwnership() external {
        require(
            msg.sender == newOwner,
            "Only the new owner can accept the ownership."
        );
        owner = newOwner;
        newOwner = address(0);
        emit LogAcceptOwnership(msg.sender, block.timestamp);
    }

    function vote(bytes32 _electionId, string memory _party)
        public
        payable
        isValidElectionId(_electionId)
        requireElectionActive(_electionId)
    {
        while (lock[_electionId]) {
            // wait until the election is unlocked
        }
        lock[_electionId] = true;

        require(isPartyExist(_electionId, _party), "Party does not exist.");
        require(
            msg.value >= elections[_electionId].voteFee,
            "Insufficient funds."
        );
        require(
            !elections[_electionId].voters[msg.sender],
            "You are not a registered voter."
        );
        require(
            !elections[_electionId].voted[msg.sender],
            "You have already voted."
        );

        elections[_electionId].voteCounts[_party] += 1;
        elections[_electionId].voted[msg.sender] = true;
        elections[_electionId].voteTimestamps[msg.sender] = block.timestamp;

        emit LogVote(msg.sender, _electionId, _party, block.timestamp);

        lock[_electionId] = false;
    }

    function getPartyIndex(bytes32 _electionId, string memory _party)
        private
        view
        returns (int256)
    {
        for (
            int256 i = 0;
            i < int256(elections[_electionId].parties.length);
            i++
        ) {
            if (
                keccak256(bytes(elections[_electionId].parties[uint256(i)])) ==
                keccak256(bytes(_party))
            ) {
                return i;
            }
        }
        return -1;
    }

    function isPartyExist(bytes32 _electionId, string memory _party)
        private
        view
        returns (bool)
    {
        for (uint256 i = 0; i < elections[_electionId].parties.length; i++) {
            if (
                keccak256(bytes(elections[_electionId].parties[uint256(i)])) ==
                keccak256(bytes(_party))
            ) {
                return true;
            }
        }
        return false;
    }

    function generateId() private view returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(block.timestamp, msg.sender, address(this))
        );
        return hash;
    }

    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 bytelength = bytes(s).length;

        for (len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }
}
