# User story: migrate the legacy estate to the target state

## Story

**As** the Harbour Point Bank integration team,
**I want** the three IIB SOAP services (Customer, Account, Payment) re-built as .NET 10 REST APIs using CQRS,
**so that** we can retire IIB and SOAP without changing any business answer our consumers rely on.

## Scope

| Legacy (this repo) | Target |
| --- | --- |
| `GetCustomerProfile` | `GET /v1/customers/{customerId}` (query) |
| `UpdateContactDetails` | `PATCH /v1/customers/{customerId}/contact-details`, JSON Merge Patch (command) |
| `GetAccountSummary` | `GET /v1/accounts/{accountId}/summary` (query) |
| `GetTransactionHistory` | `GET /v1/accounts/{accountId}/transactions?from&to&limit&cursor` (query) |
| `InitiateTransfer` | `POST /v1/transfers` with an `Idempotency-Key` header (command) |
| `GetTransferStatus` | `GET /v1/transfers/{transferId}` and `GET /v1/transfers?clientRef=` (query) |

Out of scope: moving the mainframe customer master off MQ (the .NET API keeps calling the core stub with the same `CUSTREC` / `CUSTUPD` copybooks).

## Acceptance criteria

1. **Same answers.** Every rule R1 to R14 behaves as in the legacy estate, and each has a named test.
2. **Traps caught.** The 8 seeded traps each have a failing-then-passing test:
   - fee rounds half-up, not half-even (R13)
   - an absent field is not the same as an empty one (R3)
   - `pageSize` above 50 is quietly capped at 50 (R9)
   - Europe/London time is used, not server UTC (R12, R14)
   - packed-decimal `REL_VALUE` keeps its value and sign (R2)
   - account ids are matched case-insensitively (R8)
   - the two-commit transfer becomes one transaction (R12 to R14)
   - the 5-second MQ reply timeout returns 503 (R1)
3. **CQRS split.** Commands write through an EF Core write model in one transaction that also writes outbox rows. Queries read projected read models with Dapper and never touch the write model.
4. **Errors keep their codes.** Faults become RFC 9457 problem details, and the `type` keeps the HPB code (for example `HPB-422-LIMIT`).
5. **Gateway policies carried over.** Client keys, plans (600 and 60 calls/min), the `payments:write` scope, and `ChannelId` taken from a token claim, never from the request.
6. **Parity proven.** The golden request set replays through both stacks with matching business fields, or each difference has a signed decision record. This includes database state after each command.
7. **No duplicate postings** under 50 concurrent retries of one transfer.

## Definition of done

- Discovery inventory, rule catalogue (R1 to R14 traced to file and line) and legacy-to-target mapping table are signed off.
- OpenAPI 3.1 contract is published and validated against the running endpoints.
- Parity report is signed off, and p95 latency is recorded for both stacks.

## Phases and sign-offs

1. **Discover**: inventory and rule catalogue.
2. **Design**: command/query split, OpenAPI contract, decision record retiring the compensation path.
3. **Capture**: golden set and one failing test per rule.
4. **Build**: one vertical slice per operation, queries first, commands last.
5. **Prove**: full parity run.

Each phase needs a person's sign-off before the next one starts.
