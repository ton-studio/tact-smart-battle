struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

message DeployNewProposal {
    votingEndingAt: Int as uint32;
}

message StartVoting {
    votingEndingAt: Int as uint32;
}

contract ProposalMaster {
    nextProposalId: Int as uint32 = 0;

    // deploy
    receive() {
    }

    receive(msg: DeployNewProposal) {
        require(msg.votingEndingAt >= now(), "Voting must end in the future");

        let proposalInit = initOf Proposal(ProposalInit {
        master: myAddress(),
        proposalId: self.nextProposalId,
        });

        deploy(DeployParameters {
        init: proposalInit,
        mode: SendRemainingValue,
        value: 0,
        body: (StartVoting {
        votingEndingAt: msg.votingEndingAt,
        }).toCell(),
        });

        self.nextProposalId += 1;
    }

    get fun nextProposalId(): Int { return self.nextProposalId }
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
    const INVALID_TIME: Int = 0;

    master: Address;
    proposalId: Int as uint32;

    votingEndingAt: Int as uint32;

    voters: map<Address, Bool> = emptyMap();
    yesCount: Int as uint7 = 0;
    totalCount: Int as uint7 = 0;

    init(data: ProposalInit) {
        throwUnless(2025, data.master == sender());
        self.proposalId = data.proposalId;
        self.master = data.master;
        self.votingEndingAt = self.INVALID_TIME;
    }

    receive(msg: StartVoting) {
        // init() is implicitly called here, so we know it is called by master
        // StartVoting can be called only once: it is guaranteed by the master contract
        require(self.votingEndingAt == self.INVALID_TIME, "Voting is already started");
        self.votingEndingAt = msg.votingEndingAt;
    }

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
    }

    get fun proposalState(): ProposalState {
        return ProposalState {
            yesCount: self.yesCount,
            noCount: self.totalCount - self.yesCount,
            master: self.master,
            proposalId: self.proposalId,
            votingEndingAt: self.votingEndingAt,
        }
    }
}
