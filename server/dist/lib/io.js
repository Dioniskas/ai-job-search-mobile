"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.setIo = setIo;
exports.getIo = getIo;
let io;
function setIo(instance) {
    io = instance;
}
function getIo() {
    if (!io)
        throw new Error('Socket.io not initialized');
    return io;
}
