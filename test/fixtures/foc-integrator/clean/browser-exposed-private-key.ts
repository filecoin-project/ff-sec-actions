// Clean: the key stays in server-only environment variables.
import { Synapse } from '@filoz/synapse-sdk'
import { Wallet } from 'ethers'
import { privateKeyToAccount } from 'viem/accounts'

// ok: foc.typescript.browser-exposed-private-key
const account = privateKeyToAccount(process.env.FOC_PRIVATE_KEY as `0x${string}`)
export const synapse = Synapse.create({ account })

// ok: foc.typescript.browser-exposed-private-key
export const serverAccount = privateKeyToAccount(import.meta.env.WALLET_KEY)

// ok: foc.typescript.browser-exposed-private-key
export const wallet = new Wallet(process.env.SIGNER_PRIVATE_KEY as string)

// A public variable that is not a key is fine.
export const rpc = process.env.NEXT_PUBLIC_RPC_URL
