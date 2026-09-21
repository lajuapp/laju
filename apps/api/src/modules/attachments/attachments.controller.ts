import {
  Controller,
  Post,
  Get,
  Param,
  Body,
  UseGuards,
  Res,
  HttpStatus
} from '@nestjs/common';
import { Response } from 'express';
import { AttachmentsService } from './attachments.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@Controller('attachments')
@UseGuards(JwtAuthGuard)
export class AttachmentsController {
  constructor(private readonly attachmentsService: AttachmentsService) {}

  @Post(':messageId')
  async upload(
    @Param('messageId') messageId: string,
    @Body() body: { base64Data: string; mimeType: string; checksum: string }
  ) {
    const buffer = Buffer.from(body.base64Data, 'base64');
    return this.attachmentsService.uploadEncryptedAttachment(
      messageId,
      buffer,
      body.mimeType || 'application/octet-stream',
      body.checksum
    );
  }

  @Get(':blobId')
  async download(@Param('blobId') blobId: string, @Res() res: Response) {
    const data = await this.attachmentsService.getEncryptedBlob(blobId);
    res.setHeader('Content-Type', 'application/octet-stream');
    return res.status(HttpStatus.OK).send(Buffer.from(data));
  }
}
