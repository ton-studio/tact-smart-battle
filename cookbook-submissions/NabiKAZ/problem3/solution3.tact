message Vote {
    value: Bool;
}

struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
}

struct Init {
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}

contract Proposal {
    // Contract state variables
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    yesCount: Int as uint32 = 0;
    noCount: Int as uint32 = 0;

    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
    }

    // For contract deployment
    receive() {}

    // For receiving votes
    receive(msg: Vote) {
        // Check if voting is still open (time-based)
        throwUnless(700, now() < self.votingEndingAt);

        // Check if the vote limit has been reached
        throwUnless(700, self.yesCount + self.noCount < 100);

        // Count the vote based on its value
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }

        // Deploy VoteStorage contract to keep track of votes
        deploy(DeployParameters {
            value: 0,
            mode: SendRemainingValue,
            body: msg.toCell(),
            bounce: true,
            init: initOf VoteStorage(
                sender(),
                myAddress(),
            ),
        });
    }

    // Handle bounce messages when vote storage deployment fails
    bounced(msg: Vote) {
        // Decrease vote count on deploy failure
        if (msg.value) {
            self.yesCount -= 1;
        } else {
            self.noCount -= 1;
        }
    }

    // Getter for current proposal state
    get fun proposalState(): ProposalState {
        return ProposalState {
            yesCount: self.yesCount,
            noCount: self.noCount,
        };
    }
}

// Storage contract for tracking votes
contract VoteStorage {
    // Address of the voter
    ownerAddress: Address;
    // Address of the proposal contract
    proposalAddress: Address;
    // Flag to prevent multiple votes
    alreadyVoted: Bool;

    // Initialize with voter and proposal addresses
    init(ownerAddress: Address, proposalAddress: Address) {
        // Only proposal can deploy this
        require(sender() == proposalAddress, "Only proposal contract can call this");
        // Set initial values
        self.ownerAddress = ownerAddress;
        self.proposalAddress = proposalAddress;
        self.alreadyVoted = false;
    }

    // Handle incoming vote message
    receive(msg: Vote) {
        // Check if already voted
        require(!self.alreadyVoted, "Already voted");
        // Verify sender is proposal contract
        require(sender() == self.proposalAddress, "Only proposal contract can call this");
        // Mark as voted
        self.alreadyVoted = true;
    }

    // Default receive handler
    receive() {}
}
