"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.uploadAudio = exports.uploadPdf = exports.uploadSingle = void 0;
const multer_1 = __importDefault(require("multer"));
const response_1 = require("../utils/response");
const storage = multer_1.default.memoryStorage();
function makeUploader(allowedMime, maxMb) {
    return (0, multer_1.default)({
        storage,
        limits: { fileSize: maxMb * 1024 * 1024 },
        fileFilter: (_req, file, cb) => {
            if (allowedMime.includes(file.mimetype)) {
                cb(null, true);
            }
            else {
                cb(new Error(`Allowed types: ${allowedMime.join(', ')}`));
            }
        },
    });
}
// image/jpg is sent by some Android devices alongside the standard image/jpeg
const imageUploader = makeUploader(['image/jpeg', 'image/jpg', 'image/png', 'image/webp'], 5);
const pdfUploader = makeUploader(['application/pdf'], 10);
const audioUploader = makeUploader(['audio/webm', 'audio/ogg', 'audio/mp4', 'audio/mpeg', 'audio/wav', 'video/webm'], 25);
function wrapSingle(uploader, fieldName) {
    return (req, res, next) => {
        uploader.single(fieldName)(req, res, (err) => {
            if (err instanceof multer_1.default.MulterError) {
                (0, response_1.fail)(res, `Upload error: ${err.message}`);
            }
            else if (err instanceof Error) {
                (0, response_1.fail)(res, err.message);
            }
            else {
                next();
            }
        });
    };
}
const uploadSingle = (field) => wrapSingle(imageUploader, field);
exports.uploadSingle = uploadSingle;
const uploadPdf = (field) => wrapSingle(pdfUploader, field);
exports.uploadPdf = uploadPdf;
const uploadAudio = (field) => wrapSingle(audioUploader, field);
exports.uploadAudio = uploadAudio;
