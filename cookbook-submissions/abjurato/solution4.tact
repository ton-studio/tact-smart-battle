struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

message DeployNewProposal {
    votingEndingAt: Int as uint32;
}

message DeployNewProposalInternal {
    votingEndingAt: Int as uint32;
    author: Address;
}

contract ProposalMaster {
    nextProposalId: Int as uint32 = 0;

    // top up
    receive() {
        if (myBalance() > ton("0.01"))  {
            nativeReserve(ton("0.01"), ReserveAtMost);
            send( SendParameters{
                to: sender(),
                mode: SendRemainingBalance,
                bounce: false,
                value: 0,
                body: null
            });
        }
    }

    receive(msg: DeployNewProposal) {
        throwIf(
            2000,
            now() > msg.votingEndingAt
        );

        let proposal: StateInit = initOf Proposal(ProposalInit {
            master: myAddress(),
            proposalId: self.nextProposalId,
        });

        deploy(DeployParameters {
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: DeployNewProposalInternal{
                votingEndingAt: msg.votingEndingAt,
                author: sender(),
            }.toCell(),
            init: proposal,
        });

        self.nextProposalId += 1;
    }

    get fun nextProposalId(): Int {
        return self.nextProposalId;
    }

    get fun balance(): Int {
        return myBalance();
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
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;

    votes: map<Address, Bool>;
    count: Int as uint32;

    init(data: ProposalInit) {
        self.master = data.master;
        self.proposalId = data.proposalId;
        self.votingEndingAt = 0;
        self.votes = emptyMap();
        self.count = 0;
    }

    receive(msg: DeployNewProposalInternal) {
        let ctx: Context = context();

        throwUnless(
            2025,
            ctx.sender == self.master
        );

        self.votingEndingAt = msg.votingEndingAt;
        cashback(msg.author);
    }

    receive(msg: Vote) {
        let ctx: Context = context();

        throwIf( // impersonation attempt: deploy by sending Vote message
            2025,
            self.votingEndingAt == 0
        );

        throwIf(
            2000,
            now() > self.votingEndingAt
        );

        throwIf(
            2001,
            self.votes.exists(ctx.sender)
        );

        throwIf(
            2002,
            self.count >= 100
        );

        self.votes.set(ctx.sender, msg.value);
        self.count += 1;
        cashback(ctx.sender);
    }

    receive() {
        // any other message
        throwIf(2025, true);
    }


    get fun proposalState(): ProposalState {
        let yesCount: Int = 0;
        foreach (key, value in self.votes) {
            if (value) {
                yesCount += 1;
            }
        }

        return ProposalState{
            yesCount: yesCount,
            noCount: self.count - yesCount,
            master: self.master,
            proposalId: self.proposalId,
            votingEndingAt: self.votingEndingAt,
        }
    }
}
