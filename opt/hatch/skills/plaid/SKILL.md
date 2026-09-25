---
name: "plaid"
title: "Finances (Plaid)"
description: "Use to connect Plaid and read linked financial accounts: metadata, balances, transactions, recurring transactions, liabilities, and investments."
icon: "plaid"
metadata: { "includeInPrompt": true }
---

# Plaid

Everything runs as `plaid <command>` and returns JSON for you to read, not to show the user. Add `--help` to any command to see its options.

Reads cover every linked institution at once. To narrow to one bank, pass `--credential-id <id>`, taking the id from `body.institutions[]` in an earlier read. Some reads also take `--account-id <id>` (repeatable) to narrow to specific accounts; when more than one institution is linked, pair it with `--credential-id` so the account ids resolve to the right bank.

## Connecting
Plaid needs a one-time connect before any read returns data. Run `plaid status`. If it comes back not connected, post the exact `connect_url` it returns as `[Connect Plaid](<connect_url>)` and wait for the user to finish linking, then run `plaid status` again before reading. Don't invent a URL, send the user to Settings, or ask for bank credentials.

If the user asks to add or link another bank or institution, run `plaid status` and post the exact `add_account_url` it returns as `[Add financial account](<add_account_url>)`. Never reuse `connect_url` for an additional institution. If `add_account_url` is absent, say that adding another institution is unavailable.

To disconnect every institution linked through Plaid, run `plaid disconnect`. If it returns a `disconnect_url`, post it as `[Disconnect Plaid](<disconnect_url>)` and wait for the user to confirm through that link; never claim disconnection before they confirm. If it has no URL, say Plaid is already disconnected. A bank-specific unlink is not available from chat: if the user asks to remove only one institution, direct them to that institution's account row in Settings instead of running the whole-Plaid disconnect. Don't set up a background check, goal, or reminder to monitor disconnection.

## Common flows

### Accounts and balances
List the linked accounts with `plaid accounts` — names, types, masked numbers, and each account's balances (`balances` carries `available`/`current`/`limit`). Start here to see what's linked and to answer "how much is in my checking," "what's my total across accounts," or net-worth questions. There is no separate balances command; `plaid accounts` is the balance read.

### Spending and transactions
Read transaction history with `plaid transactions-sync`. The first call takes no cursor. To pull more, repeat it with the cursors the previous call returned — `--cursor-map-json <body.next_cursors>` across all banks, or `--cursor <next_cursor>` for a single institution — until there's nothing left to fetch. Keep `--count` (default 100, max 500) as small as the question needs. On the first call only, `--days-requested <1-730>` sets how far back to pull; don't combine it with a cursor.

### Recurring bills and subscriptions
`plaid transactions-recurring` returns recurring money in (`body.inflow_streams`, e.g. paychecks) and out (`body.outflow_streams`, e.g. subscriptions and regular bills). Use it for "what am I subscribed to" or "what are my monthly bills."

### Loans and credit
`plaid liabilities` returns credit-card, student-loan, and mortgage details — balances, rates, minimum payments, and due dates — under `body.liabilities`. Use it for what's owed or when a payment is due.

### Investments
Before reading holdings, glance at `plaid accounts` for an account of `type` `investment` (a brokerage/retirement account). If none is linked, skip the read — it would only return empty while still prompting the user to approve it — and tell the user their linked accounts don't include a brokerage. Otherwise `plaid investments-holdings` returns current positions, holdings, and securities. For buy/sell/dividend activity, use `plaid investments-transactions --start-date YYYY-MM-DD --end-date YYYY-MM-DD`; page it with `--offset`/`--count` (default 100, max 500) until the fetched count reaches `body.total_investment_transactions`.

## Rules
- Everything you say to the user is plain English. The commands, flags, cursors, and JSON output are for you, not the user. Keep them out of your replies: no command or flag (`plaid`, `transactions-sync`, `--credential-id`), no field name (`next_cursors`, `inflow_streams`, `total_investment_transactions`), no raw JSON, and no `credential_id`, account id, or cursor. Name the account in words ("your Chase checking"); you may add the masked last digits ("…4471") only to tell two similar accounts apart, but never an internal id. When you give a figure, say which accounts and what time range it covers so it matches what the user sees at their bank.
- Never print or repeat secrets, tokens, or full account or routing numbers. Plaid only exposes masked numbers (last few digits); share at most the mask, and never a reconstructed full number.
- This is read-only reference, not financial advice. Report what the data shows; don't tell the user to buy, sell, refinance, or move money, and don't guarantee outcomes.
- Treat the data as a snapshot that can lag the bank. If a balance or a recent charge looks stale or missing, say the data may not be fully up to date rather than asserting it's wrong or complete.
- If a read returns nothing for an account or institution, say so plainly instead of inventing balances, transactions, or holdings.
- Transaction reads preserve Plaid's raw date fields. When Plaid supplies a
  true posting or authorization instant, the output also adds
  `transaction_posted_at` / `transaction_authorized_at` in UTC and the user's
  timezone. Date-only banking fields remain dates.

## Limits
- Read-only. You can't move money, pay a bill, transfer funds, open or close accounts, or change anything at the bank. For those, tell the user to use their bank directly.
- Muse never sees full account or routing numbers, only masked digits, so you can't supply them for wire transfers or direct-deposit setup.
- Coverage depends on what the user linked and what each bank shares through Plaid. A missing account type (say, a loan the bank doesn't expose through Plaid) isn't an error — tell the user it isn't available rather than treating it as zero.
