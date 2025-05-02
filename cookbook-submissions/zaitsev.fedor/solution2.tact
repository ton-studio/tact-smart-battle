struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

message DeployNewProposal {
    votingEndingAt: Int as uint32;
}

contract ProposalMaster {
    proposalId: Int = 0;
    // deploy
    receive() { }

    receive(msg: DeployNewProposal) {
        // This was a trick to pass last test
        throwUnless(61, now() <= msg.votingEndingAt);

        // send message to deploy new proposal
        let proposalInit: ProposalInit = ProposalInit {
            master: myAddress(),
            proposalId: self.getNextProposalId(),
        };

        let init: StateInit = initOf Proposal(proposalInit);

        deploy(DeployParameters{
            init: init,
            mode: SendRemainingValue,
            body: Time {
                votingEndingAt: msg.votingEndingAt,
            }.toCell(),
            value: 0,
        });

        self.proposalId += 1;
    }

    get fun nextProposalId(): Int {
        return self.getNextProposalId();
    }

    fun getNextProposalId(): Int {
        return self.proposalId;
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

message Time {
    votingEndingAt: Int as uint32;
}

contract Proposal {
    data: ProposalInit;
     // possible replace with an array
    votes: map<Address, Bool>;

    // should be uint7
    size: Int as uint32 = 0;
    votingEndingAt: Int as uint32 = -1;

    init(data: ProposalInit) {
        self.data = data;
        throwUnless(2025, sender() == self.data.master);
        self.votes = emptyMap();
    }

    receive(msg: Time) {
        throwUnless(2025, sender() == self.data.master);

        self.votingEndingAt = msg.votingEndingAt;
    }

    receive(msg: Vote) {
        throwUnless(61, now() <= self.votingEndingAt);

        throwUnless(61, self.size < 100);

        let address = sender();
        throwUnless(61, !self.votes.exists(address));


        self.votes.set(address, msg.value);
        self.size += 1;

    }

    get fun proposalState(): ProposalState {
        let yesCount: Int = 0;
        let noCount: Int = 0;

        foreach (address, vote in self.votes) {
            if (vote) {
                yesCount += 1;
            } else {
                noCount += 1;
            }
        }

        return ProposalState {
            yesCount: yesCount,
            noCount: noCount,
            master: self.data.master,
            proposalId: self.data.proposalId,
            votingEndingAt: self.votingEndingAt,
        };
    }
}
