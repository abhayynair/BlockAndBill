#TrustMeBroLedger

# On-chain Invoice Ledger (Sepolia testnet)

When many invoices and payments exist, can anyone see who owes what, and what is overdue, from one shared record that nobody can quietly edit?

Testnet only. The token has no value and there are no real funds or real users.

## Background

This is the same problem as the invoice reconciliation work I did at ODeX Global in Dubai (about 500 invoices against 252 onboarded companies), done with a shared record: invoice, payment, balance, status.

## What it is

Two small Solidity contracts:

- `TestUSD.sol`: a test token (ERC-20, 6 decimals) with a public faucet.
- `InvoiceLedger.sol`: an issuer raises an invoice against a payer, the payer settles it in full or in parts, and anyone can read each payer's open balance and overdue balance. Every action is logged as an event.

Invoice status is one of: Open, PartiallyPaid, Paid, Cancelled, Overdue. Overdue is worked out from the due date at read time, so it updates by itself.

## Live on Sepolia

Both contracts are deployed on the Sepolia testnet and their source code is verified on Etherscan.

| Contract | Address |
|---|---|
| TestUSD (tUSD) | [0xC8D9957cd0690D5653da9A750B3953c7F4127443](https://sepolia.etherscan.io/address/0xC8D9957cd0690D5653da9A750B3953c7F4127443#code) |
| InvoiceLedger | [0x6d8F5274b50064fEd157585B0D77ed34e5De7252](https://sepolia.etherscan.io/address/0x6d8F5274b50064fEd157585B0D77ed34e5De7252#code) |

Wallets used in the demo:

- Issuer: `0x7f71fc3ccc5fad8d59bb6e395e2d12327917ff59`
- Payer: `0x83Fc74829971c85Ee30BD7f592185368f1e4752D`

## Demo run on Sepolia

1. The payer minted 5,000 tUSD from the faucet and approved the ledger to spend it.
2. The issuer created invoice 0 against the payer: 1,000 tUSD, due 26 October 2026 (unix time 1792972800). [Transaction](https://sepolia.etherscan.io/tx/0x035f7a715157926b3caba4d907b098102e721934b347c06c4d50a3b358e2d77a)
3. The payer paid 400 tUSD towards it. [Transaction](https://sepolia.etherscan.io/tx/0x3c15c13ee27b1eddc69e5f151f7fbba75ae768e86b49f6b452f4f4a57e1d2abd)
4. `openBalance(payer)` returned `600000000`, which is 600 tUSD still owed (1,000 invoiced minus 400 paid).

## Check it yourself

1. Open the [InvoiceLedger contract on Etherscan](https://sepolia.etherscan.io/address/0x6d8F5274b50064fEd157585B0D77ed34e5De7252#readContract) and go to Read Contract.
2. Call `openBalance` with the payer address above. It returns `600000000`.
3. Call `getInvoice` with `0` to see the invoice, how much has been paid, and its status.

## Main functions

| Function | What it does |
|---|---|
| `createInvoice(payer, amount, dueDate)` | Raises an invoice. Amount must be above zero and the due date in the future. |
| `pay(id, amount)` | Only the named payer can pay. Part or full payment, never more than is owed. Needs a prior token approval. |
| `cancel(id)` | Only the issuer can cancel, and only while nothing has been paid. |
| `statusOf(id)` / `getInvoice(id)` | Returns the invoice and its current status. |
| `openBalance(payer)` | Total still owed by a payer across non-cancelled invoices. |
| `overdueBalance(payer)` | The part of that total that is past its due date. |

## Design notes

- The ledger holds no funds. When a payer pays, tokens move straight from the payer to the issuer using the payer's approval, and the ledger records it.
- Events (`InvoiceCreated`, `PaymentMade`, `InvoiceCancelled`) give an auditable history of every action.
- Limits: anyone can raise an invoice against any address, there are no identity checks, and the contracts have not been audited. This is a small demonstration of the record-keeping idea.

## Build settings

Solidity 0.8.34, optimiser on with 200 runs, EVM version paris, MIT licence.

