import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request, Response } from 'express';
import { Readable } from 'stream';

@Injectable()
export class SeaweedFsService {
  private readonly logger = new Logger(SeaweedFsService.name);
  private readonly filerUrl: string;

  constructor(private readonly configService: ConfigService) {
    this.filerUrl = (this.configService.get<string>('SEAWEEDFS_FILER_URL') || 'http://localhost:8888').replace(/\/+$/, '');
  }

  /**
   * Uploads a binary buffer to SeaweedFS Filer under /blobs/:blobPath.
   * Tries HTTP PUT first (standard SeaweedFS streaming upload), with fallback to multipart POST.
   */
  async uploadBlob(blobPath: string, buffer: Buffer, contentType: string = 'application/octet-stream'): Promise<boolean> {
    const cleanPath = blobPath.replace(/^\/+/, '');
    const targetUrl = `${this.filerUrl}/blobs/${cleanPath}`;

    try {
      // Method 1: HTTP PUT with raw binary stream and Content-Type header (standard for weed filer)
      const putRes = await fetch(targetUrl, {
        method: 'PUT',
        headers: {
          'Content-Type': contentType,
        },
        body: new Uint8Array(buffer),
      });

      if (putRes.ok) {
        return true;
      }

      // Method 2: Multipart Form-Data POST (form field 'file')
      const formData = new FormData();
      const blob = new Blob([new Uint8Array(buffer)], { type: contentType });
      formData.append('file', blob, cleanPath);

      const postRes = await fetch(targetUrl, {
        method: 'POST',
        body: formData,
      });

      if (postRes.ok) {
        return true;
      }

      const errText = await postRes.text().catch(() => '');
      this.logger.error(`SeaweedFS upload failed (${putRes.status} PUT, ${postRes.status} POST): ${errText}`);
      throw new Error(`SeaweedFS upload failed with status ${postRes.status}: ${errText}`);
    } catch (err: any) {
      this.logger.error(`Error uploading blob to SeaweedFS (${cleanPath}): ${err.message}`);
      throw err;
    }
  }

  /**
   * Retrieves raw bytes from SeaweedFS Filer.
   */
  async getBlob(blobPath: string): Promise<ArrayBuffer | null> {
    try {
      const cleanPath = blobPath.replace(/^\/+/, '');
      const targetUrl = `${this.filerUrl}/blobs/${cleanPath}`;
      const res = await fetch(targetUrl);
      if (!res.ok) return null;
      return await res.arrayBuffer();
    } catch (err: any) {
      this.logger.error(`Error fetching blob from SeaweedFS (${blobPath}): ${err.message}`);
      return null;
    }
  }

  /**
   * Streams a blob directly from SeaweedFS to the Express client response.
   * Supports HTTP 206 Partial Content (Range requests) for video scrubbing & audio streaming,
   * as well as Content-Length, ETag, and Cache-Control headers.
   */
  async streamBlob(
    blobPath: string,
    req: Request,
    res: Response,
    fallbackMime: string = 'application/octet-stream'
  ): Promise<boolean> {
    try {
      const cleanPath = blobPath.replace(/^\/+/, '');
      const targetUrl = `${this.filerUrl}/blobs/${cleanPath}`;

      const forwardHeaders: Record<string, string> = {};
      if (req.headers.range) {
        forwardHeaders['Range'] = req.headers.range as string;
      }

      const upstream = await fetch(targetUrl, {
        headers: forwardHeaders,
      });

      if (!upstream.ok) {
        return false;
      }

      // Set response status (200 OK or 206 Partial Content)
      res.status(upstream.status);

      // Forward relevant headers from SeaweedFS
      const headerKeys = [
        'content-type',
        'content-length',
        'content-range',
        'accept-ranges',
        'etag',
        'last-modified',
      ];
      for (const [key, value] of upstream.headers.entries()) {
        if (headerKeys.includes(key.toLowerCase())) {
          res.setHeader(key, value);
        }
      }

      if (!res.getHeader('content-type')) {
        res.setHeader('Content-Type', fallbackMime);
      }
      if (!res.getHeader('accept-ranges')) {
        res.setHeader('Accept-Ranges', 'bytes');
      }

      res.setHeader('Cache-Control', 'public, max-age=86400');
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');

      if (upstream.body) {
        Readable.fromWeb(upstream.body as any).pipe(res);
      } else {
        res.end();
      }

      return true;
    } catch (err: any) {
      this.logger.error(`Error streaming blob from SeaweedFS (${blobPath}): ${err.message}`);
      return false;
    }
  }

  /**
   * Deletes a blob from SeaweedFS Filer.
   */
  async deleteBlob(blobPath: string): Promise<boolean> {
    try {
      const cleanPath = blobPath.replace(/^\/+/, '');
      const targetUrl = `${this.filerUrl}/blobs/${cleanPath}`;
      const res = await fetch(targetUrl, { method: 'DELETE' });
      return res.ok;
    } catch (err: any) {
      this.logger.error(`Error deleting blob from SeaweedFS (${blobPath}): ${err.message}`);
      return false;
    }
  }

  /**
   * Checks if a blob exists in SeaweedFS.
   */
  async hasBlob(blobPath: string): Promise<boolean> {
    try {
      const cleanPath = blobPath.replace(/^\/+/, '');
      const targetUrl = `${this.filerUrl}/blobs/${cleanPath}`;
      const res = await fetch(targetUrl, { method: 'HEAD' });
      return res.ok;
    } catch (_) {
      return false;
    }
  }
}

