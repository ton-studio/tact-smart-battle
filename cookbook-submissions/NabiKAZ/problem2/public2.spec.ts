import '@ton/test-utils';
import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { toNano } from '@ton/core';
import { Proposal } from '../output/solution2_Proposal';
import { ProposalMaster } from '../output/solution2_ProposalMaster';

describe('Proposal Contract Tests', () => {
    let blockchain: Blockchain;
    let proposalMaster: SandboxContract<ProposalMaster>;
    let masterDeployer: SandboxContract<TreasuryContract>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        proposalMaster = blockchain.openContract(await ProposalMaster.fromInit());
        masterDeployer = await blockchain.treasury('deployer');
        await proposalMaster.send(
            masterDeployer.getSender(),
            { value: toNano('0.01') },
            null
        );
    });

    it('should deploy proposal and accept valid vote', async () => {
        const currentTime = BigInt(Math.floor(Date.now() / 1000));

        await proposalMaster.send(
            masterDeployer.getSender(),
            {
                value: toNano('0.1'),
                bounce: false,
            },
            {
                $$type: 'DeployNewProposal',
                votingEndingAt: currentTime + 24n * 60n * 60n,
            },
        );

        const voter = await blockchain.treasury('voter');
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'ProposalInit',
                master: proposalMaster.address,
                proposalId: 0n,
            }),
        );

        await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: true },
        );

        expect(await proposal.getProposalState()).toMatchObject({ yesCount: 1n, noCount: 0n });
    });

    it('should reject deployment from non-master', async () => {
        const unauthorizedUser = await blockchain.treasury('unauthorized');
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'ProposalInit',
                master: proposalMaster.address,
                proposalId: 0n,
            }),
        );

        const deployResult = await proposal.send(
            unauthorizedUser.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'DeployNewProposal',
                votingEndingAt: BigInt(Math.floor(Date.now() / 1000)) + 24n * 60n * 60n,
            }
        );

        expect(deployResult.transactions).toHaveTransaction({
            exitCode: 2025,
        });
    });

    it('should reject votes after deadline', async () => {
        const startTime = Math.floor(Date.now() / 1000);
        blockchain.now = startTime;

        await proposalMaster.send(
            masterDeployer.getSender(),
            { value: toNano('0.1') },
            { $$type: 'DeployNewProposal', votingEndingAt: BigInt(startTime + 1) }
        );

        const voter = await blockchain.treasury('voter');
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'ProposalInit',
                master: proposalMaster.address,
                proposalId: 0n,
            }),
        );

        blockchain.now = startTime + 2;

        const result = await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: true },
        );

        expect(result.transactions).toHaveTransaction({
            // exitCode: 59195,
            success: false,
        });
    });

    it('should reject more than 100 votes', async () => {
        const currentTime = BigInt(Math.floor(Date.now() / 1000));
        await proposalMaster.send(
            masterDeployer.getSender(),
            { value: toNano('0.1') },
            { $$type: 'DeployNewProposal', votingEndingAt: currentTime + 3600n }
        );

        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'ProposalInit',
                master: proposalMaster.address,
                proposalId: 0n,
            }),
        );

        for (let i = 0; i < 100; i++) {
            const voter = await blockchain.treasury(`voter${i}`);
            await proposal.send(
                voter.getSender(),
                { value: toNano('0.1') },
                { $$type: 'Vote', value: true },
            );
        }

        const extraVoter = await blockchain.treasury('extraVoter');
        const result = await proposal.send(
            extraVoter.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: true },
        );

        expect(result.transactions).toHaveTransaction({
            // exitCode: 26102,
            success: false,
        });
    });

    // ** THIS IS NOT COMPLETE AND NEEDS TO BE REVIEWED: **
    // it('should return excess funds to voter', async () => {
    //     const currentTime = BigInt(Math.floor(Date.now() / 1000));
    //     await proposalMaster.send(
    //         masterDeployer.getSender(),
    //         { value: toNano('0.1') },
    //         { $$type: 'DeployNewProposal', votingEndingAt: currentTime + 3600n }
    //     );

    //     const voter = await blockchain.treasury('voter');
    //     const initialBalance = await voter.getBalance();

    //     const proposal = blockchain.openContract(
    //         await Proposal.fromInit({
    //             $$type: 'ProposalInit',
    //             master: proposalMaster.address,
    //             proposalId: 0n,
    //         }),
    //     );

    //     await proposal.send(
    //         voter.getSender(),
    //         { value: toNano('0.5') },
    //         { $$type: 'Vote', value: true },
    //     );

    //     const finalBalance = await voter.getBalance();
    //     expect(finalBalance).toBeGreaterThan(initialBalance - toNano('0.1'));
    // });

    it('should count votes correctly', async () => {
        const currentTime = BigInt(Math.floor(Date.now() / 1000));
        await proposalMaster.send(
            masterDeployer.getSender(),
            { value: toNano('0.1') },
            { $$type: 'DeployNewProposal', votingEndingAt: currentTime + 3600n }
        );

        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'ProposalInit',
                master: proposalMaster.address,
                proposalId: 0n,
            }),
        );

        const voter1 = await blockchain.treasury('voter1');
        const voter2 = await blockchain.treasury('voter2');

        await proposal.send(voter1.getSender(), { value: toNano('0.1') }, { $$type: 'Vote', value: true });
        await proposal.send(voter2.getSender(), { value: toNano('0.1') }, { $$type: 'Vote', value: false });

        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(1n);
        expect(state.noCount).toEqual(1n);
    });

    it('should reject proposal deployment if deadline is in the past', async () => {
        const currentTime = Math.floor(Date.now() / 1000);
        blockchain.now = currentTime;

        const resultPast = await proposalMaster.send(
            masterDeployer.getSender(),
            { value: toNano('0.1') },
            { $$type: 'DeployNewProposal', votingEndingAt: BigInt(currentTime - 1) },
        );

        expect(resultPast.transactions).toHaveTransaction({
            // exitCode: 2874,
            success: false,
        });
    });

    // Test for multiple deployed proposals
    it('should handle multiple proposals correctly', async () => {
        // Deploy master contract
        await proposalMaster.send(masterDeployer.getSender(), { value: toNano('0.01') }, null);

        const currentTime = BigInt(Math.floor(Date.now() / 1000));

        // Deploy first proposal
        await proposalMaster.send(
            masterDeployer.getSender(),
            { value: toNano('0.1') },
            { $$type: 'DeployNewProposal', votingEndingAt: currentTime + 3600n }
        );

        // Check that nextProposalId incremented
        expect(await proposalMaster.getNextProposalId()).toEqual(1n);

        // Deploy second proposal
        await proposalMaster.send(
            masterDeployer.getSender(),
            { value: toNano('0.1') },
            { $$type: 'DeployNewProposal', votingEndingAt: currentTime + 7200n }
        );

        // Check that nextProposalId incremented again
        expect(await proposalMaster.getNextProposalId()).toEqual(2n);

        // Open both proposal contracts
        const proposal1 = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'ProposalInit',
                master: proposalMaster.address,
                proposalId: 0n
            })
        );

        const proposal2 = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'ProposalInit',
                master: proposalMaster.address,
                proposalId: 1n
            })
        );

        // Vote on both proposals
        const voter1 = await blockchain.treasury('voter1');
        const voter2 = await blockchain.treasury('voter2');

        // Vote on first proposal
        await proposal1.send(voter1.getSender(), { value: toNano('0.1') }, { $$type: 'Vote', value: true });
        await proposal1.send(voter2.getSender(), { value: toNano('0.1') }, { $$type: 'Vote', value: false });

        // Vote on second proposal
        await proposal2.send(voter1.getSender(), { value: toNano('0.1') }, { $$type: 'Vote', value: false });
        await proposal2.send(voter2.getSender(), { value: toNano('0.1') }, { $$type: 'Vote', value: true });

        // Check states of both proposals
        const state1 = await proposal1.getProposalState();
        const state2 = await proposal2.getProposalState();

        // Verify first proposal state
        expect(state1.yesCount).toEqual(1n);
        expect(state1.noCount).toEqual(1n);
        expect(state1.proposalId).toEqual(0n);

        // Verify second proposal state
        expect(state2.yesCount).toEqual(1n);
        expect(state2.noCount).toEqual(1n);
        expect(state2.proposalId).toEqual(1n);

        // Verify different voting ending times
        expect(state1.votingEndingAt).not.toEqual(state2.votingEndingAt);

        // Verify same master address using string representation
        expect(state1.master.toString()).toEqual(state2.master.toString());
    });

    // Test for voter trying to vote twice
    it('should reject when voter tries to vote twice', async () => {
        // Deploy master contract
        await proposalMaster.send(masterDeployer.getSender(), { value: toNano('0.01') }, null);

        const currentTime = BigInt(Math.floor(Date.now() / 1000));

        // Deploy proposal
        await proposalMaster.send(
            masterDeployer.getSender(),
            { value: toNano('0.1') },
            { $$type: 'DeployNewProposal', votingEndingAt: currentTime + 3600n }
        );

        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'ProposalInit',
                master: proposalMaster.address,
                proposalId: 0n
            })
        );

        const voter = await blockchain.treasury('voter');

        // First vote should succeed
        await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: true }
        );

        // Second vote should fail
        const result = await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: false }
        );

        // Check for failure due to "Already voted" condition
        expect(result.transactions).toHaveTransaction({
            // exitCode: 59369, // Exit code for require("Already voted")
            aborted: true,
            success: false,
        });

        // Verify vote count didn't change
        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(1n);
        expect(state.noCount).toEqual(0n);
    });

    it('should handle multiple proposals correctly', async () => {
        // Current time plus one hour
        const votingEndTime = Math.floor(Date.now() / 1000) + 3600;

        // Deploy a proposal from the master contract
        const deployResult = await proposalMaster.send(
            masterDeployer.getSender(),
            { value: toNano('0.5') },
            { $$type: 'DeployNewProposal', votingEndingAt: BigInt(votingEndTime) }
        );

        // Verify deployment succeeded
        expect(deployResult.transactions).toHaveLength(3); // Deploy tx + new contract init + state change tx

        // Check if the second transaction is successful (based on available data)
        const secondTransaction = deployResult.transactions[1];
        expect(secondTransaction.outMessagesCount).toBeGreaterThan(0); // Ensure there is at least one outgoing message

        // Get the proposal ID
        const proposalId = await proposalMaster.getNextProposalId();
        expect(proposalId).toBe(1n); // After first deployment, should be 1

        // Deploy another proposal from the master contract
        const deployResult2 = await proposalMaster.send(
            masterDeployer.getSender(),
            { value: toNano('0.5') },
            { $$type: 'DeployNewProposal', votingEndingAt: BigInt(votingEndTime + 3600) }
        );

        // Verify deployment succeeded
        expect(deployResult2.transactions).toHaveLength(3); // Deploy tx + new contract init + state change tx

        // Check if the second transaction is successful (based on available data)
        const secondTransaction2 = deployResult2.transactions[1];
        expect(secondTransaction2.outMessagesCount).toBeGreaterThan(0); // Ensure there is at least one outgoing message

        // Get the second proposal ID
        const proposalId2 = await proposalMaster.getNextProposalId();
        expect(proposalId2).toBe(2n); // After second deployment, should be 2
    });

    it('should successfully deploy a proposal from master contract', async () => {
        // Current time plus one hour
        const votingEndTime = Math.floor(Date.now() / 1000) + 3600;

        // Deploy a proposal from the master contract
        const deployResult = await proposalMaster.send(
            masterDeployer.getSender(),
            { value: toNano('0.5') },
            { $$type: 'DeployNewProposal', votingEndingAt: BigInt(votingEndTime) }
        );

        // Verify deployment succeeded
        expect(deployResult.transactions).toHaveLength(3); // Deploy tx + new contract init + state change tx

        // Check if the second transaction is successful (based on available data)
        const secondTransaction = deployResult.transactions[1];
        expect(secondTransaction.outMessagesCount).toBeGreaterThan(0); // Ensure there is at least one outgoing message

        // Get the proposal ID
        const proposalId = await proposalMaster.getNextProposalId();
        expect(proposalId).toBe(1n); // After first deployment, should be 1
    });

    // ** THIS IS NOT COMPLETE AND NEEDS TO BE REVIEWED: **
    // it('should fail with exit code 2025 when not deployed by master', async () => {
    //     const imposter = await blockchain.treasury('imposter');

    //     // // Calculate what would be the proposal address
    //     // const proposalId = await proposalMaster.getNextProposalId();

    //     // Try to directly deploy a proposal from imposter account
    //     const proposalInit = {
    //         $$type: 'ProposalInit',
    //         master: proposalMaster.address,
    //         proposalId: 0n,
    //     };

    //     // // Craft the proposal initialization data
    //     // const proposalAddress = Proposal.calculateAddress(proposalInit);



    //     // Get proposal address
    //     // const proposalId = await proposalMaster.getNextProposalId() - 1n; // Last deployed proposal ID
    //     const proposalContract = blockchain.openContract(
    //         await Proposal.fromInit({
    //             $$type: 'ProposalInit',
    //             master: proposalMaster.address,
    //             proposalId: 0n,
    //         }),
    //     );
    //     const proposalAddress = proposalContract.address;
    //     console.log(proposalContract.init);

    //     // Get the contract's state init (code + data)
    //     const stateInit = await proposalContract.getStateInit();
    //     // console.log(">>>", stateInit.getInit());

    //     // Try to deploy directly from imposter
    //     const result = await imposter.send({
    //         to: proposalAddress,
    //         value: toNano('0.5'),
    //         // Use the deploy flag instead of explicit init
    //         bounce: false,
    //         deploy: true,
    //         init2ss: proposalContract.init,
    //     });

    //     // Check that deployment failed with exit code 2025
    //     expect(result.transactions).toHaveTransaction({
    //         to: proposalAddress,
    //         exitCode: 2025
    //     });
    // });

    it('should reject messages from non-master accounts after deployment', async () => {
        const imposter = await blockchain.treasury('imposter');

        // Deploy a legitimate proposal first
        const votingEndTime = Math.floor(Date.now() / 1000) + 3600;
        await proposalMaster.send(
            masterDeployer.getSender(),
            { value: toNano('0.5') },
            { $$type: 'DeployNewProposal', votingEndingAt: BigInt(votingEndTime) }
        );

        // Get proposal address
        const proposalId = await proposalMaster.getNextProposalId() - 1n; // Last deployed proposal ID
        const proposalContract = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'ProposalInit',
                master: proposalMaster.address,
                proposalId: proposalId,
            }),
        );
        const proposalAddress = proposalContract.address;

        // Try to send DeployNewProposal from imposter
        const result = await proposalContract.send(
            imposter.getSender(),
            { value: toNano('0.1') },
            { $$type: 'DeployNewProposal', votingEndingAt: BigInt(votingEndTime + 1000) }
        );

        // Check that message was rejected with exit code 2025
        expect(result.transactions).toHaveTransaction({
            from: imposter.address,
            to: proposalAddress,
            exitCode: 2025
        });
    });

});
