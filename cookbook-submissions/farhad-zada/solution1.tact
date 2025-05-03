message(0x193b63cd) Vote {
    value: Int as int2; // 1 for yes, 0 for no
}

struct ProposalState {
    yesCount: Int as uint7;
    noCount: Int as uint7;
}

struct Init {
    proposalId: Int as uint32;
    votingEndingAt: Int as int32;
}
contract Proposal {
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    // since at most 100 votes are allowed, we can use uint7
    yesCount: Int as uint7 = 0;
    noCount: Int as uint7 = 0;
    voted: map<Address, Bool> = null;

    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
    }

    receive() {
        cashback(sender());
    }

    receive(msg: Vote) {
        let sender = sender();
        // proposal expired
        throwIf(257, now() > self.votingEndingAt);
        // voters limit reached
        throwIf(258, self.yesCount + self.noCount == 100);
        // already voted
        throwIf(259, self.voted.exists(sender));

        self.yesCount += msg.value;
        self.noCount += ((-1) * (msg.value - 1));
        self.voted.set(sender, true);
        // reimburse the remaining value
        cashback(sender());
    }

    get(0x13962) fun proposalState(): ProposalState {
        return ProposalState { yesCount: self.yesCount, noCount: self.noCount };
    }
}
