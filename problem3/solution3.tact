//
// Reference solution
//

message Vote {
    value: Bool;
}

message VoteConfirmed {
    value: Bool;
    voter: Address;
}

message DeployBallot {}

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

    yesCount: Int as uint32 = 0;
    totalCount: Int as uint32 = 0;

    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
    }

    // deploy
    receive() {}

    receive(msg: Vote) {
        // Voting is already finished!
        throwUnless(701, now() < self.votingEndingAt);
        // this solution does not handle cases when we run out of gas until
        // the ballot sends a callback to the proposal contract: this
        // will be part of level 5

        let ballot = initOf Ballot(
            sender(),
            myAddress(),
            false,
        );
        deploy(DeployParameters {
            mode: SendRemainingValue,
            value: 0,
            bounce: false,
            body: msg.toCell(),
            init: ballot,
        });
    }

    receive(msg: VoteConfirmed) {
        let ballot = initOf Ballot(
            msg.voter,
            myAddress(),
            false,
        );
        throwUnless(704, ballot.hasSameBasechainAddress(sender()));

        if (msg.value) {
            self.yesCount += 1;
        }

        self.totalCount += 1;
    }

    get fun proposalState(): ProposalState {
        return ProposalState {
            yesCount: self.yesCount,
            noCount: self.totalCount - self.yesCount,
        };
    }
}

contract Ballot(
    voter: Address,
    proposal: Address,
    hasVoted: Bool,
) {
    receive(msg: Vote) {
        if (self.hasVoted) {
            return;
        }

        // Can only accept messages from the corresponding Proposal contract
        throwUnless(703, sender() == self.proposal);

        message(MessageParameters {
            to: self.proposal,
            mode: SendRemainingValue,
            value: 0,
            bounce: false,
            body: VoteConfirmed { value: msg.value, voter: self.voter }.toCell(),
        });

        self.hasVoted = true;
    }
}
