import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { SeaweedFsService } from '../../infrastructure/seaweedfs/seaweedfs.service';

@Injectable()
export class AttachmentsService {
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
}
