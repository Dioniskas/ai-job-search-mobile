"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.uploadBuffer = uploadBuffer;
exports.deleteFile = deleteFile;
const nodejs_1 = require("@imagekit/nodejs");
const ik = new nodejs_1.ImageKit({
    privateKey: process.env.IMAGEKIT_PRIVATE_KEY,
});
async function uploadBuffer(buffer, mimetype, folder, fileName) {
    const file = await (0, nodejs_1.toFile)(buffer, fileName, { type: mimetype });
    const result = await ik.files.upload({
        file,
        fileName,
        folder,
        useUniqueFileName: false,
        overwriteFile: true,
    });
    if (!result.url)
        throw new Error('ImageKit upload returned no URL');
    return result.url;
}
// Requires fileId — store it in the future if soft-delete is needed.
// Currently unused; left for future sprints.
async function deleteFile(fileId) {
    await ik.files.delete(fileId);
}
