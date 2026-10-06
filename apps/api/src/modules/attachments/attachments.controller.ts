import {
  Controller,
  Post,
  Get,
  Param,
  Body,
  UseGuards,
  Req,
  Res,
  HttpStatus,
  BadRequestException,
  NotFoundException
} from '@nestjs/common';
import { Request, Response } from 'express';
import { AttachmentsService } from './attachments.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@Controller('attachments')
export class AttachmentsController {
  constructor(private readonly attachmentsService: AttachmentsService) {}

  @Post('avatar')
  @UseGuards(JwtAuthGuard)
  async uploadAvatar(
    @Body() body: { base64Data: string; filename?: string; mimeType?: string }
  ) {
    if (!body?.base64Data) {
      throw new BadRequestException('base64Data berkas gambar avatar wajib disertakan');
    }
    const rawData = body.base64Data.includes(',')
      ? body.base64Data.split(',')[1]
      : body.base64Data;
    const buffer = Buffer.from(rawData, 'base64');
    if (buffer.length < 50) {
      throw new BadRequestException('Berkas avatar tidak valid atau terlalu kecil');
    }
    return this.attachmentsService.uploadAvatar(
      buffer,
      body.mimeType || 'image/jpeg',
      body.filename || 'avatar.jpg'
    );
  }

  @Get('avatar/:blobId')
  async getAvatar(
    @Param('blobId') blobId: string,
    @Req() req: Request,
    @Res() res: Response
  ) {
    const success = await this.attachmentsService.streamAvatar(blobId, req, res);
    if (!success) {
      return res.status(HttpStatus.NOT_FOUND).json({ error: 'Avatar blob not found' });
    }
  }

  @Post(':messageId')
  @UseGuards(JwtAuthGuard)
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
  @UseGuards(JwtAuthGuard)
  async download(@Param('blobId') blobId: string, @Res() res: Response) {
    const data = await this.attachmentsService.getEncryptedBlob(blobId);
    res.setHeader('Content-Type', 'application/octet-stream');
    return res.status(HttpStatus.OK).send(Buffer.from(data));
  }
}
