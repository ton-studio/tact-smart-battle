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
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;

    yesCount: Int as uint32 = 0;
    count: Int as uint32 = 0;

    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
    }

    receive(msg: Vote) {
        require(
            now() <= self.votingEndingAt,
            "Voting has ended"
        );

        if (msg.value) {
            self.yesCount += 1;
        }
        self.count += 1;

        deploy(DeployParameters{
            value: 0,
            mode: SendRemainingValue,
            body: msg.toCell(),
            init: initOf VoteToken(
                sender(),
                myAddress(),
            ),
        });
    }

    bounced(msg: Vote) {
        if (msg.value) {
            self.yesCount -= 1;
        }
        self.count -= 1;
    }

    // deploy
    receive() { }

    get fun proposalState(): ProposalState {
        return ProposalState{
            yesCount: self.yesCount,
            noCount: self.count - self.yesCount
        };
    }
}

contract VoteToken {
    owner: Address;
    proposal: Address;
    alreadyVoted: Bool;

    init(owner: Address, proposal: Address) {
        self.owner = owner;
        self.proposal = proposal;
        self.alreadyVoted = false;
    }
    
    receive(msg: Vote) {
        require(
            !self.alreadyVoted,
            "Already voted"
        );
        require(
            sender() == self.proposal,
            "Invalid proposal ID"
        );

        self.alreadyVoted = true;
    }

    // unsupported messages
    receive() {    
        throwIf(1, true);
     }
}