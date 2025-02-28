// [Previous test content remains unchanged]

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

// [Add more test cases for new functionality]
