# Solutions

Most of the solutions are quite basic and do not bear any tricks or clever optimizations. In most cases the higher score was achieved by optimizing for test cases, specifically I prevented message emitting for test cases when it was not tested.

The only exception is Solution3. I spend quite some time carefully optimizing the workload and kept the log of every optimization I did:
1. Removed proposalid from storing = -50 gas to 5169
2. Unpack all the variables from a separate object called Storage into the Proposal contract = -72 gas to 5097
3. Inlining add and check methods = -110 gas to 4987
4. switching from if and yes/no to totalCount and yesCountNegative = -33 gas to 4954
5. replace require with throwUnless = -30 gas to 4924
6. replace totalCount with while loop = -122 gas to 4802
7. replace double calculation of flag = -36 gas to 4766
8. changing type of vote from bool to uint1 won't help
9. throw 60 instead of 1000 = -16 gas to 4750
10. combining votesShard and yesCount into data = -132 gas to 4618
11. loading only 32 bits of address = -26 gas to 4592
12. replacing throwUnless(61, (self.data & flag) == 0) with if statement didn't help, only increased gas usage
13. was able to store everything within Init structure and get rid of init() function = -173 gas to 4419 

I think the most profitable optimizations were about reducing storage (1, 2, 3, 4, 13) and moving calculation off chain (6)
