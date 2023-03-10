// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

contract ElectionContract {
    enum ElectionStatus {
        NOT_STARTED,
        ACTIVE,
        PAUSED,
        CLOSED,
        CANCELLED
    }

    enum PartyStatus {
        ACTIVE,
        INACTIVE
    }

    struct Winner {
        string party;
        uint256 votes;
    }

    struct Election {
        bytes32 electionId;
        string name;
        string description;
        uint256 createdTime;
        uint256 startTime;
        uint256 stopTime;
        uint256 voteFee;
        bool paused;
        address createdBy;
        bool noVoting;
        bool isCancelled;
    }

    struct Party {
        string name;
        uint256 createdTime;
        uint256 voteCount;
        PartyStatus status;
    }

    struct Admin {
        address addr;
        string name;
        uint256 createdTime;
    }

    struct Voter {
        address addr;
        bool voted;
        uint256 voteTimestamp;
    }

    mapping(bytes32 => Election) public elections;
    mapping(bytes32 => Party[]) public partyNames;

    mapping(bytes32 => mapping(string => bool)) public parties;
    // Change name to election admins
    mapping(bytes32 => mapping(address => bool)) public admins;
    // Change name to party vote counts
    mapping(bytes32 => mapping(address => Voter)) public voters;
    mapping(bytes32 => Winner[]) public winners;

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
    event LogElectionDeleted(
        address indexed initiator,
        bytes32 indexed electionId,
        uint256 timestamp
    );
    event LogElectionPaused(
        address indexed initiator,
        bytes32 indexed electionId,
        uint256 timestamp
    );
    event LogElectionCancelled(
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
    event LogElectionWinnerDeclared(
        address indexed initiator,
        bytes32 indexed electionId,
        Winner winner,
        uint256 timestamp
    );
    event LogElectionTied(
        address indexed initiator,
        bytes32 indexed electionId,
        Winner[] coWinners,
        uint256 timestamp
    );
    event LogNoVotingCasted(
        address indexed initiator,
        bytes32 indexed electionId,
        uint256 timestamp
    );

    constructor() {
        owner = msg.sender;
    }

    modifier isOwner() {
        require(
            owner == msg.sender,
            "You are not authorized to perform this action."
        );
        _;
    }

    modifier isUniqueName(string memory _name) {
        require(
            electionNameToId[_name] == bytes32(uint256(0)),
            "Election name already exists."
        );
        _;
    }

    modifier isValidElectionId(bytes32 _electionId) {
        require(
            elections[_electionId].electionId != bytes32(uint256(0)),
            "Invalid election Id"
        );
        _;
    }

    modifier requireElectionOpen(bytes32 _electionId) {
        require(
            status(_electionId) != ElectionStatus.CLOSED &&
                status(_electionId) != ElectionStatus.CANCELLED,
            "Election is closed or cancelled"
        );
        _;
    }

    modifier requireElectionClosed(bytes32 _electionId) {
        require(
            status(_electionId) == ElectionStatus.CLOSED,
            "Election is still active"
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
            msg.sender == owner || admins[_electionId][msg.sender],
            "You are not authorized to perform this action."
        );
        _;
    }

    // TODO-1: Pre registered elections - Optional for an election
    // TODO-2: List elections only which the user is eligible
    // TODO-3: Write Unit test cases for all the functions
    // TODO-4: Multi owner contract - multi should be optional
    // TODO-5: block.timestamp Alternative
    // TODO-6: Break ElectionStruct to mulitiple structs to avoid reading performance issues
    // TODO-7: Avoid multiple election reads in the vote method
    // TODO-8: Use Truffle for the test cases
    // TODO-9: Unique PartyName

    modifier validateElectionRequest(
        ElectionRequest memory request,
        bytes32 _electionId
    ) {
        require(
            strlen(request.name) >= 3 && strlen(request.name) <= 50,
            "Invalid name, it should be between 3 and 50 characters."
        );
        require(
            strlen(request.description) >= 3 &&
                strlen(request.description) <= 100,
            "Invalid description, it should be between 3 and 100 characters."
        );
        require(
            (electionNameToId[request.name] == bytes32(uint256(0)) ||
                electionNameToId[request.name] == _electionId),
            "Election name already exists."
        );
        require(
            request.startTime > block.timestamp,
            "Invalid startTime, it should be greater than current time."
        );
        require(
            request.stopTime > request.startTime,
            "Invalid stopTime, it should be greater than startTime."
        );
        _;
    }

    struct ElectionRequest {
        string name;
        string description;
        uint256 startTime;
        uint256 stopTime;
        uint256 voteFee;
    }

    function createElection(ElectionRequest memory request)
        external
        isOwner
        validateElectionRequest(request, bytes32(uint256(0)))
    {
        bytes32 _electionId = generateId();

        electionNameToId[request.name] = _electionId;

        Election storage e = elections[_electionId];
        e.startTime = request.startTime;
        e.stopTime = request.stopTime;
        e.electionId = _electionId;
        e.paused = true;
        e.voteFee = request.voteFee;
        e.createdTime = block.timestamp;
        e.name = request.name;
        e.description = request.description;
        e.createdBy = msg.sender;
        e.noVoting = false;
        e.isCancelled = false;

        emit LogElectionCreated(
            msg.sender,
            _electionId,
            request.name,
            request.description,
            e.createdTime,
            request.startTime,
            request.stopTime,
            request.voteFee
        );
    }

    function updateElection(bytes32 _electionId, ElectionRequest memory request)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
        requireElectionOpen(_electionId)
        validateElectionRequest(request, _electionId)
    {
        require(
            msg.sender == owner || admins[_electionId][msg.sender],
            "You are not authorized to perform this action"
        );
        Election storage e = elections[_electionId];

        if (keccak256(bytes(e.name)) != keccak256(bytes(request.name))) {
            delete electionNameToId[e.name];
            electionNameToId[request.name] = _electionId;
        }
        e.name = request.name;
        e.description = request.description;
        e.startTime = request.startTime;
        e.stopTime = request.stopTime;
        e.voteFee = request.voteFee;
        electionNameToId[request.name] = _electionId;
        emit LogElectionUpdated(
            msg.sender,
            _electionId,
            request.name,
            request.description,
            block.timestamp,
            request.startTime,
            request.stopTime,
            request.voteFee
        );
    }

    function status(bytes32 _electionId) public view returns (ElectionStatus) {
        uint256 currentTime = block.timestamp;
        if (elections[_electionId].isCancelled) {
            return ElectionStatus.CANCELLED;
        } else if (currentTime < elections[_electionId].startTime) {
            return ElectionStatus.NOT_STARTED;
        } else if (
            currentTime >= elections[_electionId].startTime &&
            currentTime < elections[_electionId].stopTime &&
            !elections[_electionId].paused
        ) {
            return ElectionStatus.ACTIVE;
        } else if (
            currentTime >= elections[_electionId].startTime &&
            currentTime < elections[_electionId].stopTime &&
            elections[_electionId].paused
        ) {
            return ElectionStatus.PAUSED;
        } else {
            return ElectionStatus.CLOSED;
        }
    }

    function deleteElection(bytes32 _electionId)
        external
        isOwner
        isValidElectionId(_electionId)
    {
        Election storage e = elections[_electionId];
        delete electionNameToId[e.name];
        delete elections[_electionId];
        delete partyNames[_electionId];
        //delete admins[_electionId];
        //delete voteCounts[_electionId];
        //delete voters[_electionId];
        delete winners[_electionId];

        emit LogElectionDeleted(msg.sender, _electionId, block.timestamp);
    }

    function cancelElection(bytes32 _electionId)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
        requireElectionOpen(_electionId)
    {
        elections[_electionId].isCancelled = true;
        emit LogElectionCancelled(msg.sender, _electionId, block.timestamp);
    }

    function pauseElection(bytes32 _electionId)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
        requireElectionOpen(_electionId)
    {
        require(!elections[_electionId].paused, "Election is already paused.");
        elections[_electionId].paused = true;
        emit LogElectionPaused(msg.sender, _electionId, block.timestamp);
    }

    function resumeElection(bytes32 _electionId)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
        requireElectionOpen(_electionId)
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
        admins[_electionId][_admin] = true;
        emit LogAdminCreated(msg.sender, _electionId, _admin, block.timestamp);
    }

    function removeAdmin(bytes32 _electionId, address _admin)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
    {
        admins[_electionId][_admin] = false;
        emit LogAdminRemoved(msg.sender, _electionId, _admin, block.timestamp);
    }

    function addParty(bytes32 _electionId, string memory _party)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
        requireElectionOpen(_electionId)
    {
        require(
            strlen(_party) >= 3 && strlen(_party) <= 50,
            "Invalid party name, it should be between 3 and 50 characters."
        );

        partyNames[_electionId].push(
            Party(_party, block.timestamp, uint256(0), PartyStatus.ACTIVE)
        );

        parties[_electionId][_party] = true;
        emit LogPartyCreated(msg.sender, _electionId, _party, block.timestamp);
    }

    function removeParty(bytes32 _electionId, string memory _party)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
        requireElectionOpen(_electionId)
    {
        parties[_electionId][_party] = false;

        for (uint256 i = 0; i < partyNames[_electionId].length; i++) {
            if (
                keccak256(bytes(partyNames[_electionId][i].name)) !=
                keccak256(bytes(_party))
            ) {
                partyNames[_electionId][i].status = PartyStatus.INACTIVE;
            }
        }

        emit LogPartyRemoved(msg.sender, _electionId, _party, block.timestamp);
    }

    function updateWinner(bytes32 _electionId)
        external
        isValidElectionId(_electionId)
        isAuthorized(_electionId)
        requireElectionClosed(_electionId)
        returns (Winner[] memory)
    {
        require(
            block.timestamp > elections[_electionId].stopTime,
            "Election is not closed yet."
        );

        require(
            partyNames[_electionId].length > 0,
            "No parties are registered in this election."
        );

        if (winners[_electionId].length > 0)
            revert("Winner already declared for this election.");

        uint256 currentTime = block.timestamp;

        uint256 maxVotes = 0;
        for (uint256 i = 0; i < partyNames[_electionId].length; i++) {
            if (partyNames[_electionId][i].voteCount > maxVotes) {
                maxVotes = partyNames[_electionId][i].voteCount;
            }
        }

        if (maxVotes == 0) {
            elections[_electionId].noVoting = true;
            emit LogNoVotingCasted(msg.sender, _electionId, currentTime);
            revert("No votes have been cast in this election, Hence no winner");
        }

        elections[_electionId].noVoting = false;

        for (uint256 i = 0; i < partyNames[_electionId].length; i++) {
            if (partyNames[_electionId][i].voteCount == maxVotes) {
                maxVotes = partyNames[_electionId][i].voteCount;
                winners[_electionId].push(
                    Winner(partyNames[_electionId][i].name, maxVotes)
                );
            }
        }

        if (winners[_electionId].length == 1) {
            emit LogElectionWinnerDeclared(
                msg.sender,
                _electionId,
                winners[_electionId][0],
                currentTime
            );
        } else {
            emit LogElectionTied(
                msg.sender,
                _electionId,
                winners[_electionId],
                currentTime
            );
        }
        return winners[_electionId];
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
        external
        payable
        isValidElectionId(_electionId)
        requireElectionActive(_electionId)
    {
        while (lock[_electionId]) {
            // wait until the election is unlocked
        }
        lock[_electionId] = true;

        require(
            strlen(_party) >= 3 && strlen(_party) <= 50,
            "Invalid party name, it should be between 3 and 50 characters."
        );

        require(isPartyExist(_electionId, _party), "Party does not exist.");
        require(
            msg.value >= elections[_electionId].voteFee,
            "Insufficient funds."
        );

        // TODO: Need to fix this
        /*require(
            !voters[_electionId][msg.sender],
            "You are not a registered voter."
        );*/

        require(
            !voters[_electionId][msg.sender].voted,
            "You have already voted."
        );

        for (uint256 i = 0; i < partyNames[_electionId].length; i++) {
            if (
                keccak256(bytes(partyNames[_electionId][i].name)) !=
                keccak256(bytes(_party))
            ) {
                partyNames[_electionId][i].voteCount += 1;
            }
        }

        voters[_electionId][msg.sender].voted = true;
        voters[_electionId][msg.sender].voteTimestamp = block.timestamp;

        emit LogVote(msg.sender, _electionId, _party, block.timestamp);

        lock[_electionId] = false;
    }

    function isPartyExist(bytes32 _electionId, string memory _party)
        private
        view
        returns (bool)
    {
        return parties[_electionId][_party];
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
