import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test key registration and ownership",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('safe-key', 'register-key', [], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        
        let keyInfo = chain.callReadOnlyFn(
            'safe-key',
            'get-key-info',
            [types.uint(1)],
            wallet1.address
        );
        
        assertEquals(
            keyInfo.result.expectSome().expectTuple(),
            {
                owner: wallet1.address,
                active: true,
                'last-used': block.height,
                permissions: []
            }
        );
    }
});

Clarinet.test({
    name: "Test key transfer",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('safe-key', 'register-key', [], wallet1.address),
            Tx.contractCall('safe-key', 'transfer-key', [
                types.uint(1),
                types.principal(wallet2.address)
            ], wallet1.address)
        ]);
        
        block.receipts[1].result.expectOk().expectBool(true);
        
        let keyInfo = chain.callReadOnlyFn(
            'safe-key',
            'get-key-info',
            [types.uint(1)],
            wallet1.address
        );
        
        assertEquals(
            keyInfo.result.expectSome().expectTuple().owner,
            wallet2.address
        );
    }
});

Clarinet.test({
    name: "Test permission management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('safe-key', 'register-key', [], wallet1.address),
            Tx.contractCall('safe-key', 'add-permission', [
                types.uint(1),
                types.principal(wallet2.address)
            ], wallet1.address),
            Tx.contractCall('safe-key', 'use-key', [
                types.uint(1)
            ], wallet2.address)
        ]);
        
        block.receipts[1].result.expectOk().expectBool(true);
        block.receipts[2].result.expectOk().expectBool(true);

        // Test permission removal
        block = chain.mineBlock([
            Tx.contractCall('safe-key', 'remove-permission', [
                types.uint(1),
                types.principal(wallet2.address)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk().expectBool(true);

        // Verify wallet2 can no longer use the key
        block = chain.mineBlock([
            Tx.contractCall('safe-key', 'use-key', [
                types.uint(1)
            ], wallet2.address)
        ]);

        block.receipts[0].result.expectErr().expectUint(100);
    }
});
