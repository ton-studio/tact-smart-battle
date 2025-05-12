struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

message DeployNewProposal {
    votingEndingAt: Int as uint32;
}

contract ProposalMaster {
    // State variable to track the next proposal ID
    nextId: Int as uint32 = 0;

    // Empty receiver for initial deployment
    receive() {}

    // Deploy a new proposal when message is received
    receive(msg: DeployNewProposal) {
        // Verify the voting end time is in the future
        throwUnless(700, msg.votingEndingAt > now());

        // Calculate the address of the new proposal contract
        let init: StateInit = initOf Proposal(
            ProposalInit {
                master: myAddress(),
                proposalId: self.nextId,
            },
        );

        // Deploy the proposal contract
        send(SendParameters {
            to: contractAddress(init),
            value: 0, // Send remaining balance
            mode: SendRemainingValue | SendIgnoreErrors,
            body: DeployNewProposal {
                votingEndingAt: msg.votingEndingAt,
            }.toCell(),
            code: init.code,
            data: init.data,
        });

        // Increment the proposal ID for the next proposal
        self.nextId = self.nextId + 1;
    }

    // Getter function to retrieve the next proposal ID
    get fun nextProposalId(): Int {
        return self.nextId;
    }
}

// ==============================================================================

message Vote {
    value: Bool;
}

struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}

contract Proposal {
    // Proposal state variables
    yesCount: Int as uint32 = 0;
    noCount: Int as uint32 = 0;
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32 = 0;

    // Map to track who has voted
    voters: map<Address, Bool>;

    // Empty receiver for initial deployment
    receive() {}

    init(data: ProposalInit) {
        // This check ensures that only the master contract can deploy proposals
        // It's executed during contract initialization
        throwUnless(2025, sender() == data.master);
        
        self.master = data.master;
        self.proposalId = data.proposalId;
    }

    // Handle deployment message from master
    receive(msg: DeployNewProposal) {
        // Verify that the sender is the master contract
        throwUnless(2025, sender() == self.master);

        // Set the voting ending time
        self.votingEndingAt = msg.votingEndingAt;
    }

    receive(msg: Vote) {
        // Check if voting is still open
        throwUnless(700, now() < self.votingEndingAt);

        // Check if max votes limit reached
        throwUnless(700, self.yesCount + self.noCount < 100);

        // Check if the voter has already voted
        let sender = sender();
        throwUnless(700, self.voters.get(sender) == null);

        // Record the vote
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }

        // Mark this voter as having voted
        self.voters.set(sender, true);
    }

    get fun proposalState(): ProposalState {
        return ProposalState {
            yesCount: self.yesCount,
            noCount: self.noCount,
            master: self.master,
            proposalId: self.proposalId,
            votingEndingAt: self.votingEndingAt,
        };
    }
}