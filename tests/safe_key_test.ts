Clarinet.test({
    name: "Test enhanced analytics and security features",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Test key registration with analytics
        let block = chain.mineBlock([
            Tx.contractCall('safe-key', 'register-key', 
                [types.uint(100), types.some(wallet2.address)],
                wallet1.address
            )
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        
        // Test key usage and analytics
        block = chain.mineBlock([
            Tx.contractCall('safe-key', 'use-key', 
                [types.uint(1)],
                wallet1.address
            )
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Verify analytics
        let analytics = chain.callReadOnlyFn(
            'safe-key',
            'get-key-analytics',
            [types.uint(1)],
            wallet1.address
        );
        
        analytics.result.expectSome();
    }
});
