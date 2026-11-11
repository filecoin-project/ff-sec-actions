// Planted defect: unlimited Filecoin Pay operator allowances.
import { Synapse } from '@filoz/synapse-sdk'
import { MaxUint256 } from 'ethers'
import { maxUint256 } from 'viem'

declare const synapse: Synapse

// ruleid: foc.typescript.unlimited-operator-allowance
await synapse.payments.approveService({ rateAllowance: maxUint256, lockupAllowance: 10n ** 18n })

// ruleid: foc.typescript.unlimited-operator-allowance
await synapse.payments.approveService({ rateAllowance: 10n ** 12n, lockupAllowance: MaxUint256 })

// ruleid: foc.typescript.unlimited-operator-allowance
await synapse.payments.depositWithPermitAndApproveOperator({ amount: 10n ** 18n, lockupAllowance: 2n ** 256n - 1n })
