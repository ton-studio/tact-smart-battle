struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

message DeployNewProposal {
    votingEndingAt: Int as uint32;
}

const ERROR_ENDED: Int = 2021;
const ERROR_LIMIT_REACHED: Int = 2022;
const ERROR_ALREADY_VOTED: Int = 2023;
const ERROR_INVALID_ENDING: Int = 2024;
const ERROR_NOT_MASTER: Int = 2025;

contract ProposalMaster {
    counter: Int as uint32 = 0;

    // deploy
    receive() {}

    receive(msg: DeployNewProposal) {
        let votingEndingAt = msg.votingEndingAt;
        throwIf(ERROR_INVALID_ENDING, now() > votingEndingAt);
        let init = initOf Proposal(ProposalInit {
            master: myAddress(),
            proposalId: self.counter,
        });
        deploy(DeployParameters {
            value: 0,
            mode: SendRemainingValue,
            init: init,
            body: beginCell().storeUint(votingEndingAt, 32).endCell(),
        });
        self.counter += 1;
    }

    get fun nextProposalId(): Int {
        return self.counter;
    }
}

// ==============================================================================

message Vote {
    value: Int as uint1;
}

struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}

contract Proposal {
    const MAX_VOTES_MASK: Int = 1 << 100;

    master: Address;
    id: Int as uint32;
    votingEndingAt: Int as uint32 = 0;
    voters: map<Address, Cell>;
    votes: Int as uint256 = 1;

    init(data: ProposalInit) {
        self.master = data.master;
        self.id = data.proposalId;
    }

    receive(msg: Slice) {
        throwIf(ERROR_NOT_MASTER, sender() != self.master);
        self.votingEndingAt = msg.loadUint(32);
    }

    receive(msg: Vote) {
        throwIf(ERROR_ENDED, now() > self.votingEndingAt);
        throwIf(ERROR_LIMIT_REACHED, self.votes >= self.MAX_VOTES_MASK);
        let sender = sender();
        throwIf(ERROR_ALREADY_VOTED, self.voters.exists(sender));
        self.voters.set(sender, emptyCell());
        self.votes = (self.votes << 1) + msg.value;
    }

    get fun proposalState(): ProposalState {
        let yesCount = 0;
        let noCount = 0;
        let votes = self.votes;
        while (votes > 1) {
            if ((votes & 1) == 1) {
                yesCount += 1;
            } else {
                noCount += 1;
            }
            votes >>= 1;
        }
        return ProposalState {
            yesCount: yesCount,
            noCount: noCount,
            master: self.master,
            proposalId: self.id,
            votingEndingAt: self.votingEndingAt,
        };
    }
}
