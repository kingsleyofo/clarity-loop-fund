import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create a loan request",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const block = chain.mineBlock([
            Tx.contractCall('loop_fund', 'create-loan-request', [
                types.uint(1000000), // amount: 1 STX
                types.uint(10),      // interest rate: 10%
                types.uint(144)      // term length: ~1 day in blocks
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0); // First loan ID should be 0
    }
});

Clarinet.test({
    name: "Can fund a loan request",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            // Create loan request
            Tx.contractCall('loop_fund', 'create-loan-request', [
                types.uint(1000000),
                types.uint(10),
                types.uint(144)
            ], wallet1.address),
            // Fund the loan
            Tx.contractCall('loop_fund', 'fund-loan', [
                types.uint(0)
            ], wallet2.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0);
        block.receipts[1].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Can repay a loan",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            // Create loan request
            Tx.contractCall('loop_fund', 'create-loan-request', [
                types.uint(1000000),
                types.uint(10),
                types.uint(144)
            ], wallet1.address),
            // Fund the loan
            Tx.contractCall('loop_fund', 'fund-loan', [
                types.uint(0)
            ], wallet2.address),
            // Make repayment
            Tx.contractCall('loop_fund', 'repay-loan', [
                types.uint(0),
                types.uint(1100000) // Repay full amount + 10% interest
            ], wallet1.address)
        ]);
        
        block.receipts.map(receipt => receipt.result.expectOk());
        
        // Verify loan status is now repaid
        const loan = chain.callReadOnlyFn(
            'loop_fund',
            'get-loan',
            [types.uint(0)],
            wallet1.address
        );
        
        assertEquals(loan.result.expectSome().status, types.uint(2)); // LOAN-STATUS-REPAID
    }
});

Clarinet.test({
    name: "Cannot fund already funded loan",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        const wallet3 = accounts.get('wallet_3')!;
        
        let block = chain.mineBlock([
            // Create loan request
            Tx.contractCall('loop_fund', 'create-loan-request', [
                types.uint(1000000),
                types.uint(10),
                types.uint(144)
            ], wallet1.address),
            // First funding
            Tx.contractCall('loop_fund', 'fund-loan', [
                types.uint(0)
            ], wallet2.address),
            // Attempt second funding
            Tx.contractCall('loop_fund', 'fund-loan', [
                types.uint(0)
            ], wallet3.address)
        ]);
        
        block.receipts[2].result.expectErr().expectUint(401); // ERR-ALREADY-FUNDED
    }
});