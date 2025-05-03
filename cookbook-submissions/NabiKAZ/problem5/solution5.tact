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
    init(data: Init) {
    }

    // deploy
    receive() { }

    receive(msg: Vote) {
        // TODO: implement
    }

    get fun proposalState(): ProposalState {
        // TODO: implement
    }
}
