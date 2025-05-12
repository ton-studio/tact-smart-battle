import '@ton/test-utils';
import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { Address, Cell, toNano, beginCell } from '@ton/core';
import { Proposal } from '../output/solution3_Proposal';

describe('Proposal Contract Tests', () => {
    let blockchain: Blockchain;
    let proposal: SandboxContract<Proposal>;
    let deployer: SandboxContract<TreasuryContract>;
    let votingEndTime: bigint;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        // Set voting end time to 24 hours from now
        votingEndTime = BigInt(Math.floor(Date.now() / 1000)) + 24n * 60n * 60n;

        // Create contract from init()
        proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 123n,
                votingEndingAt: votingEndTime,
            }),
        );

        // Deploy contract
        deployer = await blockchain.treasury('deployer');
        await proposal.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            null // empty message, handled by `receive()` without parameters
        );
    });

    it('should initialize with zero votes', async () => {
        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(0n);
        expect(state.noCount).toEqual(0n);
    });

    it('should count a yes vote correctly', async () => {
        const voter = await blockchain.treasury('voter1');

        await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: true }
        );

        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(1n);
        expect(state.noCount).toEqual(0n);
    });

    it('should count a no vote correctly', async () => {
        const voter = await blockchain.treasury('voter2');

        await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: false }
        );

        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(0n);
        expect(state.noCount).toEqual(1n);
    });

    it('should count multiple votes from different voters', async () => {
        const voter1 = await blockchain.treasury('voter3');
        const voter2 = await blockchain.treasury('voter4');
        const voter3 = await blockchain.treasury('voter5');

        // Three yes votes
        await proposal.send(
            voter1.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: true }
        );

        await proposal.send(
            voter2.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: true }
        );

        await proposal.send(
            voter3.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: true }
        );

        let state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(3n);
        expect(state.noCount).toEqual(0n);

        // Two no votes from different voters
        const voter4 = await blockchain.treasury('voter6');
        const voter5 = await blockchain.treasury('voter7');

        await proposal.send(
            voter4.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: false }
        );

        await proposal.send(
            voter5.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: false }
        );

        state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(3n);
        expect(state.noCount).toEqual(2n);
    });

    it('should reject duplicate votes from the same address', async () => {
        const voter = await blockchain.treasury('voter8');

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

        expect(result.transactions).toHaveTransaction({
            // exitCode: 59656, // Updated exit code for "You have already voted"
            from: voter.address,
            to: proposal.address,
            success: false,
        });

        // Counts should remain unchanged after the failed vote
        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(1n);
        expect(state.noCount).toEqual(0n);
    });

    it('should reject votes after the deadline', async () => {
        // Set up a proposal with a deadline in the past
        const expiredProposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 456n,
                votingEndingAt: BigInt(Math.floor(Date.now() / 1000)) - 60n, // 1 minute ago
            }),
        );

        // Deploy the expired proposal
        await expiredProposal.send(
            deployer.getSender(),
            { value: toNano('0.05') },
            null
        );

        // Try to vote on the expired proposal
        const voter = await blockchain.treasury('voter9');
        const result = await expiredProposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: true }
        );

        // Voting should fail with the appropriate exit code
        expect(result.transactions).toHaveTransaction({
            // exitCode: 59195, // Updated exit code for "Voting has ended"
            from: voter.address,
            to: expiredProposal.address,
            success: false,
        });

        // Verify that no votes were counted
        const state = await expiredProposal.getProposalState();
        expect(state.yesCount).toEqual(0n);
        expect(state.noCount).toEqual(0n);
    });

    it('should handle mixed yes and no votes', async () => {
        // Create 10 voters with alternating yes/no votes
        for (let i = 0; i < 10; i++) {
            const voter = await blockchain.treasury(`mixed_voter_${i}`);
            const voteValue = i % 2 === 0; // Even indexes vote yes, odd indexes vote no

            await proposal.send(
                voter.getSender(),
                { value: toNano('0.1') },
                { $$type: 'Vote', value: voteValue }
            );
        }

        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(5n); // 5 yes votes (even indexes)
        expect(state.noCount).toEqual(5n);  // 5 no votes (odd indexes)
    });

    it('should support different proposal IDs', async () => {
        // Create another proposal with a different ID
        const anotherProposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 789n,
                votingEndingAt: votingEndTime,
            }),
        );

        // Deploy the second proposal
        await anotherProposal.send(
            deployer.getSender(),
            { value: toNano('0.05') },
            null
        );

        // Vote on both proposals
        const voter1 = await blockchain.treasury('voter_multi_1');
        const voter2 = await blockchain.treasury('voter_multi_2');

        // Vote on the first proposal
        await proposal.send(
            voter1.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: true }
        );

        // Vote on the second proposal
        await anotherProposal.send(
            voter1.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: false }
        );

        // Same voter can vote on both proposals because they're separate
        const state1 = await proposal.getProposalState();
        const state2 = await anotherProposal.getProposalState();

        expect(state1.yesCount).toEqual(1n);
        expect(state1.noCount).toEqual(0n);

        expect(state2.yesCount).toEqual(0n);
        expect(state2.noCount).toEqual(1n);
    });

    it('should work with minimum gas', async () => {
        // Test with minimal gas amount
        const voter = await blockchain.treasury('low_gas_voter');

        // Try with just 0.05 TON
        await proposal.send(
            voter.getSender(),
            { value: toNano('0.05') },
            { $$type: 'Vote', value: true }
        );

        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(1n);
    });

    // Test for scalability (simplified simulation)
    it('should handle many different voters', async () => {
        // Create a reasonable number of voters for testing
        // (We can't test billions, but we can test the mechanism)
        const voterCount = 50;

        for (let i = 0; i < voterCount; i++) {
            const voter = await blockchain.treasury(`scale_voter_${i}`);
            const voteValue = i % 3 === 0; // 1/3 yes votes, 2/3 no votes

            await proposal.send(
                voter.getSender(),
                { value: toNano('0.1') },
                { $$type: 'Vote', value: voteValue }
            );
        }

        const state = await proposal.getProposalState();
        // Every third voter (i % 3 === 0) votes yes
        expect(state.yesCount).toEqual(BigInt(Math.floor(voterCount / 3) + (voterCount % 3 > 0 ? 1 : 0)));
        // The rest vote no
        expect(state.noCount).toEqual(BigInt(voterCount - Number(state.yesCount)));
    });

    it('should have storage size under 100,000 bits for 4 billion votes', async () => {
        // First measure the base contract storage (without any votes)
        const emptyContractState = await blockchain.getContract(proposal.address);
        const baseStorage = Number(emptyContractState.account.account.storageStats.used.bits);

        // Add sufficient sample votes to get accurate storage metrics
        const sampleSize = 1000; // Use 1000 votes as sample size

        for (let i = 0; i < sampleSize; i++) {
            const voter = await blockchain.treasury(`voter${i}`);
            await proposal.send(
                voter.getSender(),
                { value: toNano('0.1') },
                { $$type: 'Vote', value: i % 2 === 0 }
            );
        }

        // Get the contract state and storage stats after adding votes
        const contractState = await blockchain.getContract(proposal.address);
        const storageStats = contractState.account.account.storageStats.used;
        const storageBits = Number(storageStats.bits);

        // Calculate storage metrics - accounting for actual base storage
        const votesStorageBits = storageBits - baseStorage;
        const bitsPerVoter = votesStorageBits / sampleSize;
        const targetVoters = 4_000_000_000; // 4 billion voters 
        const projectedBits = baseStorage + (bitsPerVoter * targetVoters);

        // Calculate available storage after considering actual base contract storage
        const totalAvailableStorage = 100_000; // Total allowed storage
        const availableStorage = totalAvailableStorage - baseStorage;
        const maxAllowedBitsPerVoter = availableStorage / targetVoters;

        // Log storage metrics
        const metrics = [
            `Storage metrics:`,
            `  - Base storage measured: ${baseStorage.toLocaleString()} bits`,
            `  - Available storage for votes: ${availableStorage.toLocaleString()} bits`,
            `  - Current total storage: ${storageBits.toLocaleString()} bits in ${storageStats.cells.toLocaleString()} cells for ${sampleSize.toLocaleString()} votes`,
            `  - Storage used by votes only: ${votesStorageBits.toFixed(8).toLocaleString()} bits`,
            `  - Bits per voter: ${bitsPerVoter.toFixed(30).toLocaleString()}`,
            `  - Maximum allowed bits per voter: ${maxAllowedBitsPerVoter.toFixed(8).toLocaleString()}`,
            `  - Projected storage for ${targetVoters.toLocaleString()} votes: ${projectedBits.toLocaleString()} bits`
        ];
        console.log(metrics.join('\n'));

        // Verify storage efficiency
        expect(bitsPerVoter).toBeLessThanOrEqual(maxAllowedBitsPerVoter);
    });

});