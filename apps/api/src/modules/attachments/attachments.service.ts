import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { Request, Response } from 'express';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { SeaweedFsService } from '../../infrastructure/seaweedfs/seaweedfs.service';

const AVATAR_DIR = process.env.AVATAR_DIR || path.join(process.cwd(), 'uploads', 'avatars');

@Injectable()
export class AttachmentsService {
  private readonly logger = new Logger(AttachmentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly seaweedFs: SeaweedFsService
  ) {}

  async uploadEncryptedAttachment(
    messageId: string,
    fileBuffer: Buffer,
    mimeType: string,
    checksum: string
  ) {
    const blobId = `enc-${Date.now()}-${Math.random().toString(36).substring(2, 10)}`;
    await this.seaweedFs.uploadBlob(blobId, fileBuffer, mimeType);

    const attachment = await this.prisma.attachment.create({
      data: {
        messageId,
        blobId,
        mimeType,
        fileSize: BigInt(fileBuffer.length),
        checksum
      }
    });

    return {
      id: attachment.id,
      blobId: attachment.blobId,
      mimeType: attachment.mimeType,
      fileSize: attachment.fileSize.toString(),
      checksum: attachment.checksum
    };
  }

  async getEncryptedBlob(blobId: string) {
    const blob = await this.seaweedFs.getBlob(blobId);
    if (!blob) {
      throw new NotFoundException('Encrypted attachment blob not found');
    }
    return blob;
  }

  async uploadAvatar(fileBuffer: Buffer, mimeType: string = 'image/jpeg', filename?: string) {
    const rawExt = filename?.split('.').pop()?.toLowerCase() || 'jpg';
    const cleanExt = rawExt.replace(/[^a-zA-Z0-9]/g, '') || 'jpg';
    const blobId = `avatar-${Date.now()}-${crypto.randomBytes(8).toString('hex')}.${cleanExt}`;

    let seaweedUploaded = false;
    if (this.seaweedFs) {
      try {
        await this.seaweedFs.uploadBlob(blobId, fileBuffer, mimeType);
        seaweedUploaded = true;
      } catch (err: any) {
        this.logger.warn(`SeaweedFS upload avatar skipped/failed: ${err.message}`);
      }
    }

    try {
      if (!fs.existsSync(AVATAR_DIR)) {
        fs.mkdirSync(AVATAR_DIR, { recursive: true });
      }
      const localFilePath = path.join(AVATAR_DIR, blobId);
      await fs.promises.writeFile(localFilePath, fileBuffer);
    } catch (fsErr: any) {
      this.logger.warn(`Local disk avatar backup skipped: ${fsErr.message}`);
    }

    return {
      url: `/attachments/avatar/${blobId}`,
      blobId,
      mimeType,
      size: fileBuffer.length
    };
  }

  async streamAvatar(blobId: string, req: Request, res: Response): Promise<boolean> {
    const safeBlobId = path.basename(blobId);
    const ext = safeBlobId.split('.').pop()?.toLowerCase() || 'jpg';
    let mime = 'image/jpeg';
    if (ext === 'png') mime = 'image/png';
    else if (ext === 'webp') mime = 'image/webp';
    else if (ext === 'gif') mime = 'image/gif';

    res.setHeader('Cache-Control', 'public, max-age=86400');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');

    if (this.seaweedFs) {
      const streamed = await this.seaweedFs.streamBlob(safeBlobId, req, res, mime);
      if (streamed) return true;
    }

    const candidateDirs = [
      AVATAR_DIR,
      '/app/uploads/avatars',
      '/app/apps/api/uploads/avatars',
      path.join(process.cwd(), 'uploads', 'avatars'),
    ].filter(Boolean) as string[];

    for (const dir of candidateDirs) {
      const localFilePath = path.join(dir, safeBlobId);
      if (fs.existsSync(localFilePath)) {
        res.setHeader('Content-Type', mime);
        fs.createReadStream(localFilePath).pipe(res);
        return true;
      }
    }

    return false;
  }
}
