message(1) Vote {
    value: Bool;
}
    
struct ProposalState {
    yesCount: Int as uint8;
    noCount: Int as uint8;
}
    
struct Init {
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}
    
contract Proposal {
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    voters: map<Address, Bool> = null;
    res: Int as uint16 = 0;
    
    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
    }
    
    receive() { }
    
    receive(msg: Vote) {
        throwUnless(400, ((self.res >> 8) + self.res & (255)) < 100 && now() < self.votingEndingAt && !self.voters.exists(sender()));
        self.voters.set(sender(), true);

        self.res += 1 << ((-8) *  msg.value.asInt());
        cashback(sender());
    }
    
    get fun proposalState(): ProposalState {
        return ProposalState{
            yesCount: self.res >> 8,
            noCount: self.res & ((1 << 8) - 1),
        };
    }
}
    
asm extends fun asInt(self: Bool): Int {}