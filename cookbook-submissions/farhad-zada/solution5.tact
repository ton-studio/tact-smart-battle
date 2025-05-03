message(0x193b63cd) Vote {
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
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    proposalState: ProposalState;

    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
        self.proposalState = ProposalState { yesCount: 0, noCount: 0 };
    }

    receive() {}

    receive(msg: Vote) {
        let forwardFee: Int = getForwardFee(9, 4400, false);
        let computeFee: Int = getComputeFee(20005, false);
        throwUnless(300, context().value > forwardFee + computeFee);
        throwUnless(301, now() <= self.votingEndingAt);
        deploy(DeployParameters {
            init: initOf Voter(VoterInit { owner: sender(), proposal: myAddress() }),
            mode: SendRemainingValue + SendIgnoreErrors,
            body: msg.toCell(),
            value: 0,
        });
    }

    receive(msg: VoterResponse) {
        // invalid voter
        throwIf(302, contractAddress(initOf Voter(VoterInit { owner: msg.voter, proposal: myAddress() })) != sender());
        if (msg.value) {
            self.proposalState.yesCount += 1;
        } else {
            self.proposalState.noCount += 1;
        }
        cashback(msg.voter);
    }

    get(0x13962) fun proposalState(): ProposalState {
        return self.proposalState;
    }
}

struct VoterInit {
    proposal: Address;
    owner: Address;
}

message(0x658841e3) VoterResponse {
    voter: Address;
    value: Bool;
}
contract Voter {
    proposal: Address;
    owner: Address;
    hasVoted: Bool = false;

    init(data: VoterInit) {
        self.proposal = data.proposal;
        self.owner = data.owner;
    }

    receive(msg: Vote) {
        try {
            throwIf(400, self.hasVoted);
            throwIf(401, self.proposal != sender());
            self.hasVoted = true;
            message(MessageParameters {
                to: sender(),
                value: 0,
                mode: SendRemainingValue + SendIgnoreErrors,
                body: VoterResponse { voter: self.owner, value: msg.value }.toCell(),
            });
        } catch (e) {
            cashback(self.owner);
        }
    }
}
