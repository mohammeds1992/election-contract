// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

contract Election {

    struct ElectionStruct {
        bytes32 electionId;
        string name;
        string description;
        uint createdTime;
        uint startTime;
        uint stopTime;
        uint voteFee;
        bool paused;
        address createdBy;
        string[] parties;
        mapping(address => bool) voters;
        mapping(address => bool) admins;
        mapping(string => uint)  voteCounts;
        mapping(address => bool) voted;
        mapping(address => uint) voteTimestamps;
        string winnerParty;
    }

    mapping(bytes32 => ElectionStruct) public elections;
    address public owner;
    address public newOwner;
    mapping(bytes32 => bool) public lock;
    mapping(string => bytes32) public electionNameToId;

    event LogElectionCreated(address indexed initiator, bytes32 indexed electionId, string name, string description, uint timestamp, uint startTime, uint stopTime, uint voteFee);
    event LogElectionUpdated(address indexed initiator, bytes32 indexed electionId, string name, string description, uint timestamp, uint startTime, uint stopTime, uint voteFee);
    event LogElectionPaused(address indexed initiator, bytes32 indexed electionId, uint timestamp);
    event LogElectionResumed(address indexed initiator, bytes32 indexed electionId, uint timestamp);
    event LogAdminCreated(address indexed initiator, bytes32 indexed electionId, address indexed admin, uint timestamp);
    event LogAdminRemoved(address indexed initiator, bytes32 indexed electionId, address indexed admin, uint timestamp);
    event LogPartyCreated(address indexed initiator, bytes32 indexed electionId, string  party, uint timestamp);
    event LogPartyRemoved(address indexed initiator, bytes32 indexed electionId, string  party, uint timestamp);
    event LogTransferOwnership(address indexed initiator, uint timestamp);
    event LogAcceptOwnership(address indexed initiator, uint timestamp);
    event LogVote(address indexed initiator, bytes32 indexed electionId, string  party, uint timestamp);
    event LogWinnerUpdated(address indexed initiator, bytes32 indexed electionId, string  party, uint timestamp);

    constructor() {
        owner = msg.sender;
    }

    function createElection(
        string memory _name, 
        string memory _description, 
        uint _startTime, 
        uint _stopTime, 
        uint _voteFee)
        public {
                require(msg.sender == owner, "Only the owner can create an election.");
                require(electionNameToId[_name] == bytes32(0), "Election name already exists.");
                require(strlen(_name) >= 3 && strlen(_name) <= 50, "Invalid name, it should be between 3 and 50 characters.");
                require(strlen(_description) >= 3 && strlen(_description) <= 100, "Invalid description, it should be between 3 and 100 characters.");
                //require(_startTime > block.timestamp, "Invalid startTime, it should be greater than current time.");
                //require(_stopTime > _startTime, "Invalid stopTime, it should be greater than startTime.");
                require(_voteFee >= 0, "Invalid vote fees, it should be greater than 0.");

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
                emit LogElectionCreated(msg.sender, _electionId, _name, _description, e.createdTime, _startTime, _stopTime, _voteFee);
            }

    function updateElection(
        bytes32 _electionId, 
        string memory _name, 
        string memory _description, 
        uint _startTime, 
        uint _stopTime,
        uint _voteFee) 
        public {
            require(isValidElectionId(_electionId), "Invalid election ID.");
            require(isAdmin(_electionId), "You are not authorized to update the election details.");
            require(strlen(_name) >= 3 && strlen(_name) <= 50, "Invalid name, it should be between 3 and 50 characters.");
            require(strlen(_description) >= 3 && strlen(_description) <= 100, "Invalid description, it should be between 3 and 100 characters.");
            //require(_startTime > block.timestamp, "Invalid startTime, it should be greater than current time.");
            //require(_stopTime > _startTime, "Invalid stopTime, it should be greater than startTime.");

            ElectionStruct storage e = elections[_electionId];
            delete electionNameToId[e.name];
            e.name = _name;
            e.description = _description;
            e.startTime = _startTime;
            e.stopTime = _stopTime;
            e.voteFee = _voteFee;
            electionNameToId[_name] = _electionId;
            emit LogElectionUpdated(msg.sender, _electionId, _name, _description, block.timestamp, _startTime, _stopTime, _voteFee);
    }

    function pauseElection
        (bytes32 _electionId) 
        public {
            require(isAdmin(_electionId), "You are not authorized to pause the election.");
            require(isValidElectionId(_electionId), "Invalid election Id");
            require(!elections[_electionId].paused, "Election is already paused.");
            elections[_electionId].paused = true;
            emit LogElectionPaused(msg.sender, _electionId, block.timestamp);
    }

    function 
        resumeElection
        (bytes32 _electionId) 
        public {
            require(isAdmin(_electionId), "You are not authorized to resume the election.");
            require(isValidElectionId(_electionId), "Invalid election Id");
            require(elections[_electionId].paused, "Election is not paused.");
            elections[_electionId].paused = false;
            emit LogElectionResumed(msg.sender, _electionId, block.timestamp);
    }

    function addAdmin(bytes32 _electionId, address _admin) public {
        require(isAdmin(_electionId), "Only the owner or admins can add new admins.");
        require(isValidElectionId(_electionId), "Invalid election Id");
        elections[_electionId].admins[_admin] = true;
        emit LogAdminCreated(msg.sender, _electionId, _admin, block.timestamp);
    }

    function removeAdmin(bytes32 _electionId, address _admin) public {
        require(isAdmin(_electionId), "Only the owner or admins can remove admins.");
        require(isValidElectionId(_electionId), "Invalid election Id");
        elections[_electionId].admins[_admin] = false;
        emit LogAdminRemoved(msg.sender, _electionId, _admin, block.timestamp);
    }

    function addParty(bytes32 _electionId, string memory _party) public {
        require(isAdmin(_electionId), "Only the owner or party admins can add parties.");
        elections[_electionId].parties.push(_party);
        emit LogPartyCreated(msg.sender, _electionId, _party, block.timestamp);
    }


    // Hard deletion of party might not be current, we just need to disable it

    function removeParty(bytes32 _electionId, string memory _party) public {
        require(isAdmin(_electionId), "Only the owner or party admins can remove parties.");
        int partyIndex = getPartyIndex(_electionId, _party);
        require(partyIndex != -1, "Party not found.");
        delete elections[_electionId].voteCounts[_party];
        for (int i = partyIndex; i < int(elections[_electionId].parties.length) - 1; i++) {
            elections[_electionId].parties[uint(i)] = elections[_electionId].parties[uint(i) + 1];
        }
        delete elections[_electionId].parties[elections[_electionId].parties.length - 1];
        emit LogPartyRemoved(msg.sender, _electionId, _party, block.timestamp);
    }

    function getPartyIndex(bytes32 _electionId, string memory _party) private view returns (int) {
        for (int i = 0; i < int(elections[_electionId].parties.length); i++) {
            if (keccak256(bytes(elections[_electionId].parties[uint(i)])) == keccak256(bytes(_party))) {
                return i;
            }
        }
        return -1;
    }

    function isPartyExist(bytes32 _electionId, string memory _party) private view returns (bool) {
        for (uint i = 0; i < elections[_electionId].parties.length; i++) {
            if (keccak256(bytes(elections[_electionId].parties[uint(i)])) == keccak256(bytes(_party))) {
                return true;
            }
        }
        return false;
    }

    function updateWinner(bytes32 _electionId) public {
        require(isAdmin(_electionId), "You are not authorized to update the winner.");
        require(isValidElectionId(_electionId), "Invalid election Id");
        require(block.timestamp > elections[_electionId].stopTime, "Election is not closed yet.");

        string memory winnerParty;
        uint maxVotes = 0;
        for (uint i = 0; i < elections[_electionId].parties.length; i++) {
            if (elections[_electionId].voteCounts[elections[_electionId].parties[i]] > maxVotes) {
                maxVotes = elections[_electionId].voteCounts[elections[_electionId].parties[i]];
                winnerParty = elections[_electionId].parties[i];
            }
        }

        elections[_electionId].winnerParty = winnerParty;
        emit LogWinnerUpdated(msg.sender, _electionId, winnerParty, block.timestamp);
    }

    function transferOwnership(address _newOwner) public {
        require(_newOwner == owner, "Cannot transfer ownership to the current owner.");
        require(msg.sender == owner, "Only the owner can transfer ownership.");
        require(_newOwner != address(0), "Cannot transfer ownership to address(0)");
        newOwner = _newOwner;
        emit LogTransferOwnership(msg.sender, block.timestamp);
    }

    function acceptOwnership() public {
        require(msg.sender == newOwner, "Only the new owner can accept the ownership.");
        owner = newOwner;
        newOwner = address(0);
        emit LogAcceptOwnership(msg.sender, block.timestamp);
    }

   function vote(bytes32 _electionId, string memory _party) public payable {
        while(lock[_electionId]) {
            // wait until the election is unlocked
        }
        lock[_electionId] = true;

        require(isValidElectionId(_electionId), "Invalid election Id");
        require(isPartyExist(_electionId, _party), "Party does not exist.");
        require(msg.value >= elections[_electionId].voteFee, "Insufficient funds.");
        require(!elections[_electionId].voters[msg.sender], "You are not a registered voter.");
        require(!elections[_electionId].voted[msg.sender], "You have already voted.");
        require(block.timestamp >= elections[_electionId].startTime && block.timestamp <= elections[_electionId].stopTime, "Election is closed.");
        require(!elections[_electionId].paused, "Election is paused.");

        elections[_electionId].voteCounts[_party] += 1;
        elections[_electionId].voted[msg.sender] = true;
        elections[_electionId].voteTimestamps[msg.sender] = block.timestamp;

        emit LogVote(msg.sender, _electionId, _party, block.timestamp);

        lock[_electionId] = false;
    }

    function isValidElectionId(bytes32 _electionId) public view returns (bool) {
        return elections[_electionId].electionId != bytes32(0);
    }

    function isAdmin(bytes32 _electionId) private view returns (bool) {
        return msg.sender == owner || elections[_electionId].admins[msg.sender];
    }

    function generateId() private view returns (bytes32) {
        bytes32 hash = keccak256(abi.encodePacked(block.timestamp, msg.sender, address(this)));
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