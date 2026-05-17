import ImageKit from 'imagekit';

const ik = new ImageKit({
  publicKey:  process.env.IMAGEKIT_PUBLIC_KEY  as string,
  privateKey: process.env.IMAGEKIT_PRIVATE_KEY as string,
  urlEndpoint: process.env.IMAGEKIT_URL_ENDPOINT as string,
});

export async function uploadBuffer(
  buffer: Buffer,
  mimetype: string,
  folder: string,
  fileName: string
): Promise<string> {
  const result = await ik.upload({
    file: buffer,
    fileName,
    folder,
    useUniqueFileName: false,
    overwriteFile: true,
  });
  if (!result.url) throw new Error('ImageKit upload returned no URL');
  return result.url;
}

export async function deleteFile(fileId: string): Promise<void> {
  await ik.deleteFile(fileId);
}