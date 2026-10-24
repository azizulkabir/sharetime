# ShareTime: GitHub Actions → AWS Lambda via OIDC

**Current status:** Configuration files are committed. AWS IAM provider/role, Lambda function and GitHub repository settings still require first-time setup in the account; nothing is deployed automatically.

### GitHub repository

- Repository: `azizulkabir/sharetime`
- GitHub Actions workflow: `.github/workflows/deploy-wallet-lambda.yml`
- Manual trigger: Actions → Deploy ShareTime Wallet Lambda → Run workflow (**main** only).
- GitHub environment: `wallet-production`. **Configure Deployment branches and tags to allow only `main`**. Optionally add required reviewers if supported by your GitHub plan.
- GitHub repository variable: `AWS_WALLET_DEPLOY_ROLE_ARN` containing the role ARN (no long-lived access keys needed).
- In Settings → Actions → General ensure the workflow is permitted to run.
- Do not run deployment until Lambda and IAM setup are finished.

### AWS IAM setup (AWS account 293767632920)

IAM is a global service; Lambda region is **Sydney, ap-southeast-2**.

1. In AWS IAM → Identity providers → Add provider, choose **OpenID Connect**, enter `https://token.actions.githubusercontent.com`, Audience `sts.amazonaws.com`. If the provider already exists, reuse it.
2. IAM → Roles → Create role with Web identity (GitHub OIDC provider), then use the committed trust JSON `infrastructure/aws/wallet-github-oidc-trust-policy.json`. This trust policy limits AWS role assumption to the `wallet-production` environment, whose allowed deployment branch must be restricted to `main`.
3. Attach the inline permissions JSON `infrastructure/aws/wallet-github-deploy-permissions.json`. It allows only `lambda:UpdateFunctionCode` and `lambda:GetFunctionConfiguration` for `sharetime-wallet-api`, not IAM/Secrets Manager/admin changes.
4. Suggested role name: `sharetime-github-wallet-deployer`. Copy its full ARN into GitHub repository Actions variable `AWS_WALLET_DEPLOY_ROLE_ARN`.
5. Verify the AWS account ID in the JSON matches your intended AWS account. If GitHub issued an **immutable-subject OIDC token** for this repository, use its actual documented `sub` claim and adjust the trust policy before proceeding. Do not relax the trust to `repo:azizulkabir/*` or an unrestricted wildcard.

### Prerequisite Lambda resources (one-time AWS Console steps)

The workflow **does not create** Lambda resources or privileges. Complete `services/wallet-api/README.md` first:

- Secrets Manager: Firebase Admin JSON stored privately, `sharetime/firebase-admin-wallet`. Never commit or share JSON.
- Lambda execution role: CloudWatch basic logs and **read access only to that exact Secrets Manager secret**, plus customer-managed KMS decrypt if applicable.
- Lambda: `sharetime-wallet-api`, Node.js 22.x, handler `index.handler`, region `ap-southeast-2`, environment variable `FIREBASE_SERVICE_ACCOUNT_SECRET_ARN` set to the correct ARN.
- API Gateway HTTPS POST `/wallet` integration, with appropriate protections. First deployment requires a Lambda function to exist; the GitHub workflow updates its code package.
- Firebase administrator custom claim should only be granted through a privileged Admin SDK operation, not by app clients.

### Run and verify

1. Run the manual workflow from GitHub Actions while selecting `main`.
2. Check **Configure AWS credentials using OIDC** and **Verify Lambda deployment** both pass.
3. Only afterward configure the Flutter launch value `--dart-define=SHARETIME_WALLET_API_URL=https://<api-id>.execute-api.ap-southeast-2.amazonaws.com/wallet` using the real API URL.
4. Test unauthenticated requests (401), normal-user admin requests (403), welcome bonus idempotency, and concurrent withdrawal reserve enforcement before any real money is handled.

Security note: AWS trust on `environment:wallet-production` relies on GitHub environment deployment-branch rules. Without that, an untrusted branch could attempt deployment through that environment. Configure branch restrictions before enabling the role.
