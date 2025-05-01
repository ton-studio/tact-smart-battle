//
// Reference solution of Problem #1
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

    voters: map<Address, Bool>;
    yesCount: Int as uint7 = 0;
    totalCount: Int as uint7 = 0;

    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
    }

    // deploy
    receive() { }

    receive(msg: Vote) {
        // There cannot be more than 100 voters
        throwUnless(700, self.totalCount < 100);
        // Voting is already finished!
        throwUnless(701, now() < self.votingEndingAt);
        let sender = sender();
        // User already voted
        throwUnless(702, !self.voters.exists(sender));

        self.voters.set(sender, true);
        if (msg.value) { self.yesCount += 1 }
    self.totalCount += 1;

    cashback(sender());
    }

    get fun proposalState(): ProposalState {
        return ProposalState {
            yesCount: self.yesCount,
            noCount: self.totalCount - self.yesCount,
        }
    }
}
