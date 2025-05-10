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

const ERROR_ENDED: Int = 2021;
const ERROR_ALREADY_VOTED: Int = 2023;
const ERROR_NOT_MASTER: Int = 2025;
const ERROR_NOT_ENOUGH_VALUE: Int = 2026;

contract Proposal {
    endTime: Int as uint32;
    yesCount: Int as uint32 = 0;
    noCount: Int as uint32 = 0;

    init(data: Init) {
        self.endTime = data.votingEndingAt;
    }

    // deploy
    receive() {}

    receive(msg: Vote) {
        throwIf(ERROR_NOT_ENOUGH_VALUE, context().value < ton("0.02")); // check if value enough for bounce
        throwIf(ERROR_ENDED, now() > self.endTime);
        let init = initOf Voter(myAddress(), sender());
        deploy(DeployParameters {
            value: 0,
            mode: SendRemainingValue,
            init: init,
            body: beginCell().storeUint(msg.value, 1).endCell(),
        });
        self.yesCount += msg.value;
        self.noCount += 1 - msg.value;
    }

    bounced(msg: Slice) {
        let value = msg.preloadUint(1);
        self.yesCount -= 1;
        self.noCount -= 1 - value;
    }

    get fun proposalState(): ProposalState {
        return ProposalState {
            yesCount: self.yesCount,
            noCount: self.noCount,
        };
    }
}

contract Voter {
    proposal: Address;
    user: Address;
    voted: Bool = false;

    init(proposal: Address, user: Address) {
        self.proposal = proposal;
        self.user = user;
    }

    receive(_: Slice) {
        throwIf(ERROR_NOT_MASTER, sender() != self.proposal);
        throwIf(ERROR_ALREADY_VOTED, self.voted);
        self.voted = true;
    }
}
