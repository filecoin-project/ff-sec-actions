// Clean: bounded allowances sized to the application.
import { Synapse } from '@filoz/synapse-sdk'

declare const synapse: Synapse
const ratePerEpoch = 10n ** 12n
const lockup = ratePerEpoch * 2880n * 30n

// ok: foc.typescript.unlimited-operator-allowance
await synapse.payments.approveService({ rateAllowance: ratePerEpoch, lockupAllowance: lockup })

// ok: foc.typescript.unlimited-operator-allowance
await synapse.payments.depositWithPermitAndApproveOperator({ amount: lockup, rateAllowance: ratePerEpoch, lockupAllowance: lockup })
