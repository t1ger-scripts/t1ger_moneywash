import { useCashCounterStore } from './cash-counter.store'
const messages = {
    common: {
        close: 'Close',
    },
    cashCounter: {
        injectTitle: 'Inject cash',
        withdrawTitle: 'Withdraw cash',
        available: 'Available cash',
        amount: 'Amount to count',
        typeAmount: 'Type amount',
        hideInput: 'Hide field',
        exactAmount: 'Exact amount',
        max: 'Max',
        done: 'Done',
        ready: 'Ready',
        complete: 'Complete',
        counting: 'Counting',
        countingBatch: 'Counting {amount}…',
        confirming: 'Confirming transaction…',
        accepting: 'Loading cash…',
        injected: '{amount} injected into your business.',
        withdrawn: '{amount} withdrawn.',
        empty: 'No cash available.',
        dragHint: 'Drag the cash into the feeder to begin.',
        load: 'Load {amount}',
        release: 'Release to count {amount}',
        waitingToFeed: 'Waiting to feed',
        selectedBatch: 'Selected batch',
        cashInjected: 'BATCH COUNTED',
        awaiting: 'AWAITING CASH',
        batchComplete: 'BATCH COMPLETE',
        autoFeed: 'AUTO FEED',
        dropHere: 'DROP CASH HERE',
        countedCash: 'Counted cash',
        errors: {
            invalid_amount:
                'Choose a whole amount within your available balance.',
            insufficient_dirty_cash:
                'Your available cash has changed. Choose a smaller amount.',
            business_closed: 'This business is closed.',
            not_owner: 'You no longer own this business.',
            too_far: 'Return to your business handler.',
            operation_in_progress: 'Another operation is already in progress.',
            request_failed:
                'Unable to confirm the request. Checking the transaction status…',
            not_ready: 'The cash counter is not ready yet.',
            manual_review:
                'This batch needs administrator review. Your transaction has been recorded.',
            unsupported_operation: 'This cash operation is not available.',
        },
    },
}
export function openCounterDemo(available = 10000000) {
    useCashCounterStore().open({
        businessId: 1,
        operation: 'inject',
        available,
        currency: '$',
        locale: 'en',
        messages,
        titleKey: 'cashCounter.injectTitle',
        successKey: 'cashCounter.injected',
    })
}
