message(0x193b63cd) Vote {
    value: Int as int2; // 1 for yes, 0 for no
}

struct ProposalState {
    yesCount: Int;
    noCount: Int;
}

struct Init {
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}

contract Proposal {
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    yesCount: Int = 0;
    noCount: Int = 0;

    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
    }

    // does not process bounced messages

    receive() {}

    receive(msg: Vote) {
        let init: StateInit = initOf Voter(VoterInit { owner: sender(), proposal: myAddress() });
        deploy(
            DeployParameters {
                init: init,
                value: 0, // it will send all the remaining value since we do not need to reimburse the incoming TONs
                mode: SendRemainingValue + SendIgnoreErrors,
                body: msg.toCell(),
            },
        );
    }

    receive(msg: VoteResponse) {
        let sender = contractAddress(initOf Voter(VoterInit { owner: msg.owner, proposal: myAddress() }));
        // check if the sender is the Voter contract
        throwUnless(2025, sender == sender());
        // throw if proposal has expired
        throwIf(258, now() > self.votingEndingAt);
        self.yesCount += msg.value;
        self.noCount += ((-1) * (msg.value - 1));
    }

    get fun proposalState(): ProposalState {
        return ProposalState { yesCount: self.yesCount, noCount: self.noCount };
    }
}

// ==============================================================================

struct VoterInit {
    owner: Address;
    proposal: Address;
}

message(0x5d918b6a) VoteResponse {
    value: Int as int2;
    owner: Address;
}

// it would be better to call the Voter contract directly instead of calling the Proposal contract to vote
contract Voter {
    owner: Address;
    proposal: Address;
    hasVoted: Bool = false;

    init(data: VoterInit) {
        self.owner = data.owner;
        self.proposal = data.proposal;
    }

    // does not process bounced messages

    receive(msg: Vote) {
        // not voted yet
        throwIf(259, self.hasVoted);
        self.hasVoted = true;

        // call the proposal contract to vote
        message(MessageParameters {
            to: self.proposal,
            value: 0,
            body: VoteResponse { value: msg.value, owner: self.owner }.toCell(),
            mode: SendRemainingValue + SendIgnoreErrors,
        });
    }
}
