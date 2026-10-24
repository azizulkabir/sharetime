import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

// Firebase service account remains in AWS Secrets Manager; never in the
// repository, deployment ZIP or Flutter application.
let firebaseClientsPromise;
async function firebaseClients() {
  firebaseClientsPromise ??= (async () => {
    const secretId = process.env.FIREBASE_SERVICE_ACCOUNT_SECRET_ARN;
    if (!secretId) throw new Error('Firebase credentials secret is not configured.');
    const secret = await new SecretsManagerClient({}).send(
      new GetSecretValueCommand({ SecretId: secretId }),
    );
    if (!secret.SecretString) throw new Error('Firebase credentials secret is empty.');
    const serviceAccount = JSON.parse(secret.SecretString);
    if (serviceAccount.project_id !== 'ntecway-sharetime') {
      throw new Error('Unexpected Firebase project.');
    }
    const app = getApps().length
      ? getApps()[0]
      : initializeApp({
          credential: cert(serviceAccount),
          projectId: 'ntecway-sharetime',
        });
    return { db: getFirestore(app), auth: getAuth(app) };
  })();
  return firebaseClientsPromise;
}

const DEFAULT_BONUS_PAISA = 5000; // BDT 50, configurable by admin
const MIN_WITHDRAWAL_PAISA = 50000; // BDT 500
const REQUIRED_RESERVE_PAISA = 10000; // BDT 100

function reply(statusCode, data) {
  return {
    statusCode,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
    body: JSON.stringify(data),
  };
}

function requireInteger(value, minimum = 0) {
  if (!Number.isSafeInteger(value) || value < minimum) {
    throw Object.assign(new Error('Invalid amount.'), { statusCode: 400 });
  }
  return value;
}

async function actor(event, auth) {
  const token = (event.headers?.authorization ?? event.headers?.Authorization ?? '')
    .match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) throw Object.assign(new Error('Authentication required.'), { statusCode: 401 });
  return auth.verifyIdToken(token, true);
}

function requireAdmin(decoded) {
  if (decoded.admin !== true) {
    throw Object.assign(new Error('Admin permission required.'), { statusCode: 403 });
  }
}

export async function handler(event) {
  try {
    const { db, auth } = await firebaseClients();
    const user = await actor(event, auth);
    const body = event.body ? JSON.parse(event.body) : {};
    const action = body.action;

    if (action === 'initializeWallet') {
      const ref = db.collection('walletAccounts').doc(user.uid);
      await db.runTransaction(async (tx) => {
        if ((await tx.get(ref)).exists) return;
        const settingsRef = db.collection('walletConfig').doc('policy');
        const settings = (await tx.get(settingsRef)).data() ?? {};
        const bonus = requireInteger(
          settings.welcomeBonusPaisa ?? DEFAULT_BONUS_PAISA,
        );
        tx.create(ref, {
          spendingBalancePaisa: bonus,
          providerEarningsPaisa: 0,
          pendingWithdrawalPaisa: 0,
          withdrawalEnabled: false,
          welcomeBonusGranted: true,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.create(ref.collection('ledger').doc('welcomeBonus'), {
          type: 'welcome_bonus',
          amountPaisa: bonus,
          createdAt: FieldValue.serverTimestamp(),
        });
      });
      return reply(200, { success: true });
    }

    if (action === 'setWelcomeBonus') {
      requireAdmin(user);
      const value = requireInteger(body.amountPaisa);
      if (value > 1000000) return reply(400, { message: 'Bonus exceeds limit.' });
      await db.collection('walletConfig').doc('policy').set(
        { welcomeBonusPaisa: value, updatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
      return reply(200, { success: true });
    }

    if (action === 'setWithdrawalPermission') {
      requireAdmin(user);
      const targetUid = body.userId;
      if (typeof targetUid !== 'string' || !targetUid || typeof body.enabled !== 'boolean') {
        return reply(400, { message: 'Invalid user or permission.' });
      }
      const ref = db.collection('walletAccounts').doc(targetUid);
      await db.runTransaction(async (tx) => {
        if (!(await tx.get(ref)).exists) {
          throw Object.assign(new Error('Wallet not initialized.'), { statusCode: 404 });
        }
        tx.update(ref, {
          withdrawalEnabled: body.enabled,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      return reply(200, { success: true });
    }

    if (action === 'requestWithdrawal') {
      const amount = requireInteger(body.amountPaisa, MIN_WITHDRAWAL_PAISA);
      const requestId = typeof body.requestId === 'string' ? body.requestId : '';
      if (!/^[a-zA-Z0-9_-]{12,80}$/.test(requestId)) {
        return reply(400, { message: 'Valid idempotency key required.' });
      }
      const walletRef = db.collection('walletAccounts').doc(user.uid);
      const withdrawalRef = db.collection('withdrawalRequests').doc(requestId);
      await db.runTransaction(async (tx) => {
        const existing = await tx.get(withdrawalRef);
        if (existing.exists) {
          if (existing.data().userId === user.uid &&
              existing.data().amountPaisa === amount) return;
          throw Object.assign(new Error('Duplicate request ID.'), { statusCode: 409 });
        }
        const snapshot = await tx.get(walletRef);
        if (!snapshot.exists) {
          throw Object.assign(new Error('Wallet not initialized.'), { statusCode: 404 });
        }
        const wallet = snapshot.data();
        if (wallet.withdrawalEnabled !== true) {
          throw Object.assign(new Error('Admin approval is required.'), { statusCode: 403 });
        }
        const earnings = requireInteger(wallet.providerEarningsPaisa);
        if (earnings - amount < REQUIRED_RESERVE_PAISA) {
          throw Object.assign(new Error('Insufficient earnings after reserve.'), { statusCode: 400 });
        }
        tx.update(walletRef, {
          providerEarningsPaisa: earnings - amount,
          pendingWithdrawalPaisa: FieldValue.increment(amount),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.create(withdrawalRef, {
          userId: user.uid,
          amountPaisa: amount,
          status: 'pending',
          createdAt: FieldValue.serverTimestamp(),
        });
        tx.create(walletRef.collection('ledger').doc(requestId), {
          type: 'withdrawal_hold',
          amountPaisa: -amount,
          createdAt: FieldValue.serverTimestamp(),
        });
      });
      return reply(200, { success: true, requestId });
    }

    if (action === 'resolveWithdrawal') {
      requireAdmin(user);
      const { requestId, decision } = body;
      if (typeof requestId !== 'string' || !['paid', 'rejected'].includes(decision)) {
        return reply(400, { message: 'Invalid request or decision.' });
      }
      const ref = db.collection('withdrawalRequests').doc(requestId);
      await db.runTransaction(async (tx) => {
        const request = await tx.get(ref);
        if (!request.exists) {
          throw Object.assign(new Error('Request not found.'), { statusCode: 404 });
        }
        if (request.data().status !== 'pending') {
          throw Object.assign(new Error('Request already processed.'), { statusCode: 409 });
        }
        const { userId, amountPaisa } = request.data();
        const walletRef = db.collection('walletAccounts').doc(userId);
        const wallet = await tx.get(walletRef);
        if (!wallet.exists || wallet.data().pendingWithdrawalPaisa < amountPaisa) {
          throw Object.assign(new Error('Wallet state mismatch.'), { statusCode: 409 });
        }
        tx.update(walletRef, {
          pendingWithdrawalPaisa: FieldValue.increment(-amountPaisa),
          ...(decision === 'rejected'
            ? { providerEarningsPaisa: FieldValue.increment(amountPaisa) }
            : {}),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.update(ref, {
          status: decision,
          reviewedBy: user.uid,
          resolvedAt: FieldValue.serverTimestamp(),
        });
        tx.create(walletRef.collection('ledger').doc(requestId + '_' + decision), {
          type: decision === 'paid' ? 'withdrawal_paid' : 'withdrawal_refunded',
          amountPaisa: decision === 'paid' ? 0 : amountPaisa,
          createdAt: FieldValue.serverTimestamp(),
        });
      });
      return reply(200, { success: true });
    }

    return reply(400, { message: 'Unknown action.' });
  } catch (error) {
    const status = error.statusCode ??
      ((error.code === 'auth/id-token-expired' || error.code === 'auth/argument-error')
        ? 401 : 500);
    console.error('Wallet action failed:', { status, code: error.code ?? 'unknown' });
    return reply(status, { success: false, message: status === 500 ? 'Server error.' : error.message });
  }
}
