import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class SeaweedFsService {
  private readonly logger = new Logger(SeaweedFsService.name);
  private readonly filerUrl: string;

  constructor(private readonly configService: ConfigService) {
    this.filerUrl = this.configService.get<string>('SEAWEEDFS_FILER_URL') || 'http://localhost:8888';
  }

  async uploadBlob(path: string, buffer: Buffer, contentType: string = 'application/octet-stream'): Promise<boolean> {
    try {
      const targetUrl = `${this.filerUrl}/blobs/${path}`;
      const res = await fetch(targetUrl, {
        method: 'POST',
        headers: {
          'Content-Type': contentType
        },
        body: new Uint8Array(buffer)
      });
      return res.ok;
    } catch (err: any) {
      this.logger.error(`Error uploading blob to SeaweedFS: ${err.message}`);
      throw err;
    }
  }

  async getBlob(path: string): Promise<ArrayBuffer | null> {
    try {
      const targetUrl = `${this.filerUrl}/blobs/${path}`;
      const res = await fetch(targetUrl);
      if (!res.ok) return null;
      return await res.arrayBuffer();
    } catch (err: any) {
      this.logger.error(`Error fetching blob from SeaweedFS: ${err.message}`);
      return null;
    }
  }
}
