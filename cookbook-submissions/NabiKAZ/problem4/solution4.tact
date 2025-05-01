struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

message DeployNewProposal {
    votingEndingAt: Int as uint32;
}

contract ProposalMaster {
    // top up
    receive() {
        // TODO: implement
    }

    receive(msg: DeployNewProposal) {
        // TODO: implement
    }

    get fun nextProposalId(): Int {
        // TODO: implement
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

    init(data: ProposalInit) {
        // TODO: implement
    }

    receive(msg: Vote) {
        // TODO: implement
    }

    get fun proposalState(): ProposalState {
        // TODO: implement
    }
}
