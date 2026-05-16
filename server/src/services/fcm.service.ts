import admin from 'firebase-admin';

let initialized = false;

function ensureInitialized() {
  if (initialized) return;

  const projectId   = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey  = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (!projectId || !clientEmail || !privateKey) {
    console.warn('Firebase Admin not configured — push notifications disabled');
    return;
  }

  admin.initializeApp({
    credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
  });
  initialized = true;
}

export async function sendPush(
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<void> {
  ensureInitialized();
  if (!initialized) return;

  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data,
      android: {
        notification: {
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          sound: 'default',
        },
      },
      apns: {
        payload: { aps: { sound: 'default' } },
      },
    });
  } catch (e) {
    // Push failure must not break the main request
    console.error('FCM send failed:', e instanceof Error ? e.message : e);
  }
}
