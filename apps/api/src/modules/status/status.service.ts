import { Injectable, NotFoundException, ForbiddenException, BadRequestException, Optional, Logger, HttpStatus, InternalServerErrorException, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { Request, Response } from 'express';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { SeaweedFsService } from '../../infrastructure/seaweedfs/seaweedfs.service';
import { CreateStatusDto, StatusTypeDto } from './dto/status.dto';

const STATUS_MEDIA_DIR = process.env.STATUS_MEDIA_DIR || path.join(process.cwd(), 'uploads', 'status-media');

@Injectable()
export class StatusService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(StatusService.name);
  private cleanupInterval?: NodeJS.Timeout;

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    @Optional() private readonly seaweedFs?: SeaweedFsService
  ) {}

  onModuleInit() {
    this.cleanupExpiredStatuses().catch((err) => {
      this.logger.error(`Error in startup status cleanup: ${err.message}`);
    });
    this.cleanupInterval = setInterval(() => {
      this.cleanupExpiredStatuses().catch((err) => {
        this.logger.error(`Error in periodic status cleanup: ${err.message}`);
      });
    }, 15 * 60 * 1000); // Check every 15 minutes
  }

  onModuleDestroy() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
    }
  }

  private extractBlobId(urlOrPath?: string | null): string | null {
    if (!urlOrPath) return null;
    const match = urlOrPath.match(/(?:asset-|status-|enc-|laju-)[a-zA-Z0-9_.-]+/);
    return match ? match[0] : null;
  }

  async cleanupExpiredStatuses(): Promise<number> {
    const now = new Date();
    const expired = await this.prisma.userStatusStory.findMany({
      where: {
        expiresAt: { lte: now }
      },
      select: {
        id: true,
        type: true,
        content: true
      }
    });

    if (expired.length === 0) return 0;

    let mediaCleaned = 0;
    for (const story of expired) {
      const blobId = this.extractBlobId(story.content);
      if (blobId) {
        if (this.seaweedFs) {
          try {
            await this.seaweedFs.deleteBlob(blobId);
            mediaCleaned++;
          } catch (_) {}
        }
        try {
          const localPath = path.join(STATUS_MEDIA_DIR, blobId);
          if (fs.existsSync(localPath)) {
            await fs.promises.unlink(localPath);
          }
        } catch (_) {}
      }
    }

    const storyIds = expired.map((s) => s.id);
    await this.prisma.statusStoryView.deleteMany({
      where: { storyId: { in: storyIds } }
    }).catch(() => {});
    await this.prisma.userStatusStory.deleteMany({
      where: { id: { in: storyIds } }
    }).catch(() => {});

    this.logger.log(`Pembersihan otomatis: menghapus ${expired.length} status kedaluwarsa & ${mediaCleaned} berkas media SeaweedFS.`);
    return expired.length;
  }

  async createStatus(userId: string, dto: CreateStatusDto) {
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours expiry
    const created = await this.prisma.userStatusStory.create({
      data: {
        userId,
        type: dto.type || StatusTypeDto.TEXT,
        content: dto.content,
        caption: dto.caption,
        backgroundColor: dto.backgroundColor,
        fontStyle: dto.fontStyle,
        expiresAt
      },
      include: {
        user: {
          select: {
            id: true,
            username: true
          }
        },
        views: true
      }
    });

    // Broadcast STATUS_UPDATE in real-time to active contacts & sender's devices
    try {
      const myConversations = await this.prisma.conversationMember.findMany({
        where: { userId, leftAt: null },
        select: { conversationId: true }
      });
      const convIds = myConversations.map((c) => c.conversationId);
      const contactMembers = await this.prisma.conversationMember.findMany({
        where: {
          conversationId: { in: convIds },
          userId: { not: userId },
          leftAt: null
        },
        select: { userId: true },
        distinct: ['userId']
      });

      const publisher = this.redis.getClient();
      if (publisher) {
        const payload = JSON.stringify({
          type: 'STATUS_UPDATE',
          userId,
          username: created.user?.username,
          statusId: created.id,
          action: 'CREATED',
          createdAt: created.createdAt
        });
        publisher.publish(`user:${userId}`, payload).catch(() => {});
        for (const m of contactMembers) {
          publisher.publish(`user:${m.userId}`, payload).catch(() => {});
        }
      }
    } catch (_) {}

    return created;
  }

  async getMyStatuses(userId: string) {
    const now = new Date();
    const stories = await this.prisma.userStatusStory.findMany({
      where: {
        userId,
        expiresAt: { gt: now }
      },
      orderBy: { createdAt: 'asc' },
      include: {
        views: {
          orderBy: { viewedAt: 'desc' },
          include: {
            viewer: {
              select: {
                id: true,
                username: true,
                phoneNumber: true
              }
            }
          }
        }
      }
    });

    // Enrich views with avatars
    return Promise.all(
      stories.map(async (story) => {
        const enrichedViews = await Promise.all(
          story.views.map(async (v) => {
            const avatarUrl = await this.redis.get(`user:${v.viewerId}:avatar`);
            return {
              ...v,
              viewer: {
                ...v.viewer,
                avatarUrl
              }
            };
          })
        );
        return {
          ...story,
          views: enrichedViews
        };
      })
    );
  }

  async getContactsStatuses(userId: string) {
    const now = new Date();

    // 1. Get contacts: users who share any conversation with current user
    const myConversations = await this.prisma.conversationMember.findMany({
      where: { userId, leftAt: null },
      select: { conversationId: true }
    });
    const convIds = myConversations.map((c) => c.conversationId);

    const contactMembers = await this.prisma.conversationMember.findMany({
      where: {
        conversationId: { in: convIds },
        userId: { not: userId },
        leftAt: null
      },
      select: { userId: true },
      distinct: ['userId']
    });

    let contactUserIds = contactMembers.map((m) => m.userId);

    // If user has no active conversation partners yet, also discover other active users
    if (contactUserIds.length === 0) {
      const activeUsers = await this.prisma.user.findMany({
        where: { id: { not: userId }, status: 'ACTIVE' },
        select: { id: true },
        take: 100
      });
      contactUserIds = activeUsers.map((u) => u.id);
    }

    if (contactUserIds.length === 0) {
      return [];
    }

    // 2. Fetch all active stories from those contacts
    const stories = await this.prisma.userStatusStory.findMany({
      where: {
        userId: { in: contactUserIds },
        expiresAt: { gt: now }
      },
      orderBy: { createdAt: 'asc' },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            phoneNumber: true
          }
        },
        views: {
          where: { viewerId: userId }
        }
      }
    });

    // 3. Group stories by user
    const userStoryMap = new Map<string, any>();
    for (const story of stories) {
      if (!userStoryMap.has(story.userId)) {
        const avatarUrl = await this.redis.get(`user:${story.userId}:avatar`);
        userStoryMap.set(story.userId, {
          userId: story.userId,
          username: story.user.username,
          phoneNumber: story.user.phoneNumber,
          avatarUrl,
          stories: []
        });
      }
      userStoryMap.get(story.userId).stories.push(story);
    }

    return Array.from(userStoryMap.values());
  }

  async markStatusViewed(userId: string, storyId: string) {
    const story = await this.prisma.userStatusStory.findUnique({
      where: { id: storyId }
    });
    if (!story) {
      throw new NotFoundException('Story not found');
    }

    return this.prisma.statusStoryView.upsert({
      where: {
        storyId_viewerId: {
          storyId,
          viewerId: userId
        }
      },
      update: {
        viewedAt: new Date()
      },
      create: {
        storyId,
        viewerId: userId
      }
    });
  }

  async getStatusViewers(userId: string, storyId: string) {
    const story = await this.prisma.userStatusStory.findUnique({
      where: { id: storyId }
    });
    if (!story) {
      throw new NotFoundException('Story not found');
    }
    if (story.userId !== userId) {
      throw new ForbiddenException('Cannot view viewers of another user story');
    }

    const views = await this.prisma.statusStoryView.findMany({
      where: { storyId },
      orderBy: { viewedAt: 'desc' },
      include: {
        viewer: {
          select: {
            id: true,
            username: true,
            phoneNumber: true
          }
        }
      }
    });

    return Promise.all(
      views.map(async (v) => {
        const avatarUrl = await this.redis.get(`user:${v.viewerId}:avatar`);
        return {
          id: v.id,
          storyId: v.storyId,
          viewerId: v.viewerId,
          reaction: v.reaction,
          viewedAt: v.viewedAt,
          viewer: {
            ...v.viewer,
            avatarUrl
          }
        };
      })
    );
  }

  async reactToStatus(userId: string, storyId: string, emoji: string) {
    const story = await this.prisma.userStatusStory.findUnique({
      where: { id: storyId }
    });
    if (!story) {
      throw new NotFoundException('Story not found');
    }

    return this.prisma.statusStoryView.upsert({
      where: {
        storyId_viewerId: {
          storyId,
          viewerId: userId
        }
      },
      update: {
        reaction: emoji,
        viewedAt: new Date()
      },
      create: {
        storyId,
        viewerId: userId,
        reaction: emoji
      }
    });
  }

  async deleteStatus(userId: string, storyId: string) {
    const story = await this.prisma.userStatusStory.findUnique({
      where: { id: storyId }
    });
    if (!story) {
      throw new NotFoundException('Story not found');
    }
    if (story.userId !== userId) {
      throw new ForbiddenException('Cannot delete another user story');
    }

    const blobId = this.extractBlobId(story.content);
    if (blobId) {
      if (this.seaweedFs) {
        try {
          await this.seaweedFs.deleteBlob(blobId);
        } catch (_) {}
      }
      try {
        const localPath = path.join(STATUS_MEDIA_DIR, blobId);
        if (fs.existsSync(localPath)) {
          await fs.promises.unlink(localPath);
        }
      } catch (_) {}
    }

    await this.prisma.statusStoryView.deleteMany({
      where: { storyId }
    }).catch(() => {});

    await this.prisma.userStatusStory.delete({
      where: { id: storyId }
    });

    if (story) {
      try {
        const myConversations = await this.prisma.conversationMember.findMany({
          where: { userId: story.userId, leftAt: null },
          select: { conversationId: true }
        });
        const convIds = myConversations.map((c) => c.conversationId);
        const contactMembers = await this.prisma.conversationMember.findMany({
          where: {
            conversationId: { in: convIds },
            userId: { not: story.userId },
            leftAt: null
          },
          select: { userId: true },
          distinct: ['userId']
        });

        const publisher = this.redis.getClient();
        if (publisher) {
          const payload = JSON.stringify({
            type: 'STATUS_UPDATE',
            userId: story.userId,
            statusId: storyId,
            action: 'DELETED'
          });
          publisher.publish(`user:${story.userId}`, payload).catch(() => {});
          for (const m of contactMembers) {
            publisher.publish(`user:${m.userId}`, payload).catch(() => {});
          }
        }
      } catch (_) {}
    }

    return { success: true };
  }

  async getOfficialStatuses(userId: string) {
    const announcements = await this.prisma.systemAnnouncement.findMany({
      where: { isActive: true },
      orderBy: { createdAt: 'asc' }
    });

    const now = new Date();
    const results: any[] = [];

    for (const a of announcements) {
      let meta: any = {};
      let target: any = { targetType: 'ALL' };
      let isViewed = false;

      if (this.redis) {
        try {
          const metaStr = await this.redis.get(`announcement:${a.id}:meta`);
          if (metaStr) meta = JSON.parse(metaStr);
        } catch (_) {}

        try {
          const targetMeta = await this.redis.get(`announcement:${a.id}:target`);
          if (targetMeta) target = JSON.parse(targetMeta);
        } catch (_) {}

        try {
          const viewed = await this.redis.getClient().sismember(`announcement:${a.id}:views`, userId);
          isViewed = viewed === 1;
        } catch (_) {}
      }

      // Check target audience
      if (target.targetType !== 'ALL') {
        if (!Array.isArray(target.targetUserIds) || !target.targetUserIds.includes(userId)) {
          continue; // not for this user
        }
      }

      // Check expiration
      if (meta.expiresAt) {
        const exp = new Date(meta.expiresAt);
        if (now > exp) {
          continue; // expired
        }
      }

      results.push({
        id: a.id,
        title: a.title,
        content: a.content,
        type: a.type,
        mediaType: meta.mediaType || 'TEXT',
        mediaUrl: meta.mediaUrl || null,
        backgroundColor: meta.backgroundColor || '#0F3E37',
        actionUrl: meta.actionUrl || null,
        actionTitle: meta.actionTitle || null,
        createdAt: a.createdAt,
        expiresAt: meta.expiresAt || null,
        isViewed
      });
    }

    return results;
  }

  async markOfficialStatusViewed(userId: string, announcementId: string) {
    if (this.redis) {
      try {
        await this.redis.getClient().sadd(`announcement:${announcementId}:views`, userId);
      } catch (_) {}
    }
    return { success: true };
  }

  async uploadMedia(
    userId: string,
    body: { filename: string; mimeType: string; base64Data: string }
  ) {
    if (!body?.base64Data) {
      throw new BadRequestException('base64Data is required');
    }

    const rawData = body.base64Data.includes(',')
      ? body.base64Data.split(',')[1]
      : body.base64Data;
    const buffer = Buffer.from(rawData, 'base64');
    const rawExt = body.filename?.split('.').pop()?.toLowerCase() || 'mp4';
    const cleanExt = rawExt.replace(/[^a-zA-Z0-9]/g, '') || 'mp4';
    const blobId = `status-${crypto.randomBytes(12).toString('hex')}.${cleanExt}`;
    const contentType = body.mimeType || (cleanExt === 'mp4' ? 'video/mp4' : 'image/jpeg');

    // 1. Primary: Persist directly to SeaweedFS Object Storage
    let seaweedUploaded = false;
    if (this.seaweedFs) {
      try {
        await this.seaweedFs.uploadBlob(blobId, buffer, contentType);
        seaweedUploaded = true;
      } catch (swErr: any) {
        this.logger.error(`Failed to upload status media to SeaweedFS: ${swErr.message}`);
      }
    }

    // 2. Also keep local copy as cache/backup if directory is available
    try {
      if (!fs.existsSync(STATUS_MEDIA_DIR)) {
        fs.mkdirSync(STATUS_MEDIA_DIR, { recursive: true });
      }
      const localFilePath = path.join(STATUS_MEDIA_DIR, blobId);
      await fs.promises.writeFile(localFilePath, buffer);
    } catch (fsErr: any) {
      this.logger.warn(`Notice: Local status disk backup skipped: ${fsErr.message}`);
    }

    if (!seaweedUploaded && !fs.existsSync(path.join(STATUS_MEDIA_DIR, blobId))) {
      throw new InternalServerErrorException('Gagal menyimpan berkas media status');
    }

    return {
      url: `/status/media/${blobId}`,
      blobId,
      filename: body.filename,
      size: buffer.length
    };
  }

  async streamStatusMedia(blobId: string, req: Request, res: Response) {
    const safeBlobId = path.basename(blobId);
    if (!safeBlobId || safeBlobId.includes('..')) {
      return res.status(HttpStatus.BAD_REQUEST).json({ error: 'Invalid blob ID' });
    }

    const ext = safeBlobId.split('.').pop()?.toLowerCase() || 'mp4';
    let mime = 'video/mp4';
    if (ext === 'jpg' || ext === 'jpeg') mime = 'image/jpeg';
    else if (ext === 'png') mime = 'image/png';
    else if (ext === 'webp') mime = 'image/webp';
    else if (ext === 'gif') mime = 'image/gif';
    else if (ext === 'mp4') mime = 'video/mp4';
    else if (ext === 'webm') mime = 'video/webm';
    else if (ext === 'mov') mime = 'video/quicktime';

    // 1. Primary: Stream directly from SeaweedFS Object Storage
    if (this.seaweedFs) {
      const streamed = await this.seaweedFs.streamBlob(safeBlobId, req, res, mime);
      if (streamed) return;
    }

    // 2. Fallback: Check local disk directories (legacy migration support)
    const candidateDirs = [
      STATUS_MEDIA_DIR,
      '/app/uploads/status-media',
      '/app/apps/api/uploads/status-media',
      path.join(process.cwd(), 'uploads', 'status-media'),
    ].filter(Boolean) as string[];

    for (const dir of candidateDirs) {
      const localFilePath = path.join(dir, safeBlobId);
      if (fs.existsSync(localFilePath)) {
        try {
          // Auto-migrate legacy file to SeaweedFS in background
          if (this.seaweedFs) {
            fs.promises.readFile(localFilePath)
              .then(buf => this.seaweedFs?.uploadBlob(safeBlobId, buf, mime))
              .catch(() => {});
          }

          const stat = fs.statSync(localFilePath);
          const fileSize = stat.size;
          const range = req.headers.range;

          res.setHeader('Accept-Ranges', 'bytes');
          res.setHeader('Cache-Control', 'public, max-age=86400');
          res.setHeader('Access-Control-Allow-Origin', '*');
          res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');

          if (range) {
            const parts = range.replace(/bytes=/, '').split('-');
            const start = parseInt(parts[0], 10);
            const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;

            if (start >= fileSize || end >= fileSize || start > end) {
              res.setHeader('Content-Range', `bytes */${fileSize}`);
              return res.status(HttpStatus.REQUESTED_RANGE_NOT_SATISFIABLE).end();
            }

            const chunksize = end - start + 1;
            const stream = fs.createReadStream(localFilePath, { start, end });
            res.writeHead(HttpStatus.PARTIAL_CONTENT, {
              'Content-Range': `bytes ${start}-${end}/${fileSize}`,
              'Accept-Ranges': 'bytes',
              'Content-Length': chunksize,
              'Content-Type': mime,
              'Access-Control-Allow-Origin': '*',
              'Cross-Origin-Resource-Policy': 'cross-origin',
            });
            return stream.pipe(res);
          }

          res.setHeader('Content-Type', mime);
          res.setHeader('Content-Length', fileSize);
          const stream = fs.createReadStream(localFilePath);
          return stream.pipe(res);
        } catch (err: any) {
          this.logger.error(`Error reading local status file: ${err.message}`);
        }
      }
    }

    return res.status(HttpStatus.NOT_FOUND).json({ error: 'Status media not found' });
  }
}

