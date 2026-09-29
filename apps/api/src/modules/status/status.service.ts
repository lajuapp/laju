import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { CreateStatusDto, StatusTypeDto } from './dto/status.dto';

@Injectable()
export class StatusService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService
  ) {}

  async createStatus(userId: string, dto: CreateStatusDto) {
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours expiry
    return this.prisma.userStatusStory.create({
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

    await this.prisma.userStatusStory.delete({
      where: { id: storyId }
    });

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
}

