// Score: 100.44 

message Vote {
    /// Bool and uint1 are serialized the same,
    /// this is solely done to do arithmetic
    /// without Tact's type system complaining.
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

contract Proposal {
    const COUNT_SIZE: Int = 7;
    const VOTES_SIZE: Int = self.COUNT_SIZE * 2;
    /// Equivalent to 0b1111... with 14 ones.
    /// Used to extract vote counts from `self.data`
    const VOTE_MASK: Int = (1 << self.COUNT_SIZE) - 1;

    /// 256 is picked, since it's the first non-reserved exit code.
    /// Codes 0-127 are reserved by the TON Blockchain,
    /// 128-255 is reserved by Tact.
    /// Any of those exit codes can be thrown still, this is just a convention.
    ///
    /// Note: for extremely gas-conscious scenarios (like this contest),
    /// error codes < 64 can be preferred, since they use 8 less gas per throw.
    const ERR_VOTING_ENDED: Int = 256;
    const ERR_TOO_MANY_VOTES: Int = 257;
    const ERR_ALREADY_VOTED: Int = 258;

    /// 46 bits = 32 bits for time + `self.VOTES_SIZE`
    /// Storing everything in just one variable ends up more gas-efficient,
    /// due to serialization happening all at once: `.storeUint(self.data, 46)`,
    /// and also due to less things being on the stack,
    /// which reduces stack manipulation.
    data: Int as uint46;
    voters: map<Address, Cell>;

    init(data: Init) {
        // Initially all vote counts are set to 0,
        // so by shifting votingEndingAt we get properly initialized `self.data`
        self.data = data.votingEndingAt << self.VOTES_SIZE;
    }

    receive() {}

    receive(msg: Vote) {
        // Shifting now() by `self.VOTES_SIZE` allows to directly compare it to
        // votingEndingAt inside `self.data`.
        // The less significant bits don't affect the comparison.
        throwIf(self.ERR_VOTING_ENDED, now() << self.VOTES_SIZE > self.data);
        throwIf(
            self.ERR_TOO_MANY_VOTES,
            // Moving the yes count in the lower 32 bits, then adding it to
            // entire `self.data`, no overflow in this bit layout is guaranteed
            // due to maximum amount of votes being 100, but there is 7 bits
            // hence 128 values for each counter.
            // After addition mask is applied to get rid of other bits.
            (((self.data >> self.COUNT_SIZE) + self.data) & self.VOTE_MASK)
                >= 100
        );
        let s: Address = sender();
        throwIf(self.ERR_ALREADY_VOTED, self.voters.exists(s));

        // Doesn't matter what value is set, so just use an empty cell
        self.voters.set(s, emptyCell());
        cashback(s);

        // If the vote value is 1 (yes), then one to the left gets bitshifted
        // to be added to the actual yes counter, otherwise the shift ends up
        // being zero, so the one is just added to the lower bits, which is the
        // no counter.
        self.data += 1 << (self.COUNT_SIZE * msg.value);
    }

    get fun proposalState(): ProposalState {
        return ProposalState {
            // Bitshift to bring the yes counter in the lower 32 bits
            yesCount: (self.data >> self.COUNT_SIZE) & self.VOTE_MASK,
            // No bitshift necessary for no counter,
            // since it already resides in lower 32 bits
            noCount: self.data & self.VOTE_MASK,
        };
    }
}
