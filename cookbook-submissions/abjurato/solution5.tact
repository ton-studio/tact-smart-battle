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
    seqno: Int as uint32 = 0;

    inFlight: map<Int, Address>;

    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
        self.inFlight = emptyMap();
    }

    // deploy
    receive() { }

    receive(msg: Vote) {
        let sender = sender();
        require(
            now() <= self.votingEndingAt,
            "Voting has ended"
        );
        self.seqno += 1;
        self.inFlight.set(self.seqno, sender);
        deploy(DeployParameters{
            value: 0,
            mode: SendRemainingValue,
            bounce: true,
            body: VoteInternal{
                seqno: self.seqno,
                vote: msg.value,
            }.toCell(),
            init: initOf VoteToken(
                sender,
                myAddress(),
            ),
        });
    }

    bounced(msg: bounced<VoteInternal>) {
        let owner = self.inFlight.get(msg.seqno);
        if (owner != null) {    
            self.inFlight.del(msg.seqno);
            cashback(owner!!);
        }
    }

    receive(msg: VoteInternal) {
        self.inFlight.del(msg.seqno);

        if (msg.vote) {
            self.yesCount += 1;
        }
        self.count += 1;

        send(SendParameters{
            to: sender(),
            value: 0,
            mode: SendRemainingValue,
            bounce: true,
            body: VoteRecorded{
                seqno: msg.seqno,
            }.toCell()
        });
    }

    get fun proposalState(): ProposalState {
        return ProposalState{
            yesCount: self.yesCount,
            noCount: self.count - self.yesCount
        };
    }
}

message VoteInternal {
    seqno: Int as uint32;
    vote: Bool;
}

message VoteRecorded {
    seqno: Int as uint32;
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
    
    receive(msg: VoteInternal) {
        let sender = sender();
        require(
            !self.alreadyVoted,
            "Already voted"
        );
        require(
            sender == self.proposal,
            "Invalid proposal ID"
        );

        send(SendParameters{
            to: sender,
            value: 0,
            mode: SendRemainingValue,
            bounce: true,
            body: msg.toCell()
        });
    }

    receive(msg: VoteRecorded) {
        self.alreadyVoted = true;
        cashback(self.owner);
    }

    bounced(msg: bounced<VoteInternal>) {
        self.alreadyVoted = false;
        cashback(self.owner);
    }

    // unsupported messages
    receive() {    
        throwIf(1, true);
     }
}