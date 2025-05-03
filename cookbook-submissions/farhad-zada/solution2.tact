struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

message(0xc1f1f28f) DeployNewProposal {
    votingEndingAt: Int as uint32;
}

contract ProposalMaster {
    nextProposalId: Int as uint32 = 0;

    receive() {}

    receive(msg: DeployNewProposal) {
        // Check if the proposal is expired
        throwIf(257, msg.votingEndingAt <= now());
        deploy(
            DeployParameters {
                init: initOf Proposal(ProposalInit { master: myAddress(), proposalId: self.nextProposalId }),
                value: 0,
                mode: SendRemainingValue + SendIgnoreErrors,
                body: msg.toCell(),
            },
        );
        self.nextProposalId += 1;
    }

    get(0x17cb9) fun nextProposalId(): Int {
        return self.nextProposalId;
    }
}

// ==============================================================================

message(0x193b63cd) Vote {
    value: Int as int2; // 1 for yes, 0 for no
}

struct ProposalState {
    yesCount: Int as uint7;
    noCount: Int as uint7;
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}

contract Proposal {
    proposalId: Int as uint32;
    master: Address;
    votingEndingAt: Int as uint32 = 0;
    // since at most 100 votes are allowed, we can use uint7
    yesCount: Int as uint7 = 0;
    noCount: Int as uint7 = 0;
    // reminder! emptyMap() = null
    voted: map<Address, Bool> = null;

    init(data: ProposalInit) {
        self.proposalId = data.proposalId;
        self.master = data.master;
    }

    receive () {
        // this means if someone tries to deploy the contract without the DeployNewProposal message
        // it will throw an error
        throwIf(2025, true);
    }

    receive(msg: DeployNewProposal) {
        // if the self.votingEndingAt is not 0, it means the proposal is already deployed
        throwUnless(258, self.votingEndingAt == 0);
        // only the master can deploy the proposal
        throwUnless(2025, sender() == self.master);
        self.votingEndingAt = msg.votingEndingAt;
    }

    receive(msg: Vote) {
        //  throw if proposal expired
        throwIf(301, self.votingEndingAt < now());
        // throw if voters limit reached
        throwIf(302, self.yesCount + self.noCount > 99);
        // throw if already voted
        throwIf(303, self.voted.exists(sender()));
        self.yesCount += msg.value;
        self.noCount += ((-1) * (msg.value - 1));
        self.voted.set(sender(), true);
        cashback(sender());
    }

    get(0x13962) fun proposalState(): ProposalState {
        return ProposalState {
            master: self.master,
            proposalId: self.proposalId,
            votingEndingAt: self.votingEndingAt,
            yesCount: self.yesCount,
            noCount: self.noCount,
        };
    }
}
