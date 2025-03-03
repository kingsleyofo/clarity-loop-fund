import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';

Clarinet.test({
    name: "Cannot create loan with invalid parameters",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const block = chain.mineBlock([
            Tx.contractCall('loop_fund', 'create-loan-request', [
                types.uint(200000000000), // Exceeds maximum amount
                types.uint(60),           // Exceeds maximum interest rate
                types.uint(144),
                types.uint(100000000000)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(408);
    }
});

Clarinet.test({
    name: "Can create valid loan request with sufficient credit score",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const block = chain.mineBlock([
            Tx.contractCall('loop_fund', 'create-loan-request', [
                types.uint(1000000),     // 1 STX
                types.uint(10),          // 10% interest
                types.uint(144),         // 1 day term
                types.uint(500000)       // 0.5 STX collateral
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
    }
});
