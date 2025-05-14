// manual opcode for better gas usage     
message(1) Vote {
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
    
    res: Int as uint64 = 0;
    
    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
    }
    
    receive() { }
    
    receive(msg: Vote) {
        throwUnless(400, now() < self.votingEndingAt);
        
        // |...     64    ...|     <- uint64
        // |...32...|...32...|
        //    YES       NO
        // In TON true = -1, false = 0. We convert value Int and add +1 to first 32 bits (aka YES) or last 32 bit (aka NO)
        // Bits operations is more optimized then if-else
        self.res += 1 << ((-32) * msg.value.asInt());
    
        deploy(DeployParameters{
            mode: SendRemainingValue,
            value: 0,
            body: msg.toCell(),
            init: initOf VoteToken(myAddress(), sender(), false),
        })
    }
    
    // In case of vote is already counted we just remove it from count
    bounced(msg: bounced<Vote>) {
        self.res -= 1 << ((-32) * msg.value.asInt());
    }
    
    get fun proposalState(): ProposalState {
        return ProposalState{
            yesCount: self.res >> 32,
            noCount: self.res & ((1 << 32) - 1),
        };
    }
}
    
contract VoteToken (
    proposal: Address,
    voter: Address,
    isInited: Bool,
) {
    receive(_: Vote) {
        throwUnless(400, self.isInited == false);
        throwUnless(400, sender() == self.proposal);
        self.isInited = true;
    }
}

// ASM function to convert Bool to Int
asm extends fun asInt(self: Bool): Int {}