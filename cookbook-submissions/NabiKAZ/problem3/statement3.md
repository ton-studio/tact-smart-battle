## Level 3: Scalable single-proposal Voting Contract

### 1. Problem Statement

You need to implement a smart contract that allows to vote "yes" or "no" on some proposal.
Compared to Level 1 there is one important distinction: this time the voting contract needs to be scalable and should handle any number of voters up to 4 billion.

1. The size of the storage of the proposal contract cannot exceed `100 000` bits.
2. Anyone can deploy the proposal contract.
3. The voting is time-limited: no more votes can be accepted after the specified duration.
4. Any number of votes can be accepted.
5. No votes can be accepted after the voting deadline.
6. A voter is uniquely identified by their blockchain address.
7. Any voter can vote only one time.
8. A voter cannot change their mind and change how they cast their vote.
9. If a vote is not accepted, an exit code indicating unsuccessful execution must be thrown.
10. Your contract's receivers should not consume too much gas: most tests won't send more than 0.1 Toncoin (the reference solution consumes way below this limit).

### 2. Interfaces

Your submission must adhere to the interfaces described in this section to ensure your contract can be tested automatically.
If your contract's interfaces are different, the tests will fail.
The interface described below is exactly the same as in Level 1.

#### 2.1 File name and contract name

Your solution must be submitted in a file named `solution3.tact`, and the contract must be named `Proposal`.

#### 2.2 Contract deployment

Your contract's [`init()` function](https://docs.tact-lang.org/book/contracts/#init-function) should receive a single argument of the following type:

```tact
struct Init {
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}
```

- The `proposalId` field in the init structure ensures that more than one proposal contract can be deployed on the blockchain.
- If the current [Unix time](https://en.wikipedia.org/wiki/Unix_time) is greater than the value of the `votingEndingAt` field, no more votes will be accepted.

An [empty receiver](https://docs.tact-lang.org/book/receive/#receive-internal-messages) should be available to deploy your contract:

```tact
receive() { }
```

Protection against funds freezing is not required here.

#### 2.3 Voting

To allow casting votes, your contract needs to have a receiver accepting the `Vote` message type:

```tact
message Vote { value: Bool }
```

The `value` field of a `Vote` message means "yes" if it is `true`, or "no" otherwise.

#### 2.4 Retrieving voting data from your contract 

Your contract needs to have a getter named `proposalState` to retrieve the current voting results with the following signature:

```tact
get fun proposalState(): ProposalState
```

This getter above needs to return the pair of "yes" and "no" votes packed into the `ProposalState` structure:

```tact
struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
}
```

#### 2.5 Solution template

You can find the contract interfaces described above in [solution3.tact](./solution3.tact).

### 3. Public Tests

For a deeper understanding of how your contract will be tested and to ensure full compatibility, please refer to the public interface compatibility test: [public3.spec.ts](./public3.spec.ts).

Use the following command to execute the automated tests specifically for Level 3: 

```shell
npm run test3
```

The `test` script automatically compiles all the Tact contracts before running the tests.

Good luck with implementing **Level 3**!