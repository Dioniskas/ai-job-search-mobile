"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createPaymePayment = createPaymePayment;
exports.paymeCallback = paymeCallback;
exports.createClickPayment = createClickPayment;
exports.clickCallback = clickCallback;
exports.completeTestPayment = completeTestPayment;
exports.getPaymentHistory = getPaymentHistory;
const crypto_1 = __importDefault(require("crypto"));
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
const BOOST_DAYS = 7;
const PRICES = {
    RESUME_BOOST: 1990,
    VACANCY_BOOST: 4990,
};
const isPaymeTest = () => process.env.PAYME_TEST_MODE === 'true';
const isClickTest = () => process.env.CLICK_TEST_MODE === 'true';
function boostUntil(days) {
    const d = new Date();
    d.setDate(d.getDate() + days);
    return d;
}
async function applyBoost(payment) {
    if (payment.type === 'RESUME_BOOST') {
        const seeker = await prisma_1.default.seekerProfile.findUnique({ where: { userId: payment.userId } });
        if (seeker) {
            await prisma_1.default.seekerProfile.update({
                where: { id: seeker.id },
                data: { boostedUntil: boostUntil(payment.days) },
            });
        }
    }
    else if (payment.type === 'VACANCY_BOOST' && payment.vacancyId) {
        await prisma_1.default.vacancy.update({
            where: { id: payment.vacancyId },
            data: { boostedUntil: boostUntil(payment.days) },
        });
    }
}
// ── Payme ─────────────────────────────────────────────────────────────────────
async function createPaymePayment(req, res) {
    try {
        const { userId } = req.user;
        const { type, vacancyId } = req.body;
        if (!PRICES[type]) {
            (0, response_1.fail)(res, 'Неверный тип платежа');
            return;
        }
        if (type === 'VACANCY_BOOST' && !vacancyId) {
            (0, response_1.fail)(res, 'vacancyId обязателен');
            return;
        }
        const amount = PRICES[type];
        const payment = await prisma_1.default.payment.create({
            data: { userId, type, provider: 'PAYME', amount, days: BOOST_DAYS, vacancyId: vacancyId ?? null },
        });
        if (isPaymeTest()) {
            (0, response_1.ok)(res, { paymentId: payment.id, checkoutUrl: null, testMode: true, amount });
            return;
        }
        const merchantId = process.env.PAYME_MERCHANT_ID ?? '';
        const amountTiyin = amount * 100;
        const params = `m=${merchantId};ac.order_id=${payment.id};a=${amountTiyin};l=ru`;
        const checkoutUrl = `https://checkout.paycom.uz/${Buffer.from(params).toString('base64')}`;
        (0, response_1.ok)(res, { paymentId: payment.id, checkoutUrl, testMode: false, amount });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function paymeCallback(req, res) {
    // Verify Basic auth: Paycom:{SECRET_KEY}
    const authHeader = req.headers.authorization ?? '';
    const secretKey = process.env.PAYME_SECRET_KEY ?? '';
    const expected = `Basic ${Buffer.from(`Paycom:${secretKey}`).toString('base64')}`;
    if (authHeader !== expected) {
        res.status(401).json({
            jsonrpc: '2.0',
            id: req.body?.id ?? null,
            error: { code: -32504, message: { ru: 'Не авторизован', en: 'Unauthorized' } },
        });
        return;
    }
    const { method, params, id } = req.body;
    const orderId = params?.account?.order_id;
    const reply = (result) => res.json({ jsonrpc: '2.0', id, result });
    const rpcError = (code, message) => res.json({ jsonrpc: '2.0', id, error: { code, message: { ru: message, en: message } } });
    const payment = orderId
        ? await prisma_1.default.payment.findUnique({ where: { id: orderId } })
        : null;
    switch (method) {
        case 'CheckPerformTransaction': {
            if (!payment || payment.status === 'FAILED' || payment.status === 'CANCELLED') {
                return void rpcError(-31050, 'Заказ не найден');
            }
            return void reply({ allow: true });
        }
        case 'CreateTransaction': {
            if (!payment)
                return void rpcError(-31050, 'Заказ не найден');
            if (payment.status === 'PAID')
                return void rpcError(-31060, 'Транзакция уже выполнена');
            await prisma_1.default.payment.update({ where: { id: orderId }, data: { transactionId: params.id } });
            return void reply({ create_time: Date.now(), transaction: params.id, state: 1 });
        }
        case 'PerformTransaction': {
            if (!payment)
                return void rpcError(-31050, 'Заказ не найден');
            if (payment.status === 'PAID') {
                return void reply({ transaction: payment.transactionId, perform_time: Date.now(), state: 2 });
            }
            await prisma_1.default.payment.update({ where: { id: orderId }, data: { status: 'PAID' } });
            await applyBoost(payment);
            return void reply({ transaction: params.id, perform_time: Date.now(), state: 2 });
        }
        case 'CancelTransaction': {
            if (!payment)
                return void rpcError(-31050, 'Заказ не найден');
            if (payment.status === 'PAID')
                return void rpcError(-31070, 'Невозможно отменить выполненный платёж');
            await prisma_1.default.payment.update({ where: { id: orderId }, data: { status: 'CANCELLED' } });
            return void reply({ transaction: params.id, cancel_time: Date.now(), state: -1 });
        }
        case 'CheckTransaction': {
            if (!payment)
                return void rpcError(-31050, 'Заказ не найден');
            const stateMap = {
                PENDING: 1, PAID: 2, CANCELLED: -1, FAILED: -2,
            };
            return void reply({
                create_time: payment.createdAt.getTime(),
                transaction: payment.transactionId ?? params.id,
                state: stateMap[payment.status] ?? -2,
            });
        }
        default:
            return void rpcError(-32601, 'Метод не найден');
    }
}
// ── Click ─────────────────────────────────────────────────────────────────────
async function createClickPayment(req, res) {
    try {
        const { userId } = req.user;
        const { type, vacancyId } = req.body;
        if (!PRICES[type]) {
            (0, response_1.fail)(res, 'Неверный тип платежа');
            return;
        }
        if (type === 'VACANCY_BOOST' && !vacancyId) {
            (0, response_1.fail)(res, 'vacancyId обязателен');
            return;
        }
        const amount = PRICES[type];
        const payment = await prisma_1.default.payment.create({
            data: { userId, type, provider: 'CLICK', amount, days: BOOST_DAYS, vacancyId: vacancyId ?? null },
        });
        if (isClickTest()) {
            (0, response_1.ok)(res, { paymentId: payment.id, checkoutUrl: null, testMode: true, amount });
            return;
        }
        const serviceId = process.env.CLICK_SERVICE_ID ?? '';
        const merchantId = process.env.CLICK_MERCHANT_ID ?? '';
        const returnUrl = process.env.CLICK_RETURN_URL ?? 'aijobsearch://payment/result';
        const checkoutUrl = `https://my.click.uz/services/pay` +
            `?service_id=${serviceId}` +
            `&merchant_id=${merchantId}` +
            `&amount=${amount}` +
            `&transaction_param=${payment.id}` +
            `&return_url=${encodeURIComponent(returnUrl)}`;
        (0, response_1.ok)(res, { paymentId: payment.id, checkoutUrl, testMode: false, amount });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function clickCallback(req, res) {
    try {
        const { click_trans_id, service_id, click_paydoc_id, merchant_trans_id, merchant_prepare_id, amount, action, sign_time, sign_string, } = req.body;
        const secretKey = process.env.CLICK_SECRET_KEY ?? '';
        // Verify signature
        const signData = action === '0'
            ? `${click_trans_id}${service_id}${secretKey}${merchant_trans_id}${amount}${action}${sign_time}`
            : `${click_trans_id}${service_id}${secretKey}${merchant_trans_id}${merchant_prepare_id}${amount}${action}${sign_time}`;
        const expected = crypto_1.default.createHash('md5').update(signData).digest('hex');
        if (sign_string !== expected) {
            res.json({ error: -1, error_note: 'SIGN CHECK FAILED!' });
            return;
        }
        const payment = await prisma_1.default.payment.findUnique({ where: { id: merchant_trans_id } });
        if (!payment) {
            res.json({ error: -5, error_note: 'Order not found' });
            return;
        }
        if (action === '0') {
            // Prepare — check order validity
            res.json({
                click_trans_id,
                merchant_trans_id: payment.id,
                merchant_prepare_id: payment.id,
                error: 0,
                error_note: 'Success',
            });
        }
        else if (action === '1') {
            // Complete — mark as paid and apply boost
            if (payment.status !== 'PAID') {
                await prisma_1.default.payment.update({ where: { id: payment.id }, data: { status: 'PAID', transactionId: click_trans_id } });
                await applyBoost(payment);
            }
            res.json({
                click_trans_id,
                merchant_trans_id: payment.id,
                merchant_confirm_id: payment.id,
                error: 0,
                error_note: 'Success',
            });
        }
        else {
            res.json({ error: -3, error_note: 'Action not found' });
        }
    }
    catch (e) {
        res.json({ error: -9, error_note: `Server error: ${e instanceof Error ? e.message : 'unknown'}` });
    }
}
// ── Test complete (only in test mode) ────────────────────────────────────────
async function completeTestPayment(req, res) {
    if (!isPaymeTest() && !isClickTest()) {
        (0, response_1.fail)(res, 'Тестовый режим не активен', 403);
        return;
    }
    try {
        const { userId } = req.user;
        const { paymentId } = req.body;
        if (!paymentId) {
            (0, response_1.fail)(res, 'paymentId обязателен');
            return;
        }
        const payment = await prisma_1.default.payment.findUnique({ where: { id: paymentId } });
        if (!payment) {
            (0, response_1.fail)(res, 'Платёж не найден', 404);
            return;
        }
        if (payment.userId !== userId) {
            (0, response_1.fail)(res, 'Нет доступа', 403);
            return;
        }
        if (payment.status === 'PAID') {
            (0, response_1.ok)(res, { message: 'Уже оплачено', boostedUntil: null });
            return;
        }
        await prisma_1.default.payment.update({
            where: { id: paymentId },
            data: { status: 'PAID', transactionId: `test_${Date.now()}` },
        });
        await applyBoost(payment);
        (0, response_1.ok)(res, {
            message: 'Симуляция оплаты успешна',
            paymentId,
            type: payment.type,
        });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── History ───────────────────────────────────────────────────────────────────
async function getPaymentHistory(req, res) {
    try {
        const { userId } = req.user;
        const payments = await prisma_1.default.payment.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
            take: 50,
        });
        (0, response_1.ok)(res, payments);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
