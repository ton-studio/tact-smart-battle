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

const ERROR_ENDED: Int = 2021;
const ERROR_LIMIT_REACHED: Int = 2022;
const ERROR_ALREADY_VOTED: Int = 2023;

contract Proposal {
    const MAX_VOTES: Int = 100;

    votingEndingAt: Int as uint32;
    count: Int as uint8 = 0;
    votes: map<Address, Bool>;

    init(data: Init) {
        self.votingEndingAt = data.votingEndingAt;
    }

    // deploy
    receive() { }

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
        return ProposalState { yesCount, noCount };
    }
}
