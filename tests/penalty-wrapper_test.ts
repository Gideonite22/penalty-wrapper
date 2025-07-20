import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.6/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure penalty can be issued successfully",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const block = chain.mineBlock([
            Tx.contractCall('penalty-wrapper', 'issue-penalty', [
                types.ascii('asset123'),
                types.ascii('penalty456'),
                types.uint(10000),
                types.utf8('Compliance violation')
            ], deployer.address)
        ]);
        
        // Assert the transaction was successful
        assertEquals(block.height, 2);
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();
    },
});

Clarinet.test({
    name: "Prevent duplicate penalty issuance",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const block = chain.mineBlock([
            Tx.contractCall('penalty-wrapper', 'issue-penalty', [
                types.ascii('asset123'),
                types.ascii('penalty456'),
                types.uint(10000),
                types.utf8('Compliance violation')
            ], deployer.address),
            Tx.contractCall('penalty-wrapper', 'issue-penalty', [
                types.ascii('asset123'),
                types.ascii('penalty456'),
                types.uint(10000),
                types.utf8('Compliance violation')
            ], deployer.address)
        ]);
        
        // First transaction should succeed, second should fail
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr().expectUint(201);
    },
});

Clarinet.test({
    name: "Resolve penalty successfully",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const block = chain.mineBlock([
            Tx.contractCall('penalty-wrapper', 'issue-penalty', [
                types.ascii('asset123'),
                types.ascii('penalty456'),
                types.uint(10000),
                types.utf8('Compliance violation')
            ], deployer.address),
            Tx.contractCall('penalty-wrapper', 'resolve-penalty', [
                types.ascii('asset123'),
                types.ascii('penalty456'),
                types.ascii('full-payment'),
                types.utf8('Penalty resolved through payment')
            ], deployer.address)
        ]);
        
        // Check that both transactions succeed
        assertEquals(block.receipts.length, 2);
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
    },
});