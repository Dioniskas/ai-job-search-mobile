"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.uploadBuffer = uploadBuffer;
exports.deleteFile = deleteFile;
const imagekit_1 = __importDefault(require("imagekit"));
const ik = new imagekit_1.default({
    publicKey: process.env.IMAGEKIT_PUBLIC_KEY,
    privateKey: process.env.IMAGEKIT_PRIVATE_KEY,
    urlEndpoint: process.env.IMAGEKIT_URL_ENDPOINT,
});
async function uploadBuffer(buffer, mimetype, folder, fileName) {
    const result = await ik.upload({
        file: buffer,
        fileName,
        folder,
        useUniqueFileName: false,
        overwriteFile: true,
    });
    if (!result.url)
        throw new Error('ImageKit upload returned no URL');
    return result.url;
}
async function deleteFile(fileId) {
    await ik.deleteFile(fileId);
}
