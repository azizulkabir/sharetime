# ShareTime Wallet API — deployment notes

This is backend source code, NOT a deployed payment service.

## Security prerequisites

- Run as AWS Lambda Node.js 22.x with Firebase Admin SDK dependencies bundled.
- Configure secure server-side Firebase service-account credentials using AWS Secrets Manager or secure workload identity. NEVER commit service-account JSON or AWS access keys.
- Expose only HTTPS through API Gateway. Restrict CORS to approved app clients where applicable, add abuse throttling and audit monitoring.
- The caller must supply `Authorization: Bearer <Firebase ID token>`.
- Set the `admin` custom claim using a privileged, audited Firebase Admin process. Admin privileges cannot be set by a Flutter client.
- Firestore Security Rules block all client writes to `walletAccounts`. Also block direct client writes to `walletConfig` and `withdrawalRequests`.
- Review payout destination verification, admin payment reconciliation, rate limits, limits, ledger auditing, failed payouts, and compliance before enabling real withdrawals.

## API actions

POST JSON body: `{ "action": "initializeWallet" }` — one-time BDT 50 default bonus; future users take the current admin-configured amount.
`{ "action": "setWelcomeBonus", "amountPaisa": 5000 }` — admin only.
`{ "action": "setWithdrawalPermission", "userId": "UID", "enabled": true }` — admin only.
`{ "action": "requestWithdrawal", "requestId": "unique_12char_key", "amountPaisa": 50000 }` — authorized users; reserve BDT 100 and minimum BDT 500 enforced atomically.
`{ "action": "resolveWithdrawal", "requestId": "ID", "decision": "paid" }` — admin only, after manual payout confirmation; `rejected` refunds the held amount.

All amounts are integer paisa, not floating point. Wallet and ledger operations are Firestore transactions.

## Not live yet

No Lambda deployment, API Gateway endpoint, wallet initialization in Flutter, or real payout rails are configured in this commit. The Wallet screen deliberately keeps withdrawals disabled. Do not claim live payout functionality based on this code alone.
