//
// Public solution template
//

message Vote {
    value: Int as uint1;
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
    votingEndingAt: Int as uint32;
    // possible replace with an array
    votes: Int as uint256 = 0;

    size: Int as uint7 = 0;
    yesCount: Int as uint7 = 0;

    init(data: Init) {
        self.votingEndingAt = data.votingEndingAt;
    }

    // deploy
    receive() { }

    receive(msg: Vote) {
        throwUnless(60, now() <= self.votingEndingAt);

        let sender = sender();


        throwUnless(61, self.size < 100);

        let addressShifted = sender.asSlice().loadUint(90) & 0xFF;
        let flag = (1 << addressShifted);

        throwUnless(61, (self.votes & flag) == 0);

        self.votes |= flag;
        self.size += 1;
        self.yesCount += msg.value;

        if (context().value > 40_000_000_000) {
            cashback(sender);
        }
    }

    get fun proposalState(): ProposalState {
        
        return ProposalState {
            yesCount: self.yesCount,
            noCount: self.size - self.yesCount,
        };
    }
}
