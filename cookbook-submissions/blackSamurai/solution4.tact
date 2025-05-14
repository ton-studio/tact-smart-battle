    struct ProposalInit {
        master: Address;
        proposalId: Int as uint32;
    }
     
    message(1) DeployNewProposal {
        votingEndingAt: Int as uint32;
    }
     
    contract ProposalMaster {
        nextProposalId: Int as uint32 = 0;
     
        receive() { 
            if (myBalance() > ton("0.01")) {
                nativeReserve(ton("0.01"), ReserveExact);
                message(MessageParameters{
                    to: sender(),
                    value: 0,
                    mode: SendIgnoreErrors | SendRemainingBalance,
                })
            }
        }
     
        receive(msg: DeployNewProposal) {
            throwIf(400, now() > msg.votingEndingAt);
     
            deploy(DeployParameters{
                mode: SendRemainingValue,
                value: 0,
                body: InternalDeploy{
                    votingEndingAt: msg.votingEndingAt,
                    sender: sender(),
                }.toCell(),
                init: initOf Proposal(ProposalInit{
                    master: myAddress(),
                    proposalId: self.nextProposalId
                })
            });
     
            self.nextProposalId += 1;
        }
     
        get fun nextProposalId(): Int {
            return self.nextProposalId;
        }
    }
     
    // ==============================================================================
     
    message(2) Vote {
        value: Bool;
    }
     
    message(3) InternalDeploy {
        votingEndingAt: Int as uint32;
        sender: Address;
    }
     
    struct ProposalState {
        yesCount: Int as uint32;
        noCount: Int as uint32;
        master: Address;
        proposalId: Int as uint32;
        votingEndingAt: Int as uint32;
    }
     
    contract Proposal {
        master: Address;
        proposalId: Int;
        yes: Int as uint16 = 0;
        votingEndingAt: Int as uint32 = 0;
     
     
        voters: map<Address, Bool> = null;
     
        init(data: ProposalInit) {
            throwIf(2025, sender() != data.master);
            self.master = data.master;
            self.proposalId = data.proposalId;
        }
     
        receive(msg: InternalDeploy) {
            throwIf(2025, sender() != self.master);
            self.votingEndingAt = msg.votingEndingAt;
            cashback(msg.sender);
        }
     
        receive(msg: Vote) {
            throwIf(404, ((self.yes >> 8) + self.yes & ((1 << 8) - 1)) == 100 || now() > self.votingEndingAt || self.voters.exists(sender()));
            self.voters.set(sender(), true);
            self.yes += 1 << ((-8) *  msg.value.asInt());
     
            cashback(sender());
        }
     
        get fun proposalState(): ProposalState {
            return ProposalState {
                yesCount: self.yes >> 8,
                noCount: self.yes & ((1 << 8) - 1),
                master: self.master,
                proposalId: self.proposalId,
                votingEndingAt: self.votingEndingAt,
            };
        }
    }
     
    asm extends fun asInt(self: Bool): Int {}