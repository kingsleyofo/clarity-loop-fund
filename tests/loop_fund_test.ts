import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create a loan request with collateral",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const block = chain.mineBlock([
            Tx.contractCall('loop_fund', 'create-loan-request', [
                types.uint(1000000), // amount: 1 STX
                types.uint(10),      // interest rate: 10%
                types.uint(144),     // term length: ~1 day in blocks
                types.uint(500000)   // collateral: 0.5 STX (50%)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0);
    }
});

Clarinet.test({
    name: "Cannot create loan with insufficient collateral",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const block = chain.mineBlock([
            Tx.contractCall('loop_fund', 'create-loan-request', [
                types.uint(1000000),
                types.uint(10),
                types.uint(144),
                types.uint(100000) // Only 10% collateral
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(406);
    }
});

Clarinet.test({
    name: "Can liquidate defaulted loan",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('loop_fund', 'create-loan-request', [
                types.uint(1000000),
                types.uint(10),
                types.uint(144),
                types.uint(500000)
            ], wallet1.address),
            Tx.contractCall('loop_fund', 'fund-loan', [
                types.uint(0)
            ], wallet2.address)
        ]);
        
        // Advance blockchain beyond term length
        chain.mineEmptyBlockUntil(block.height + 145);
        
        block = chain.mineBlock([
            Tx.contractCall('loop_fund', 'liquidate-defaulted-loan', [
                types.uint(0)
            ], wallet2.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Verify loan status is liquidated
        const loan = chain.callReadOnlyFn(
            'loop_fund',
            'get-loan',
            [types.uint(0)],
            wallet1.address
        );
        
        assertEquals(loan.result.expectSome().status, types.uint(4));
    }
});

Clarinet.test({
    name: "Credit score updates after repayment",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('loop_fund', 'create-loan-request', [
                types.uint(1000000),
                types.uint(10),
                types.uint(144),
                types.uint(500000)
            ], wallet1.address),
            Tx.contractCall('loop_fund', 'fund-loan', [
                types.uint(0)
            ], wallet2.address),
            Tx.contractCall('loop_fund', 'repay-loan', [
                types.uint(0),
                types.uint(1100000)
            ], wallet1.address)
        ]);
        
        // Check updated credit score
        const score = chain.callReadOnlyFn(
            'loop_fund',
            'get-user-credit-score',
            [types.principal(wallet1.address)],
            wallet1.address
        );
        
        assertEquals(score.result.expectSome().score, types.uint(550));
    }
});
