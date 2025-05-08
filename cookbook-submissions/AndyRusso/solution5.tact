// Score: 260.63

// These values might not represent actual gas and forward fee usage, not sure.
// However they passed tests.

const GAS_USAGE_VOTER: Int = 3916;
const GAS_USAGE_VOTE_CONFIRM: Int = 5933;

const CELLS_SENT_VOTER: Int = 0;
const CELLS_SENT_VOTE_CONFIRM: Int = 1;

const BITS_SENT_VOTER: Int = 1005;
const BITS_SENT_VOTE_CONFIRM: Int = 705;

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
    /// 256 is picked, since it's the first non-reserved exit code.
    /// Codes 0-127 are reserved by the TON Blockchain,
    /// 128-255 is reserved by Tact.
    /// Any of those exit codes can be thrown still, this is just a convention.
    ///
    /// Note: for extremely gas-conscious scenarios (like this contest),
    /// error codes < 64 can be preferred, since they use 8 less gas per throw.
    const ERR_VOTE_ENDED: Int = 256;
    const ERR_UNAUTHORIZED: Int = 257;

    yesCount: Int as uint32;
    noCount: Int as uint32;
    votingEndingAt: Int as uint32;

    init(data: Init) {
        self.votingEndingAt = data.votingEndingAt;
        self.yesCount = 0;
        self.noCount = 0;
    }

    receive() {}

    receive(msg: Vote) {
        throwIf(self.ERR_VOTE_ENDED, now() > self.votingEndingAt);

        let init: StateInit = initOf Voter(myAddress(), sender(), false);

        // Manually composing the message reduced gas a bit.
        let outMsg: Cell = beginCell()
            // Composing MessageRelaxed, see
            // https://docs.ton.org/v3/documentation/smart-contracts/message-management/sending-messages#message-layout
            .storeUint(0b011000, 6)
            .storeAddress(contractAddress(init))
            .storeUint(
                // If the amount of bits to store in is bigger than value,
                // then all remaining bits on the left will be just zeroes.
                // So these (most right) last bits are:
                // StateInit present and serialized in-place, StateInit flags,
                // message body serialized in-place.
                0b1_0_00110_0,
                + 4  // nanotons (zero)
                + 1  // other (empty extra-currency dict)
                + 4  // ihr_fee
                + 4  // fww_fee
                + 64 // created_lt
                + 32 // created_at
                + 1  // StateInit present
                + 1  // StateInit serialized in this cell, not in a reference
                + 5  // StateInit flags: https://github.com/ton-blockchain/ton/blob/master/crypto/block/block.tlb#L144
                + 1  // Message body serialized in this cell, not in a reference
            )
            .storeRef(init.code)
            .storeRef(init.data)
            .storeBool(msg.value)
            .endCell();

        nativeSendMessage(
            outMsg,
            SendRemainingValue,
        );
    }

    receive(msg: Slice) {
        let vote: Int = msg.loadUint(1);
        let voter: Address = msg.loadAddress();
        throwUnless(
            self.ERR_UNAUTHORIZED,
            sender() == contractAddress(initOf Voter(myAddress(), voter, false)),
        );
        cashback(voter);

        // Conditionals are generally expensive in TVM,
        // so doing math consumes less gas.
        self.yesCount += vote;
        self.noCount -= vote - 1;
    }

    get fun proposalState(): ProposalState {
        return ProposalState {
            yesCount: self.yesCount,
            noCount: self.noCount,
        };
    }
}

contract Voter(
    petition: Address,
    voter: Address,
    voted: Bool,
) {
    const ERR_UNAUTHORIZED: Int = 258;
    const ERR_NO_GAS: Int = 259;

    receive(msg: Slice) {
        throwUnless(self.ERR_UNAUTHORIZED, sender() == self.petition);

        if self.voted {
            cashback(self.voter);
            // The task's condition was to throw if a vote was not accepted.
            // So to throw and send the cashback - commit is used.
            // https://docs.tact-lang.org/ref/core-contextstate/#commit
            // (c5 is where actions such as messages are stored)
            commit();
            throw(258);
        }

        // The crux of this task is to gracefully handle out of gas errors.
        // This is the only place where handling out of gas is necessary.
        // If gas runs out during compute phase of parent's vote confirmation,
        // then vote counters won't be updated, while the child contract
        // has already recorded the vote.
        //
        // To prevent this, gas usage is calculated off-chain with tests
        // and is being calculated with proper config values at compute phase.
        // Also forward fee is accounted, which is the fee that is paid for
        // sending a message.
        //
        // Upon a fresh look, adding forward fee of the last message
        // is unnecessary, since `cashback` sets `SendIgnoreErrors`
        throwIf(
            self.ERR_NO_GAS,
            context().value <= (
                + getForwardFee(CELLS_SENT_VOTER, BITS_SENT_VOTER, false)
                + getComputeFee(GAS_USAGE_VOTER, false)
                + getComputeFee(GAS_USAGE_VOTE_CONFIRM, false)
                + getForwardFee(
                    CELLS_SENT_VOTE_CONFIRM,
                    BITS_SENT_VOTE_CONFIRM,
                    false
                )
            )
        );

        self.voted = true;

        let outMsg: Cell = beginCell()
            .storeUint(0b011000, 6)
            .storeAddress(self.petition)
            // This message is almost identical to the previous one,
            // however there is no StateInit,
            // and the body is vote value and voter address.
            .storeUint(
                msg.preloadUint(1),
                (4 + 1 + 4 + 4 + 64 + 32 + 1 + 1) + 1
            )
            .storeAddress(self.voter)
            .endCell();

        nativeSendMessage(
            outMsg,
            SendRemainingValue,
        );
    }
}
