import '@ton/test-utils';
import { Blockchain, BlockchainTransaction, printTransactionFees, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { toNano, fromNano } from '@ton/core';
import { Proposal } from '../output/solution1_Proposal';
import chalk from 'chalk';

const calculateTotalGasInTON = (transactions: BlockchainTransaction[]) => {
    const individualFees: string[] = [];
    transactions.forEach((tx, index) => {
        if (tx.description && 'computePhase' in tx.description) {
            const gasFees = BigInt(tx.description.computePhase.gasFees || 0);
            const feeInTon = fromNano(gasFees.toString());
            if (index === 1) {
                individualFees.push(chalk.green(feeInTon));
            } else {
                individualFees.push(feeInTon);
            }
        }
    });
    return individualFees.join(', ');
};

describe('Proposal Contract Tests', () => {
    let blockchain: Blockchain;
    let proposal: SandboxContract<Proposal>;
    let deployer: SandboxContract<TreasuryContract>;
    let currentTime: number;
    let votingEndTime: bigint;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        currentTime = Math.floor(Date.now() / 1000);
        votingEndTime = BigInt(currentTime) + 24n * 60n * 60n; // 24 hours from now

        // Create contract from init()
        proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 0n,
                votingEndingAt: votingEndTime,
            }),
        );

        // Deploy contract
        deployer = await blockchain.treasury('deployer');
        await proposal.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null, // empty message, handled by `receive()` without parameters
        );
    });

    it('should deploy successfully', async () => {
        // Check initial state
        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(0n);
        expect(state.noCount).toEqual(0n);
    });

    it('should accept a YES vote and update the state', async () => {
        // Arrange
        const voter = await blockchain.treasury('voter1');

        // Act - cast a YES vote
        const result = await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'Vote',
                value: true,
            },
        );

        printTransactionFees(result.transactions);
        console.log(`Gas fee: ${calculateTotalGasInTON(result.transactions)}`);

        // Check for success transaction
        expect(result.transactions).toHaveTransaction({
            from: voter.address,
            to: proposal.address,
            success: true,
        });

        // Assert
        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(1n);
        expect(state.noCount).toEqual(0n);
    });

    it('should accept a NO vote and update the state', async () => {
        // Arrange
        const voter = await blockchain.treasury('voter2');

        // Act - cast a NO vote
        await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'Vote',
                value: false,
            },
        );

        // Assert
        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(0n);
        expect(state.noCount).toEqual(1n);
    });

    it('should reject duplicate votes from the same address', async () => {
        // Arrange
        const voter = await blockchain.treasury('duplicate_voter');

        // Act & Assert - first vote should succeed
        await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'Vote',
                value: true,
            },
        );

        // Second vote should fail
        const response = await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'Vote',
                value: false,
            },
        );

        // Check for failure transaction
        expect(response.transactions).toHaveTransaction({
            // exitCode: 700, // Exit code for error
            from: voter.address,
            to: proposal.address,
            success: false,
        });

        // Ensure state wasn't changed by the second vote
        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(1n);
        expect(state.noCount).toEqual(0n);
    });

    it('should reject votes after voting period ends', async () => {
        // Create a proposal with voting period already ended
        const pastTime = BigInt(Math.floor(Date.now() / 1000)) - 3600n; // 1 hour in the past

        const expiredProposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 1n,
                votingEndingAt: pastTime,
            }),
        );

        // Deploy the expired proposal contract
        await expiredProposal.send(
            deployer.getSender(),
            { value: toNano('0.01') },
            null
        );

        // Try to vote on the expired proposal
        const lateVoter = await blockchain.treasury('late_voter');
        const response = await expiredProposal.send(
            lateVoter.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'Vote',
                value: true,
            },
        );

        // Check that the vote was rejected
        expect(response.transactions).toHaveTransaction({
            // exitCode: 700, // Generic exit code for error
            from: lateVoter.address,
            to: expiredProposal.address,
            success: false,
        });

        // Ensure no votes were counted
        const state = await expiredProposal.getProposalState();
        expect(state.yesCount).toEqual(0n);
        expect(state.noCount).toEqual(0n);
    });

    // Test for maximum vote limit
    it('should reject more than 100 votes', async () => {
        // Send 100 votes
        for (let i = 0; i < 100; i++) {
            const voter = await blockchain.treasury(`voter${i}`);
            await proposal.send(
                voter.getSender(),
                { value: toNano('0.1') },
                { $$type: 'Vote', value: true }
            );
        }

        // Try 101st vote
        const extraVoter = await blockchain.treasury('extraVoter');
        const result = await proposal.send(
            extraVoter.getSender(),
            { value: toNano('0.1') },
            { $$type: 'Vote', value: true }
        );

        expect(result.transactions).toHaveTransaction({
            // exitCode: 700,
            from: extraVoter.address,
            to: proposal.address,
            success: false,
        });
    });

    it('should return excess funds to the voter', async () => {
        // Arrange
        const voter = await blockchain.treasury('refund_voter');
        const initialBalance = await voter.getBalance();
        const sentAmount = toNano('0.5');  // Send much more than needed

        // Act
        await proposal.send(
            voter.getSender(),
            { value: sentAmount },
            {
                $$type: 'Vote',
                value: true,
            },
        );

        // Assert
        const finalBalance = await voter.getBalance();
        // We can't precisely check the exact amount, but the voter should have
        // received most of their funds back
        expect(finalBalance).toBeGreaterThan(initialBalance - sentAmount + toNano('0.4'));
    });

    it('should count multiple votes from different addresses correctly', async () => {
        // Cast 3 YES votes and 2 NO votes
        for (let i = 0; i < 3; i++) {
            const yesVoter = await blockchain.treasury(`yes_voter_${i}`);
            await proposal.send(
                yesVoter.getSender(),
                { value: toNano('0.1') },
                {
                    $$type: 'Vote',
                    value: true,
                },
            );
        }

        for (let i = 0; i < 2; i++) {
            const noVoter = await blockchain.treasury(`no_voter_${i}`);
            await proposal.send(
                noVoter.getSender(),
                { value: toNano('0.1') },
                {
                    $$type: 'Vote',
                    value: false,
                },
            );
        }

        // Verify the final counts
        const state = await proposal.getProposalState();
        expect(state.yesCount).toEqual(3n);
        expect(state.noCount).toEqual(2n);
    });
});