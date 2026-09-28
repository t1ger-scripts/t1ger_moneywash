# Cash counter integration

## Included

- The approved compact cash-counter screen, implemented as Vue components in `source/src/features/cash-counter/`.
- Slider, optional exact amount field, Max, representative cash stacks, one-drag loading, automatic feeding, and completion.
- Shared `App.vue` screen selection. The marketplace keeps its existing window in `MarketplaceScreen.vue`.
- Shared client NUI focus/readiness, shared Vue Escape handling, and separate feature messages.
- Launder Money now opens the counter. The server reserves dirty cash at acceptance and finalizes after its own 3–6 second timer.
- Closing the UI or disconnecting does not cancel an accepted reservation. Reopening resumes a pending batch.
- The existing business calculations still determine covered/exposed proceeds, stock consumption and suspicion. They are not displayed by the counter.
- The prior instant laundering callback rejects requests, so it cannot bypass the counter.

The cash-counter presentation accepts operation labels, available cash and results. This version wires `inject` only. Safe-to-inventory withdrawal is a future adapter: the supplied resource currently has a separate bank-transfer mission, not a cash withdrawal implementation. That bank-deposit flow is not replaced here.

## Install / merge

1. Back up your current resource and database.
2. Merge these files into your existing `t1ger_moneywash` resource. The archive includes the updated `source/` and compiled `web/`.
3. KEEP your existing `web/images/` and `web/mapStyles/` directories. Neither uploaded archive contained these photos/map tiles, so they are not included here. Do not replace the entire resource directory with this package unless you restore those assets too.
4. The resource creates `moneywash_cash_batches` on startup. If your DB account cannot create tables, run `install/cash_counter.sql` yourself before restarting. Existing business and new journal tables must use a transactional storage engine (InnoDB).
5. Restart the resource. Open your handler menu and choose Launder Money.

New configuration is `Config.CashCounter` in `shared/config.lua`: minimum/maximum duration, maximum accepted transaction amount, and server-side interaction distance. Available money is always read from the configured inventory/account. The browser demo's $10 million is never supplied in FiveM.

The frontend build now keeps existing output files (`emptyOutDir: false`) so rebuilding does not erase server-supplied business images or map tiles. Hashed assets from earlier builds may remain; remove obsolete hashed files only when you know they are no longer referenced.

## Browser development

From `source/`:

```sh
npm ci
npm run dev
```

Open `http://localhost:5173/?screen=cash-counter` to use the development-only demo. Try $15,000, $1,000,000 and $10,000,000. The UI is otherwise hidden until FiveM sends an open message. Use `npm run build` for a type-checked production build into `web/`.

## Architecture / future screens

`App.vue` displays the active feature from `stores/ui.store.ts`. `useUiLifecycle.ts` coordinates readiness, incoming cash-counter messages and Escape. `usePortalLifecycle.ts` handles marketplace data and messages; refreshing marketplace data no longer opens it. `portal.store.ts` is a compatibility facade over the shared active screen.

Each feature owns its own shell. Add future review-books screens to `features/`, add their screen name to `UiScreen`, and register their own lifecycle/messages. Shared Lua focus functions are in `client/ui.lua`.

`exports['t1ger_moneywash']:OpenCashCounter(businessId, 'inject')` opens the current adapter. Add future operations on the server, with their own validation/reservation/settlement behavior; do not accept a client-specified money destination or arbitrary callback.

## Money and persistence behavior

The server validates ownership, distance, the amount and the current dirty-cash balance. A preparation record is written before attempting the debit, and the existing money abstraction now verifies that the balance actually decreased. Confirmed reservations are journaled. No NUI completion event can credit money or accelerate counting.

At completion, the existing business formulas are applied once to the cache. A SQL transaction persists the business and marks the journal complete together. Autosave is blocked for that business during settlement; retrying a failed SQL write does not apply the credit again. Ownership changes/removal are locked while a reservation exists. Raids and safe-deposit/review requests defer or reject while a batch is pending.

Accepted `reserved` batches recover on resource startup and finish without another debit. `complete` batches are never replayed. Completed/cancelled journal records are retained for audit; retention can be added later.

An external framework inventory/account debit and this resource's SQL journal are not one atomic transaction. A hard interruption in the debit boundary can leave a `prepared` record. The resource deliberately does not guess whether the money was removed: it blocks that business's ownership changes and logs the batch ID for review. Full-server crash durability also depends on the framework's player-data persistence. Reputation and dispatch side effects are not a durable outbox; a crash after settlement can omit them, but must not trigger a second safe credit.

To reconcile a logged `prepared` batch: stop the resource, inspect the journal and framework/inventory audit data, then set that specific row to `reserved` only if the debit definitely happened and the batch has not been credited. Set it to `cancelled` only if the debit did not happen (or has been explicitly refunded). Restart to reload reservations. Never blanket-delete pending records or mark an ambiguous record reserved without checking its debit.

## Validation performed

- Vue/TypeScript type check and Vite production build.
- Browser checks of the actual Vue screen: amount slider, exact field, 1/12-stack representation, drag-to-load, counting, completion, close, and mobile rendering; no JavaScript runtime errors.
- Production Lua syntax checks.
- `tests/cash_counter_test.py` executes the production transaction module with mocked FiveM and SQL boundaries: validation, duplicate requests, server timer, disconnect/source reuse, failed SQL retry, autosave barrier, revalidation after an async operation, ambiguous debits, restart recovery, completed-batch replay prevention, original covered/exposed calculation, and old instant-callback rejection.

The automated Lua harness requires Python with `lupa`: `python3 tests/cash_counter_test.py`.

No live FiveM server or real framework/inventory/MySQL instance was available here. In-game acceptance checks are still required: focus/Escape, portal purchase-modal Escape, two clients, real item/account debit behavior, close/reopen during counting, disconnect, and resource restart with a pending batch.

The supplied manifest did not load `client/business/missions.lua`. This implementation fixes the laundering path independently. Existing unrelated deposit/review mission entry points remain as supplied; enabling/refactoring them is separate work.
