import { bcs, fromHex, toHex } from "@mysten/bcs";
import { Transaction } from "@mysten/sui/transactions";
import { PAYAFRICA_ID, NGNC_TREASURYCAP_ID } from "./smc_address.json";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { fromB64 } from "@mysten/sui/utils";
import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";

export class PayAfrica {
    private client: SuiClient;
    private keypair: Ed25519Keypair;

    constructor (privateKey: string, network: "testnet" | "mainnet" | "devnet") {
        const keypair = Ed25519Keypair.deriveKeypair(privateKey);
        const rpcUrl = getFullnodeUrl(network);
        this.keypair = keypair;
        this.client = new SuiClient({ url: rpcUrl });
    }

    private parseCost(amount: string): number {
        return Math.abs(parseInt(amount, 10)) / 1_000_000_000;
    }

    private async signAndExecuteTransaction(transaction: Transaction): Promise<boolean> {
        try {
            const { objectChanges, balanceChanges } = await this.client.signAndExecuteTransaction({
                signer: this.keypair,
                transaction: transaction,
                options: {
                    showBalanceChanges: true,
                    showEvents: true,
                    showInput: false,
                    showEffects: true,
                    showObjectChanges: true,
                    showRawInput: false,
                }
            });

            // console.log(objectChanges, balanceChanges);

            if (balanceChanges) {
                console.log("Cost to call the function:", this.parseCost(balanceChanges[0].amount), "SUI");
            }

            if (!objectChanges) {
                console.error("Error: RPC did not return objectChanges");
                return false; // Return false in case of an error
            }

            // If everything works fine, return true
            return true;

        } catch (error) {
            console.error("Error executing transaction:", error);
            return false; // Return false in case of an exception
        }
    }

    async mint(amount: string, address: string, decimals: number) {
        const transaction = new Transaction();
        const parsedAmount = parseInt(amount, 10) * 10 ** decimals;
        transaction.moveCall({
            target: `${PAYAFRICA_ID}::ngnc::mint`,
            arguments: [transaction.object(NGNC_TREASURYCAP_ID), transaction.pure.u64(parsedAmount), transaction.pure.address(address)],
        });

        return await this.signAndExecuteTransaction(transaction);
    }
}

const payAfrica = new PayAfrica("fiber surround laugh reopen depth august brown gown glance cave together brass", "devnet");

(async () => {
    const result = await payAfrica.mint("1000", "0xc299192a75ec5296b278953d6efa04f4f6337ad251b744cf437bae03846a1bf1", 6);
    console.log(result);
})();