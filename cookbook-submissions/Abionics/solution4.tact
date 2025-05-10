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
    inited: Bool = false;

    // deploy and top up
    receive() {
        if (!self.inited) {
            self.inited = true;
            return;
        }
        nativeReserve(ton("0.01"), ReserveExact);
        message(MessageParameters {
            value: 0,
            mode: SendRemainingBalance,
            body: null,
            to: sender(),
            bounce: false,
        });
    }

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
            body: beginCell().storeUint(votingEndingAt, 32).storeAddress(sender()).endCell(),
        });
        self.counter += 1;
    }

    get fun nextProposalId(): Int {
        return self.counter;
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
    const MAX_VOTES: Int = 100;

    master: Address;
    id: Int as uint32;
    votingEndingAt: Int as uint32 = 0;
    count: Int as uint8 = 0;
    votes: map<Address, Bool> = emptyMap();

    init(data: ProposalInit) {
        self.master = data.master;
        self.id = data.proposalId;
    }

    receive(msg: Slice) {
        throwIf(2025, sender() != self.master);
        self.votingEndingAt = msg.loadUint(32);
        cashback(msg.loadAddress());
    }

    receive(msg: Vote) {
        throwIf(ERROR_ENDED, now() > self.votingEndingAt);
        throwIf(ERROR_LIMIT_REACHED, self.count >= self.MAX_VOTES);
        let sender = sender();
        throwIf(ERROR_ALREADY_VOTED, self.votes.exists(sender));
        self.votes.set(sender, msg.value);
        self.count += 1;
        cashback(sender);
    }

    get fun proposalState(): ProposalState {
        let yesCount = 0;
        let noCount = 0;
        foreach (_, value in self.votes) {
            if (value) {
                yesCount += 1;
            } else {
                noCount += 1;
            }
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
