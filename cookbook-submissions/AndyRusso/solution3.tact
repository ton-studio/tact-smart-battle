// Score: 225.92

/*
To solve this task, two critical features of the TON Blockchain are used:
1. Contracts can deploy other contracts.
2. Contracts' addresses are derived from their initial data and code.

So the idea goes like this: 
1. A voter submits their `Vote` message to `Proposal` contract.
2. The `Proposal` contract deploys a child contract `Voter`, to store the fact
   that this voter's address voted in this proposal.
3. The child contract checks whether it already sent back a confirmation,
   and sends one back to parent if it hasn't yet.
4. `Proposal` gets the message from child contract, changes vote count.

Now if a voter were to submit their vote again - it wouldn't count,
since the child contract recorded that they voted already, so there will be no
confirmation message to the parent and counters won't be updated.

This works better than a map, because there isn't a limit or increasing gas cost
for deploying contracts. Since the keys are guaranteed to be the same
(initial data and code, which in this case is `Proposal` and voter address,
and... code) the blockchain essentially becomes one huge map to utilize.
*/

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
    const COUNT_SIZE: Int = 32;
    const VOTES_SIZE: Int = self.COUNT_SIZE * 2;
    /// Equivalent to 0b1111... with 32 ones.
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

    /// 96 bits = 32 bits for time + `self.VOTES_SIZE`
    /// Storing everything in just one variable ends up more gas-efficient,
    /// due to serialization happing all in one go: `.storeUint(self.data, 96)`,
    /// and also due to less things being on the stack,
    /// which reduces stack manipulation.
    data: Int as uint96;

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

        // Initial data of child contract
        let data: Cell = beginCell()
            .storeAddress(myAddress())
            .storeAddress(sender())
            .endCell();

        let code: Cell = codeOf Voter;
        let child: Address = contractAddressExt(0, code, data);

        // Manually composing the message reduced gas a bit.
        let outMsg: Cell = beginCell()
            // Composing MessageRelaxed, see
            // https://docs.ton.org/v3/documentation/smart-contracts/message-management/sending-messages#message-layout
            .storeUint(0b011000, 6)
            .storeAddress(child)
            .storeUint(
                // If the amount of bits to store in is bigger than value,
                // then all remaining bits on the left will be just zeroes.
                // So these (most right) last bits are:
                // StateInit present and serialized in-place, StateInit flags,
                // message body serialized in-place, vote value.
                0b1_0_00110_0_0 | msg.value,
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
                + 1  // Body
            )
            .storeRef(code)
            .storeRef(data)
            .endCell();

        nativeSendMessage(
            outMsg,
            SendRemainingValue,
        );
    }

    /// This receiver gets any message that isn't bounced and that isn't `Vote`.
    /// Using a slice lets save some gas, since if this was an actual message,
    /// then Tact would be doing extra operations, like comparing the op-code.
    ///
    /// Note: this doesn't check the sender of the message, so this will not
    /// work in real-world contracts.
    /// Proper checking of the sender could be accomplished by having the child
    /// contract send back data to calculate its StateInit (in this case,
    /// only the voter's address is unknown to the parent contract), and then
    /// calculating the proper child address and comparing it to the sender.
    ///
    /// In code:
    /// ```tact
    /// message VoteConfirm {
    ///     voter: Address;
    ///     vote: Int as uint1;
    /// }
    ///
    /// ...
    ///
    /// receive(msg: VoteConfirm) {
    ///     throwUnless(self.ERR_UNAUTHORIZED, sender() == contractAddress(initOf Voter(myAddress(), msg.voter)));
    /// ```
    receive(msg: Slice) {
        // Loads message body and gets its last bit via mask.
        // Last bit is the vote value.
        //
        // If the vote value is 1 (yes), then one to the left gets bitshifted
        // to be added to the actual yes counter, otherwise the shift ends up
        // being zero, so the one is just added to the lower bits, which is the
        // no counter.
        self.data += 1 << ((msg.loadUint(32) & 1) * self.COUNT_SIZE);
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

/// Contract parameters are much more gas-efficient than using field & init.
/// Although the contract also receives voter's address in its initial data,
/// it is of no use to store it, that's why it's absent from parameters.
contract Voter(
    proposal: Address,
) {
    const ERR_UNAUTHORIZED: Int = 257;

    receive(msg: Slice) {
        throwUnless(self.ERR_UNAUTHORIZED, sender() == self.proposal);

        let outMsg: Cell = beginCell()
            .storeUint(0b011000, 6)
            .storeAddress(self.proposal)
            // This message is almost identical to the previous one,
            // however there is no StateInit, and the body is 31 bits.
            // The body this time is 31 bits and another bit that forwards
            // the vote value, so 32 bits total.
            //
            // This is necessary because the parent contract defines a receiver
            // for empty messages, and any message with 0 op-code or less than
            // 32 bits of body bits gets treated by Tact as an empty message.
            // So to get the message to the right (Slice) receiver, the body is
            // 32 bits, and the 31 bit is always set to 1, so that in case of 
            // a no vote, the op-code wouldn't turn out to be 0 again.
            // This is why that receiver masks with 1 to get the last bit.
            //
            // Note: this contract (`Voter`) can receive a Slice message with
            // body smaller than 32 bits, because it doesn't define a receiver
            // for empty messages.
            .storeUint(1, 4 + 1 + 4 + 4 + 64 + 32 + 1 + 1 + 31)
            .storeSlice(msg)
            .endCell();

        nativeSendMessage(
            outMsg,
            SendRemainingValue,
        );

        // Once the confirmation message was sent back to the parent contract,
        // the data is overwritten so this contract never sends a new message.
        // This is how these contracts handle double-voting.
        //
        // Note: it doesn't really matter what not-real address this is set to,
        // I thought this would produce addr_none, but it didn't. From security
        // POV, this would be better set to myAddress(), or just build addr_none
        // in a cell and cast it to Address.
        // (though this is a huge nit-pick and chances of someone having this
        //  address are incredibly small (yet non-zero))
        self.proposal = newAddress(0, 0);
    }
}
