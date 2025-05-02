//
// Public solution template
//

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
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;

    count: Int as uint32;
    votes: map<Address, Bool>;

    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
        self.votes = emptyMap();
        self.count = 0;
    }

    // deploy
    receive() { }

    receive(msg: Vote) {
        let sender = sender();

        // check that sender did not vote yet
        require(
            !self.votes.exists(sender),
            "Sender has already voted"
        );

        // check that less than 100 votes
        require(
            self.count < 100,
            "Voting is not allowed after 100 votes"
        );

        // check that time is less then votingEndingAt
        require(
            now() <= self.votingEndingAt,
            "Voting is not allowed after the voting period has ended"
        );

        self.votes.set(sender, msg.value);
        self.count += 1;

        cashback(sender);
    }

    get fun proposalState(): ProposalState {
        let yes: Int = 0;

        foreach (adderess, vote in self.votes) {
            if (vote) {
                yes += 1;
            }
        }

        return ProposalState {
            yesCount: yes,
            noCount: self.count - yes
        }
    }
}
