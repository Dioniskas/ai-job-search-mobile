"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validate = validate;
const response_1 = require("../utils/response");
function validate(schema) {
    return (req, res, next) => {
        const result = schema.safeParse(req.body);
        if (!result.success) {
            const error = result.error.errors[0];
            (0, response_1.fail)(res, error.message, 400);
            return;
        }
        req.body = result.data;
        next();
    };
}
