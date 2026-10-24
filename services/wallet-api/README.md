# ShareTime Wallet API — AWS deployment

**Status:** Source code prepared; not deployed yet. No payment, billing, or withdrawals are live.

Project: Firebase `ntecway-sharetime`; AWS region `ap-southeast-2`.

## 1. Prepare Firebase credentials securely

In Firebase Console > Project settings > Service accounts, generate a dedicated Firebase Admin service account private key. Never share the JSON in chat, upload it to GitHub, or put it into Flutter assets. Place the raw JSON as a **SecretString** in AWS Secrets Manager in `ap-southeast-2`, e.g. a secret named `sharetime/firebase-admin-wallet`. Record its ARN in the AWS Console. Keep it private. Rotate/revoke if accidentally exposed.

The Lambda reads this secret using `FIREBASE_SERVICE_ACCOUNT_SECRET_ARN` and checks the service account's `project_id`.

## 2. Create the Lambda execution role

Create an IAM role with trust principal `lambda.amazonaws.com` and AWS managed policy `AWSLambdaBasicExecutionRole`. Add a **least-privilege** inline policy allowing `secretsmanager:GetSecretValue` on **only the exact wallet Firebase credential secret ARN**. If the secret uses a customer-managed KMS key, add `kms:Decrypt` on that exact key with appropriate restrictions.

The role must not permit wildcard Secrets Manager reads or unnecessary AWS administration.

## 3. Package Lambda in a trusted local environment

In the repository, within `services/wallet-api`:

```bash
npm install --omit=dev
zip -r wallet-lambda.zip index.mjs package.json node_modules
```

ZIP root must contain `index.mjs`, `package.json`, and `node_modules`. Never include service-account JSON, `.env`, credentials, or secrets in the ZIP.

## 4. Create Lambda and API Gateway

AWS Lambda console (Sydney region):

- Function name: `sharetime-wallet-api`
- Runtime: Node.js 22.x
- Handler: `index.handler`
- Execution role: the restricted role created above
- Set Memory 256 MB and Timeout 20 seconds initially
- Environment variable `FIREBASE_SERVICE_ACCOUNT_SECRET_ARN` = exact secret ARN
- Upload the ZIP from step 3
- Configure a dedicated API Gateway **HTTP API** with **POST** route `/wallet` and Lambda proxy integration. Use the gateway's HTTPS invoke URL including `/wallet`. Do **not** reuse the existing TURN credential Lambda handler or expose secret values.
- Add CloudWatch logging, rate limits/abuse protection and request size limits before external release.

For Flutter development pass the *new wallet endpoint* URL via:

```bash
flutter run --dart-define=SHARETIME_WALLET_API_URL=https://YOUR_API_ID.execute-api.ap-southeast-2.amazonaws.com/wallet
```

The URL is not a credential. The app sends the user's Firebase ID token in the Authorization header. Never hardcode AWS IAM keys or the Firebase Admin key in Flutter.

## 5. Set and verify admin access safely

An authorized project owner must use a separate privileged Firebase Admin process to set a **custom claim** `admin: true` on only the designated administrator's Firebase Auth UID. Never provide a client-accessible endpoint to set admin claims. The owner must sign out/in or refresh the token after setting the claim. The Flutter screen and the Lambda both check the claim; only the Lambda authorization is security-enforcing.

Do not paste privileged service-account JSON into ChatGPT.

## 6. Server-side actions

All endpoints are `POST` JSON with `Authorization: Bearer <FIREBASE_ID_TOKEN>` and:

- `{"action":"initializeWallet"}` — once per user; BDT 50 default welcome bonus, admin-configurable before initialization.
- `{"action":"setWelcomeBonus","amountPaisa":5000}` — admin.
- `{"action":"setWithdrawalPermission","userId":"FIREBASE_UID","enabled":true}` — admin.
- `{"action":"requestWithdrawal","requestId":"UNIQUE_IDEMPOTENCY_KEY","amountPaisa":50000}` — user, after permission; minimum BDT 500 and BDT 100 earnings reserve enforced transactionally.
- `{"action":"resolveWithdrawal","requestId":"UNIQUE_IDEMPOTENCY_KEY","decision":"paid"}` — admin, only after confirming manual transfer. `rejected` refunds held money.

Use integer paisa for every balance. Firebase Security Rules must block all client writes to the authoritative financial collections.

## 7. Test before enabling monetary activity

- Unauthenticated invocation must fail with 401.
- Regular user must get 403 on `setWelcomeBonus` and `setWithdrawalPermission`.
- Existing wallet initialization cannot grant the welcome bonus twice.
- User with permission OFF must not be able to withdraw.
- User with BDT 600 earnings may request BDT 500 but not BDT 501.
- Concurrent / duplicate requests must not double-debit.
- No real money or withdrawals until payout identity/destination verification, audit logs, authorization, reconciliation, and transactional accounting have been reviewed.

**Important:** The current Flutter Wallet view remains read-only; the Withdraw button is intentionally disabled. This backend is not yet linked to wallet initialization, payout details, or live money movement. The admin screen is available only after Firebase admin claim and endpoint configuration.
