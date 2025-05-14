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
    
    // map for temp storage of address to make cashbak from exactly Proposal contract
    tmp: map<Int as uint32, Address> = null;

    // In this realisation special counter in used to identify address. but it is possible to do without it
    cnt: Int as uint32 = 0;
    
    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
    }
    
    // deploy
    receive() { }
    
    receive(msg: Vote) {
        throwUnless(400, now() < self.votingEndingAt);

        // It is not the best solution, although it passes the tests. It is better to calculate gas based on current prices via getForwardFee() + getComputerFee()
        throwUnless(400, context().value > ton("0.099"));
    
        self.tmp.set(self.cnt, sender());
    
        deploy(DeployParameters{
            mode: SendRemainingValue,
            value: 0,
            body: VoteInternal{
                value: msg.value,
                cnt: self.cnt,
            }.toCell(),
            init: initOf VoteToken(myAddress(), sender(), false),
        });
    
        self.cnt += 1;
    }
    
    bounced(msg: VoteInternal) {
        cashback(self.tmp.replaceGet(msg.cnt, null)!!);
    }
    
    receive(msg: VoteInternal) {
        throwUnless(400, (initOf VoteToken(myAddress(), self.tmp.get(msg.cnt)!!, false)).hasSameBasechainAddress(sender()));
        self.res += 1 << ((-32) * msg.value.asInt());

        cashback(self.tmp.replaceGet(msg.cnt, null)!!);
    }
    
    get fun proposalState(): ProposalState {
        return ProposalState{
            yesCount: self.res >> 32,
            noCount: self.res & ((1 << 32) - 1),
        };
    }
}
    
message(2) VoteInternal {
    value: Bool;
    cnt: Int as uint32;
}
    
contract VoteToken (
    proposal: Address,
    voter: Address,
    isInited: Bool,
) {
    receive(msg: VoteInternal) {
        throwUnless(400, self.isInited == false);
        throwUnless(400, sender() == self.proposal);
        self.isInited = true;
        
        message(MessageParameters{
            to: self.proposal,
            value: 0,
            mode: SendRemainingValue,
            body: VoteInternal{
                value: msg.value,
                cnt: msg.cnt,
            }.toCell(),
        })
    }
}

// ASM function to convert Bool to Int
asm extends fun asInt(self: Bool): Int {}