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

message Voted {
    user: Address;
    value: Int as uint1;
}

const ERROR_ENDED: Int = 2021;
const ERROR_ALREADY_VOTED: Int = 2023;
const ERROR_NOT_MASTER: Int = 2025;
const ERROR_NOT_ENOUGH_VALUE: Int = 2026;
const ERROR_NOT_VOTER: Int = 2027;

const FWD_CELLS: Int = (3 + 1 + 1) + 2; // deploy + voted
const FWD_BITS: Int = (1656 + 535 + 1) + 1; // deploy + voted
const GAS_USED: Int = 10_000; // estimated amount
const IS_MASTERCHAIN: Bool = false;

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
        let minValue = getForwardFee(FWD_CELLS, FWD_BITS, IS_MASTERCHAIN) + getComputeFee(GAS_USED, IS_MASTERCHAIN);
        throwIf(ERROR_NOT_ENOUGH_VALUE, minValue > context().value); // check if value enough for second msg
        throwIf(ERROR_ENDED, now() > self.endTime);
        deploy(DeployParameters {
            value: 0,
            mode: SendRemainingValue,
            init: self.voterStateInit(sender()),
            body: beginCell().storeBool(msg.value).endCell(),
        });
    }

    receive(msg: Voted) {
        let expected = contractAddress(self.voterStateInit(msg.user));
        throwIf(ERROR_NOT_VOTER, expected != sender());
        self.yesCount += msg.value;
        self.noCount += 1 - msg.value;
        cashback(msg.user);
    }

    fun voterStateInit(user: Address): StateInit {
        return initOf Voter(myAddress(), user);
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

    receive(msg: Slice) {
        throwIf(ERROR_NOT_MASTER, sender() != self.proposal);
        if (self.voted) {
            cashback(self.user);
            commit();
            throw(ERROR_ALREADY_VOTED);
        }
        self.voted = true;
        send(SendParameters {
            to: self.proposal,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: Voted {
                user: self.user,
                value: msg.loadUint(1),
            }.toCell(),
        });
    }
}
