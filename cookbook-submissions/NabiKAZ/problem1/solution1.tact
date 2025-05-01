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
    yesVotes: Int as uint32 = 0;
    noVotes: Int as uint32 = 0;
    voters: map<Address, Bool>;

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
        throwUnless(700, self.yesVotes + self.noVotes < 100);

        // Check if the sender has already voted
        let sender = sender();
        throwUnless(700, self.voters.get(sender) == null);

        // Record that this address has voted
        self.voters.set(sender, true);

        // Count the vote based on its value
        if (msg.value) {
            self.yesVotes += 1;
        } else {
            self.noVotes += 1;
        }

        // Return excess funds
        send(SendParameters {
            to: sender(),
            value: 0,
            mode: SendRemainingValue | SendIgnoreErrors,
        });
    }

    // Getter for current proposal state
    get fun proposalState(): ProposalState {
        return ProposalState {
            yesCount: self.yesVotes,
            noCount: self.noVotes,
        };
    }
}
