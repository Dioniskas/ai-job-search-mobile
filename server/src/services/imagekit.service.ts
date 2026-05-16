import { ImageKit, toFile } from '@imagekit/nodejs';

const ik = new ImageKit({
  privateKey: process.env.IMAGEKIT_PRIVATE_KEY as string,
});

export async function uploadBuffer(
  buffer: Buffer,
  mimetype: string,
  folder: string,
  fileName: string
): Promise<string> {
  const file = await toFile(buffer, fileName, { type: mimetype });
  const result = await ik.files.upload({
    file,
    fileName,
    folder,
    useUniqueFileName: false,
    overwriteFile: true,
  });
  if (!result.url) throw new Error('ImageKit upload returned no URL');
  return result.url;
}

// Requires fileId — store it in the future if soft-delete is needed.
// Currently unused; left for future sprints.
export async function deleteFile(fileId: string): Promise<void> {
  await ik.files.delete(fileId);
}
