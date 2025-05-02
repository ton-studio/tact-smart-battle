struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

message DeployNewProposal {
    votingEndingAt: Int as uint32;
}

contract ProposalMaster {
    const MAX_ACCEPTABLE_BALANCE: Int = 10_000_000; // this is 0.01 TON

    proposalId: Int = 0;

    // deploy
    receive() {
 
        if (myBalance() <= self.MAX_ACCEPTABLE_BALANCE) {
            //dump("I accepted everything");
            return;
        }
 
 
        // it probably doesn't matter to optimize it to be exactly 0.01 TON
        if (context().value > 20_531_600) {
            message(MessageParameters {
                mode: SendIgnoreErrors,
                body: null,
                value: context().value - 20_531_600,
                to: sender(),
                bounce: false,
            });
        }
        
    }

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
            mode: SendIgnoreErrors | SendRemainingValue,
            body: Time {
                originalSender: sender(),
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
    originalSender: Address;
    votingEndingAt: Int as uint32;
}

contract Proposal {
    data: ProposalInit;
    
    // possible replace with an array
    votes: map<Address, Bool>;

    // should be uint7
    size: Int as uint7 = 0;

    votingEndingAt: Int as uint32 = -1;

    init(data: ProposalInit) {
        self.data = data;
        throwUnless(2025, sender() == self.data.master);
        self.votes = emptyMap();
    }

    receive(msg: Time) {
        throwUnless(2025, sender() == self.data.master);
        self.votingEndingAt = msg.votingEndingAt;
        //cashback(msg.originalSender);
        if (context().value > 5_000_000_000) {
            cashback(msg.originalSender);
        }
    }

    receive(msg: Vote) {
        throwUnless(61, self.size < 100);
        //require(now() <= self.votingEndingAt, "Voting has ended");
        throwUnless(61, now() <= self.votingEndingAt);

        let address = sender();

        throwUnless(61, !self.votes.exists(address));
    
        self.votes.set(address, msg.value);
        self.size += 1;
        
        if (context().value > 5_000_000_000) {
            cashback(address);
        }
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

