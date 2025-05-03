import '@ton/test-utils';
import { Blockchain } from '@ton/sandbox';
import { toNano } from '@ton/core';
import { Proposal } from '../output/solution3_Proposal';

it('solution3', async () => {
    const blockchain = await Blockchain.create();

    // create contract from init()
    const proposal = blockchain.openContract(
        await Proposal.fromInit({
            $$type: 'Init',
            proposalId: 0n,
            votingEndingAt: BigInt(Math.floor(Date.now() / 1000)) + 24n * 60n * 60n,
        }),
    );

    // deploy contract
    const deployer = await blockchain.treasury('deployer');
    await proposal.send(
        deployer.getSender(),
        {
            value: toNano('0.01'),
        },
        null, // empty message, handled by `receive()` without parameters
    );

    // vote
    const voter = await blockchain.treasury('voter');
    await proposal.send(
        voter.getSender(),
        { value: toNano('0.1') },
        {
            $$type: 'Vote',
            value: true,
        },
    );

    // the vote was counted
    expect(await proposal.getProposalState()).toMatchObject({ yesCount: 1n, noCount: 0n });
});