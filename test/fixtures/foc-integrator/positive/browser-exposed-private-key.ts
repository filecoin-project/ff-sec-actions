// Planted defect: a funded key read from browser-bundled environment variables.
import { Synapse } from '@filoz/synapse-sdk'
import { Wallet } from 'ethers'
import { privateKeyToAccount } from 'viem/accounts'

// ruleid: foc.typescript.browser-exposed-private-key
const account = privateKeyToAccount(process.env.NEXT_PUBLIC_FOC_PRIVATE_KEY as `0x${string}`)
export const synapse = Synapse.create({ account })

// ruleid: foc.typescript.browser-exposed-private-key
export const viteAccount = privateKeyToAccount(import.meta.env.VITE_WALLET_KEY)

// ruleid: foc.typescript.browser-exposed-private-key
export const wallet = new Wallet(process.env.REACT_APP_PRIVATE_KEY as string)

// ruleid: foc.typescript.browser-exposed-private-key
export const legacy = await Synapse.create({ privateKey: process.env['NEXT_PUBLIC_PK'], rpcURL: 'https://example.invalid' })
