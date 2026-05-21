"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ok = ok;
exports.fail = fail;
function ok(res, data, status = 200) {
    res.status(status).json({ success: true, data });
}
function fail(res, error, status = 400) {
    res.status(status).json({ success: false, error });
}
