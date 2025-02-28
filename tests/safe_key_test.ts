[Previous test content remains, adding new tests:]

Clarinet.test({
    name: "Test key status management and expiration",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('safe-key', 'register-key', [types.uint(100)], wallet1.address),
            Tx.contractCall('safe-key', 'set-key-status', [
                types.uint(1),
                types.bool(false)
            ], wallet1.address)
        ]);
        
        block.receipts[1].result.expectOk().expectBool(true);
        
        // Verify key is inactive
        let keyInfo = chain.callReadOnlyFn(
            'safe-key',
            'get-key-info',
            [types.uint(1)],
            wallet1.address
        );
        
        assertEquals(
            keyInfo.result.expectSome().expectTuple().active,
            false
        );
    }
});
