struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}
    
message(1) DeployNewProposal {
    votingEndingAt: Int as uint32;
}
    
contract ProposalMaster {
    nextProposalId: Int as uint32 = 0;
    
    receive() { }
    
    receive(msg: DeployNewProposal) {
        throwUnless(400, now() < msg.votingEndingAt);
    
        deploy(DeployParameters{
            mode: SendRemainingValue,
            value: 0,
            body: msg.toCell(),
            init: initOf Proposal(ProposalInit{
                master: myAddress(),
                proposalId: self.nextProposalId
            })
        });
    
        self.nextProposalId += 1;
    }
    
    get fun nextProposalId(): Int {
        return self.nextProposalId;
    }
}
    
// ==============================================================================
    
message(2) Vote {
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
    proposalId: Int;
    res: Int as uint16 = 0;
    votingEndingAt: Int as uint32 = 0;
    
    
    voters: map<Address, Bool> = null;
    
    init(data: ProposalInit) {
        throwUnless(2025, sender() == data.master);
        self.master = data.master;
        self.proposalId = data.proposalId;
    }
    
    receive(msg: DeployNewProposal) {
        throwUnless(2025, sender() == self.master);
        self.votingEndingAt = msg.votingEndingAt;
    }
    
    receive(msg: Vote) {
        throwUnless(400, ((self.res >> 8) + self.res & (255)) < 100 && now() < self.votingEndingAt && !self.voters.exists(sender()));
        self.voters.set(sender(), true);

        self.res += 1 << ((-8) *  msg.value.asInt());
    }
    
    get fun proposalState(): ProposalState {
        return ProposalState {
            yesCount: self.res >> 8,
            noCount: self.res & ((1 << 8) - 1),
            master: self.master,
            proposalId: self.proposalId,
            votingEndingAt: self.votingEndingAt,
        };
    }
}

asm extends fun asInt(self: Bool): Int {}