## Level 2: Master Contract for Multiple Voting Proposals

### 1. Problem Statement

Implement two contracts: the `ProposalMaster` contract acting as a proxy
that deploys voting proposal contracts very similar to the `Proposal` contract
from Level 1, which records users' votes as before.

1. Each `Proposal` contract is identified by its master address and a unique `proposalId` number, which should start from zero and increase by one each time a new proposal is deployed.
2. Anyone can deploy a new proposal contract via the `ProposalMaster` contract.

Each deployed `Proposal` contract must satisfy the following requirements:

1. The voting is time-limited: no more votes can be accepted after the specified duration.
2. Only the first hundred (100) votes can be accepted.
3. No votes can be accepted after the voting deadline.
4. A voter is uniquely identified by their blockchain address.
5. Any voter can vote only one time.
6. A voter cannot change their mind and change how they cast their vote.
7. If a vote is not accepted, an exit code indicating unsuccessful execution must be thrown.
8. Your contracts' receivers should not consume too much gas: most tests won't send more than 0.1 Toncoin (the reference solution consumes way below this limit).
9. If someone tries to impersonate the `ProposalMaster` contract, the `Proposal` contract should throw exit code `2025`.

### 2. Interfaces

Your submission must adhere to the interfaces described in this section to ensure your contract can be tested automatically.
If your contract's interfaces are different, the tests will fail.

#### 2.1 File name and contract names

Your solution must be submitted in a file named `solution2.tact`, and the contracts must be named `ProposalMaster` and `Proposal`. Both contracts must be implemented in the same file: this is a feature Tact supports.

#### 2.2 `ProposalMaster` contract

The `ProposalMaster` contract [`init()` function](https://docs.tact-lang.org/book/contracts/#init-function) must not have any arguments. One way to achieve this would be not to have an `init()` function at all.

An [empty receiver](https://docs.tact-lang.org/book/receive/#receive-internal-messages) should be available to deploy the `ProposalMaster` contract:

```tact
receive() { }
```

To deploy a new voting proposal the `ProposalMaster` contract must accept messages of the `DeployNewProposal` message type:

```tact
message DeployNewProposal {
    votingEndingAt: Int as uint32;
}
```

If the current [Unix time](https://en.wikipedia.org/wiki/Unix_time) is greater than the value of the `votingEndingAt` field, the new `Proposal` contract must not get deployed.

The `ProposalMaster` contract needs to have a getter named `proposalState` to retrieve the id of the next proposal with the following signature:

```tact
get fun nextProposalId(): Int
```

#### 2.3 `Proposal` contract

Your contract's [`init()` function](https://docs.tact-lang.org/book/contracts/#init-function) should receive a single argument of the following type:

```tact
struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}
```

- The `master` field record the address of the `ProposalMaster` contract that deployed the current voting proposal.
- The `proposalId` field in the init structure ensures that more than one proposal contract can be deployed on the blockchain.

The `Proposal` contracts need to be initialized with zero vote counts upon deployment.

To allow casting votes, your `Proposal` contracts need to have a receiver accepting the `Vote` message type:

```tact
message Vote { value: Bool }
```

The `value` field of a `Vote` message means "yes" if it is `true`, or "no" otherwise.

Your contract needs to have a getter named `proposalState` to retrieve the current voting results with the following signature:

```tact
get fun proposalState(): ProposalState
```

This getter above needs to return the following `ProposalState` structure:

```tact
struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}
```

If the current [Unix time](https://en.wikipedia.org/wiki/Unix_time) is greater than the value of the `votingEndingAt` field, no more votes will be accepted by the `Proposal` contract which gets deployed with this deadline information.

#### 2.4 Solution template

You can find the contract interfaces described above in [solution2.tact](./solution2.tact).
Notice that you can add new receivers to your contracts in addition to the ones specified in the template.

### 3. Public tests

For a deeper understanding of how your contract will be tested and to ensure full compatibility, please refer to the public interface compatibility test: [public2.spec.ts](./public2.spec.ts).

Use the following command to execute the automated tests specifically for Level 2: 

```shell
npm run test2
```

The `test` script automatically compiles all the Tact contracts before running the tests.

Good luck with implementing **Level 2**!
