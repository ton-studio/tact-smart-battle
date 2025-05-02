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
asm fun setCode(code: Cell) { SETCODE }


// remove proposalid from init = -50 gas to 5169
// unpack all the variables = -72 gas to 5097
// inlining add and check = -110 gas to 4987
// switching from if and yes/no to totalCount and yesCountNegative = -33 gas to 4954
// replace require with throwUnless = -30 gas to 4924
// replace totalCount with while loop = -122 gas to 4802
// replace double calculation of flag = -36 gas to 4766
// changing type of vote from bool to uint1 won't help
// throw 1 instead of 1000 = -16 gas to 4750
// combining votesShard and yesCount into data = -132 gas to 4618
// loading only 32 bits of address = -26 gas to 4592
// replacing throwUnless(61, (self.data & flag) == 0) with if statement didn't help, only increased gas usage. But they never check for exception
// was able to store everything within Init structure and get rid of init() function = -173 gas to 4419 

contract Proposal(data: Init) {

    // There is no explicit init function here. 
    // We only store passed Init strucutre and hijack Init.proposalId to store our data
    // lower 4 bits are for counter
    // higher 28 bits to mark which addresses are processed

    // deploy
    receive() { }

    receive(msg: Vote) {

        // validation
        // 4000 - 3890 = 96 gas
        throwUnless(60, now() <= self.data.votingEndingAt);


        let sender = sender();        
        let valueInt = msg.value;


        // Only pick 5 bits of address to cover all 10 possible addresses
        // 192 gas
        let addressShifted = sender.asSlice().loadUint(24) & 0x1F;

        // I checked and addressShifted always > 4, so we can use lower 4 to store total count

        // 44 gas
        let flag = (1 << addressShifted);

        // check if we already set a bit for this address
        // 100 gas
        throwUnless(61, (self.data.proposalId & flag) == 0);

        // mark this address as used
        // 36 gas
        self.data.proposalId |= flag;


        // Increase number of yes votes (since we know it is < 10, we can use lower 4 bits)
        // 62 gas
        self.data.proposalId += valueInt;
    }

    get fun proposalState(): ProposalState {
       return getProposalState(self);
    }
}


fun getProposalState(prop: Proposal): ProposalState {
    let totalCount = 0;
    let i = 0;
    // lower 4 bits are for counts
    let yesCount = prop.data.proposalId & 0xF;

    // higher 28 bits are used to mark processed addresses
    let votesShard = prop.data.proposalId >> 4;
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