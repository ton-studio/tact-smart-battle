struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

message(0xc1f1f28f) DeployNewProposal {
    votingEndingAt: Int as uint32;
}

contract ProposalMaster {
    nextProposalId: Int as uint32 = 0;

    receive() {
        // reserves 0.01 TON for the proposal contract
        nativeReserve(ton("0.01"), ReserveAtMost);
        cashback(sender());
    }

    receive(msg: DeployNewProposal) {
        throwIf(300, msg.votingEndingAt <= now());
        deploy(
            DeployParameters {
                init: initOf Proposal(ProposalInit { master: myAddress(), proposalId: self.nextProposalId }),
                value: 0,
                mode: 66, // SendRemainingValue + SendIgnoreErrors
                body: DeployNewProposalInternal { votingEndingAt: msg.votingEndingAt, sendExcessesTo: sender() }.toCell(),
            },
        );
        self.nextProposalId += 1;
    }

    get fun nextProposalId(): Int {
        return self.nextProposalId;
    }
}

// ==============================================================================

message(0x193b63cd) Vote {
    value: Int as int2; // 1 for yes, 0 for no
}

struct ProposalState {
    // there would be at most 100 votes which can be casted
    // so we can use uint7
    // to save space
    yesCount: Int as uint7;
    noCount: Int as uint7;
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}

message(0x67861204) DeployNewProposalInternal {
    votingEndingAt: Int as uint32;
    sendExcessesTo: Address;
}

contract Proposal {
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    yesCount: Int as uint7;
    noCount: Int as uint7;
    voted: map<Address, Bool> = null;

    init(data: ProposalInit) {
        self.master = data.master;
        self.proposalId = data.proposalId;
        self.votingEndingAt = 0;
        self.yesCount = 0;
        self.noCount = 0;
    }

    receive () {
        throw(2025); // on a redebloy throws 2025 
    }

    receive(msg: DeployNewProposalInternal) {
        throwUnless(2025, sender() == self.master);
        self.votingEndingAt = msg.votingEndingAt;
        cashback(msg.sendExcessesTo);
    }

    receive(msg: Vote) {
        throwIf(301, self.votingEndingAt < now());
        throwIf(302, self.yesCount + self.noCount == 100); // 100 votes are allowed
        throwIf(303, self.voted.exists(sender()));
        self.yesCount += msg.value;
        self.noCount += ((-1) * (msg.value - 1));
        self.voted.set(sender(), true);
        cashback(sender());
    }

    get fun proposalState(): ProposalState {
        return ProposalState {
            master: self.master,
            yesCount: self.yesCount,
            noCount: self.noCount,
            proposalId: self.proposalId,
            votingEndingAt: self.votingEndingAt,
        };
    }
}
