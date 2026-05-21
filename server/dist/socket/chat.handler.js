"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.initChatSocket = initChatSocket;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
function initChatSocket(io) {
    io.use((socket, next) => {
        const token = socket.handshake.auth.token;
        if (!token)
            return next(new Error('Unauthorized'));
        try {
            const payload = jsonwebtoken_1.default.verify(token, process.env.JWT_SECRET);
            socket.user = payload;
            next();
        }
        catch {
            next(new Error('Invalid token'));
        }
    });
    io.on('connection', (socket) => {
        socket.on('join_application', (applicationId) => {
            socket.join(`app_${applicationId}`);
        });
        socket.on('leave_application', (applicationId) => {
            socket.leave(`app_${applicationId}`);
        });
    });
}
