# Harbour Point Bank: legacy estate

The legacy half of the *Synthetic Bank Estate: IIB SOAP Services to .NET CQRS APIs* spec. It holds three SOAP services on IBM Integration Bus, an API Connect layer in front of them, and a simulated back end. It does **not** include the .NET migration.

```
API Connect (DataPower)  ->  IIB / ACE  ->  CustomerService -> MQ -> HPB_CoreStub -> mainframe.customer   (simulated mainframe)
                                        ->  AccountService  -> PostgreSQL core.*
                                        ->  PaymentService  -> PostgreSQL core.*  +  MQ topic HPB/TRANSFERS/COMPLETED
```

## What is where

| Path | Contents |
| --- | --- |
| `legacy/db/` | `schema.sql`, `seed.py` (fixed seed) and the generated `seed.sql`, `bank_holidays.sql` |
| `legacy/mq/hpb.mqsc` | Queues (`CORE.CUST.REQ/RPLY`, backout), topic `HPB/TRANSFERS`, a sink queue so you can see published events |
| `legacy/iib/HPB_CommonLib` | `SF_ValidateHeader`, `SF_Audit`, `SF_ErrorHandler`, shared `hpb:Header` / `hpb:Error` schema |
| `legacy/iib/HPB_CustomerService` | `GetCustomerProfile`, `UpdateContactDetails` (R1-R5), WSDL, DFDL `CUSTREC` / `CUSTUPD`, `SF_CoreCall` |
| `legacy/iib/HPB_AccountService` | `GetAccountSummary`, `GetTransactionHistory` (R6-R10) |
| `legacy/iib/HPB_PaymentService` | `InitiateTransfer`, `GetTransferStatus` (R11-R14), two commits plus compensation, publication node |
| `legacy/iib/HPB_CoreStub` | MQ-driven stub that plays the mainframe |
| `legacy/apic/` | Product, three SOAP API definitions, GatewayScript for `ChannelId` and gateway faults |
| `legacy/golden/` | 17 sample SOAP requests and `call.sh` (the full golden set is a later step) |
| `legacy/deploy/` | `build-bar.sh`, `odbc.ini`, `server.conf.yaml` |
| `docker-compose.yml` | PostgreSQL 16 and IBM MQ (`HPBQM1`) |

## Run it

1. `docker compose up -d` starts PostgreSQL (schema and seed load on first start) and MQ (queues load from `hpb.mqsc`).
2. Start an ACE 12/13 Developer Edition (or IIB 10) integration server. Set up the `HPBDB` ODBC DSN using `legacy/deploy/odbc.ini` and the credentials from `build-bar.sh`. Merge `server.conf.yaml`.
3. `legacy/deploy/build-bar.sh`, then deploy the BAR. Or open `legacy/iib` as a workspace in the Toolkit and deploy from there.
4. Test direct to IIB: `DIRECT=1 legacy/golden/call.sh payment/InitiateTransfer-ok.xml`.
5. In API Connect (Local Test Environment or a cloud trial), import `legacy/apic/` and publish the product. The gateway needs a client app with a custom field `channelId`, and an OAuth provider named `hpb-oauth-provider` for PaymentService. Then run `call.sh` without `DIRECT`.

## Seed data highlights

25 customers and 40 accounts, with about 1,900 ledger entries over 18 months. `seed.py` uses a fixed seed, so the data is the same on every run.

| Case | Where |
| --- | --- |
| Frozen account / closed account | `HPB10000005` / `HPB10000006` |
| Overdraft accounts | `HPB10000007`, `HPB10000008` |
| Active holds (R6) | `HPB10000009` to `HPB10000011`. `HPB10000012` has an expired hold |
| Credit leg fails, compensation runs | transfer into `HPB10000040`, which sits just under the balance ceiling |
| Customer with KYC REFER (R5) | `CUST000007`, `CUST000019` |
| Customer with unknown DOB (R2) | `CUST000009`, `CUST000021` |

## Things to know

- **The IIB artefacts are hand-authored text, never opened in a Toolkit.** The ESQL, DFDL, WSDL and msgflow XML follow the documented shapes, but some node property names (the MQGet correlation match, SOAPInput selectors) and DFDL options may need a tweak on first import. The spec already says a person must check every flow runs on IIB before it is frozen.
- Nothing here has been executed. No Docker, PostgreSQL, IIB or API Connect is available where this was written, so only XML well-formedness and seed generation were checked.
- ESQL reads PASSTHRU result columns in lower case, which is how PostgreSQL returns them.
- A rejected transfer (R12) is stored as `REJECTED`, so a retry with the same `clientRef` returns the original `TransferId` and `REJECTED` rather than a fresh fault.
- `ClockOverride` (a user-defined property on PaymentService, see `server.conf.yaml`) pins the London clock so you can test the 17:30 and BST/GMT boundaries.
- API Connect context variables (`client.app.metadata`) and policy syntax in `legacy/apic/` should be checked against your API Connect version.
