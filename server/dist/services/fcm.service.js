"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendPush = sendPush;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
let initialized = false;
function ensureInitialized() {
    if (initialized)
        return;
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
    if (!projectId || !clientEmail || !privateKey) {
        console.warn('Firebase Admin not configured — push notifications disabled');
        return;
    }
    firebase_admin_1.default.initializeApp({
        credential: firebase_admin_1.default.credential.cert({ projectId, clientEmail, privateKey }),
    });
    initialized = true;
}
async function sendPush(token, title, body, data) {
    ensureInitialized();
    if (!initialized)
        return;
    try {
        await firebase_admin_1.default.messaging().send({
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
    }
    catch (e) {
        // Push failure must not break the main request
        console.error('FCM send failed:', e instanceof Error ? e.message : e);
    }
}
