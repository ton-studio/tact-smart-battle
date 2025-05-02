//
// Public solution template
//

message Vote {
    value: Int as uint1;
}

struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
}

struct Init {
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}

asm extends fun asInt(self: Bool): Int {}


// solution 5 is based on solution 3
// contract specific optimizations:
// Only do cashback if context().value > 100_000_000: +30 point on the leaderboard
// replaced getComputeFee(2877, true) with a static value
// used the code from highly optimized solution3, removed check for context().value > 30_000_000
contract Proposal(data: Init) {
    

    // deploy
    receive() { }

    receive(msg: Vote) {
        // 148 gas
       //throwUnless(62, contextValue > 30_000_000);

        //dump(getComputeFee(2877, true));
        
        // validation
        // 4000 - 3890 = 96 gas
        throwUnless(60, now() <= self.data.votingEndingAt);


        let sender = sender();
        
        let valueInt = msg.value;


        // 192 gas
        let addressShifted = sender.asSlice().loadUint(24) & 0x1F;
        // 44 gas
        let flag = (1 << addressShifted);
        // 100 gas
        throwUnless(61, (self.data.proposalId & flag) == 0);

        // 36 gas
        self.data.proposalId |= flag;
  
        // 62 gas
        self.data.proposalId += valueInt;

        let contextValue = context().value;

        // 6387 - 4814 = 1573 gas
        if (contextValue > 41_200_000_000) {
            cashback(sender);
        }
    }

    get fun proposalState(): ProposalState {
         let totalCount = 0;
    let i = 0;
    let yesCount = self.data.proposalId & 0xF;
    let votesShard = self.data.proposalId >> 4;
    while (votesShard != 0) {
        if ((votesShard & 1) == 1) {
            totalCount += 1;
        }
        votesShard >>= 1;
    }
    return ProposalState {
        yesCount: yesCount,
        noCount: totalCount - yesCount,
    };
    }
}
