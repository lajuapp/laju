import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Optional
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { GotifyService } from '../../infrastructure/gotify/gotify.service';
import { CallSignalingGateway } from './calls.gateway';

@Injectable()
export class CallsService {
  // In-memory real-time media exchange for zero-latency audio & video streaming
  private audioBuffers = new Map<string, Map<string, string[]>>(); // callId -> (userId -> chunks[])
  private videoFrames = new Map<string, Map<string, { frame: string; updatedAt: number }>>(); // callId -> (userId -> frame)
  private callParticipantsCache = new Map<string, Set<string>>(); // callId -> Set<userId>

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    @Optional() private readonly gotifyService?: GotifyService,
    @Optional() private readonly callGateway?: CallSignalingGateway
  ) {}

  async createCall(callerUserId: string, callerDeviceId: string, calleeUserId: string, isVideo?: boolean) {
    if (!calleeUserId || typeof calleeUserId !== 'string' || calleeUserId.startsWith('conv-') || calleeUserId.startsWith('grp-') || calleeUserId === 'm-you') {
      throw new BadRequestException('ID kontak tujuan panggilan tidak valid');
    }

    return this.prisma.$transaction(async (tx) => {
      // Find target callee user by ID, username, email, phoneNumber
      const cleanUsername = calleeUserId.startsWith('@') ? calleeUserId.substring(1) : calleeUserId;
      const digitsOnly = calleeUserId.replace(/\D/g, '');

      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(calleeUserId);
      const targetUser = await tx.user.findFirst({
        where: {
          OR: [
            ...(isUuid ? [{ id: calleeUserId }] : []),
            { username: { equals: calleeUserId, mode: 'insensitive' } },
            { username: { equals: cleanUsername, mode: 'insensitive' } },
            { email: { equals: calleeUserId, mode: 'insensitive' } },
            { phoneNumber: calleeUserId },
            ...(digitsOnly.length >= 6 ? [
              { phoneNumber: `+${digitsOnly}` },
              { phoneNumber: digitsOnly },
              { phoneNumber: { contains: digitsOnly } }
            ] : [])
          ]
        }
      });

      if (!targetUser) {
        throw new NotFoundException(`Kontak tujuan panggilan "${calleeUserId}" tidak ditemukan di sistem LAJU`);
      }

      if (targetUser.id === callerUserId) {
        throw new BadRequestException('Tidak dapat melakukan panggilan ke akun sendiri');
      }

      const resolvedCalleeUserId = targetUser.id;

      const call = await tx.call.create({
        data: {
          initiatorId: callerUserId,
          state: 'INITIATED'
        }
      });

      await tx.callParticipant.create({
        data: {
          callId: call.id,
          userId: callerUserId,
          deviceId: callerDeviceId,
          state: 'CONNECTED',
          joinedAt: new Date()
        }
      });

      // Find callee device
      const calleeDevice = await tx.device.findFirst({
        where: { userId: resolvedCalleeUserId },
        orderBy: { lastSeenAt: 'desc' }
      });

      // ALWAYS create callParticipant with state 'RINGING' for callee so incoming call query succeeds
      await tx.callParticipant.create({
        data: {
          callId: call.id,
          userId: resolvedCalleeUserId,
          deviceId: calleeDevice?.id || `dev-${resolvedCalleeUserId}`,
          state: 'RINGING',
          joinedAt: new Date()
        }
      });

      // Store call metadata (e.g. isVideo) in Redis
      await this.redis.set(
        `call:${call.id}:meta`,
        JSON.stringify({ isVideo: !!isVideo }),
        'EX',
        3600
      );

      const caller = await tx.user.findUnique({
        where: { id: callerUserId },
        select: { username: true }
      });

      const incomingPayload = {
        type: 'CALL_INCOMING',
        callId: call.id,
        initiatorId: callerUserId,
        initiatorName: caller?.username || 'Kontak',
        callerDeviceId,
        isVideo: !!isVideo
      };

      await this.redis.publish(
        `user:${resolvedCalleeUserId}`,
        JSON.stringify(incomingPayload)
      );

      // Notify callee via WebSocket gateway directly (instant, no polling needed)
      this.callGateway?.notifyUser(resolvedCalleeUserId, incomingPayload);

      // Trigger high-priority push notification (Priority 8 - Call Wakeup)
      if (this.gotifyService) {
        this.gotifyService.sendPushNotification({
          targetToken: calleeDevice?.pushToken || undefined,
          title: `Panggilan Masuk dari ${caller?.username || 'Kontak'}`,
          message: isVideo ? 'Panggilan Video Masuk' : 'Panggilan Suara Masuk',
          conversationId: call.id,
          priority: 8
        }).catch(() => {});
      }

      return call;
    });
  }

  async acceptCall(calleeUserId: string, calleeDeviceId: string, callId: string) {
    const participant = await this.prisma.callParticipant.findFirst({
      where: { callId, userId: calleeUserId }
    });
    if (!participant) {
      throw new ForbiddenException('Not a participant in this call');
    }

    await this.prisma.$transaction([
      this.prisma.call.update({
        where: { id: callId },
        data: { state: 'CONNECTED' }
      }),
      this.prisma.callParticipant.update({
        where: { id: participant.id },
        data: { state: 'CONNECTED', joinedAt: new Date(), deviceId: calleeDeviceId }
      })
    ]);

    const acceptedPayload = {
      type: 'CALL_ACCEPTED',
      callId,
      participantId: calleeUserId,
      deviceId: calleeDeviceId
    };

    await this.redis.publish(`call:${callId}`, JSON.stringify(acceptedPayload));

    // Notify all call participants via WebSocket gateway
    this.callGateway?.notifyCallRoom(callId, acceptedPayload);

    // Also notify the initiator directly if known
    try {
      const call = await this.prisma.call.findUnique({ where: { id: callId } });
      if (call?.initiatorId) {
        this.callGateway?.notifyUser(call.initiatorId, acceptedPayload);
      }
    } catch (_) {}

    return { success: true };
  }

  async rejectCall(userId: string, callId: string) {
    await this.prisma.$transaction([
      this.prisma.call.update({
        where: { id: callId },
        data: { state: 'REJECTED', endedAt: new Date() }
      }),
      this.prisma.callParticipant.updateMany({
        where: { callId, userId },
        data: { state: 'REJECTED', leftAt: new Date() }
      })
    ]);

    const rejectedPayload = {
      type: 'CALL_REJECTED',
      callId,
      userId
    };

    await this.redis.publish(`call:${callId}`, JSON.stringify(rejectedPayload));

    try {
      const participants = await this.prisma.callParticipant.findMany({
        where: { callId },
        select: { userId: true }
      });
      for (const p of participants) {
        await this.redis.publish(`user:${p.userId}`, JSON.stringify(rejectedPayload));
        this.callGateway?.notifyUser(p.userId, rejectedPayload);
      }
    } catch (_) {}

    return { success: true };
  }

  async endCall(userId: string, callId: string) {
    await this.prisma.$transaction([
      this.prisma.call.update({
        where: { id: callId },
        data: { state: 'ENDED', endedAt: new Date() }
      }),
      this.prisma.callParticipant.updateMany({
        where: { callId, userId },
        data: { leftAt: new Date() }
      })
    ]);

    const endedPayload = {
      type: 'CALL_ENDED',
      callId,
      userId
    };

    await this.redis.publish(`call:${callId}`, JSON.stringify(endedPayload));

    try {
      const participants = await this.prisma.callParticipant.findMany({
        where: { callId },
        select: { userId: true }
      });
      for (const p of participants) {
        await this.redis.publish(`user:${p.userId}`, JSON.stringify(endedPayload));
        this.callGateway?.notifyUser(p.userId, endedPayload);
      }
    } catch (_) {}

    this.audioBuffers.delete(callId);
    this.videoFrames.delete(callId);
    this.callParticipantsCache.delete(callId);

    return { success: true };
  }

  async exchangeSignal(userId: string, deviceId: string, callId: string, signalData: any, clientIp?: string) {
    const participant = await this.prisma.callParticipant.findFirst({
      where: { callId, userId }
    });
    if (!participant) {
      throw new ForbiddenException('Not a participant in this call');
    }

    const payload = {
      type: 'CALL_SIGNAL',
      callId,
      fromUserId: userId,
      fromDeviceId: deviceId,
      clientIp: clientIp || null,
      signal: signalData,
      createdAt: Date.now()
    };

    try {
      const redisClient = this.redis.getClient();
      if (redisClient) {
        await redisClient.rpush(`call:${callId}:signals`, JSON.stringify(payload));
        await redisClient.expire(`call:${callId}:signals`, 3600);
      }
    } catch (_) {}

    await this.redis.publish(`call:${callId}`, JSON.stringify(payload));

    // Broadcast signal via WebSocket gateway for real-time delivery
    this.callGateway?.notifyCallRoom(callId, payload, undefined);

    return { success: true };
  }

  async getSignals(userId: string, callId: string) {
    const participant = await this.prisma.callParticipant.findFirst({
      where: { callId, userId }
    });
    if (!participant) {
      throw new ForbiddenException('Not a participant in this call');
    }

    try {
      const redisClient = this.redis.getClient();
      if (redisClient) {
        const rawSignals = await redisClient.lrange(`call:${callId}:signals`, 0, -1);
        return rawSignals.map((s) => {
          try {
            return JSON.parse(s);
          } catch {
            return null;
          }
        }).filter(Boolean);
      }
    } catch (_) {}

    return [];
  }

  private async verifyParticipantCached(callId: string, userId: string): Promise<boolean> {
    let participants = this.callParticipantsCache.get(callId);
    if (!participants) {
      const parts = await this.prisma.callParticipant.findMany({
        where: { callId },
        select: { userId: true }
      });
      participants = new Set(parts.map((p) => p.userId));
      this.callParticipantsCache.set(callId, participants);
    }
    return participants.has(userId);
  }

  private async getOtherParticipantId(callId: string, userId: string): Promise<string | null> {
    let participants = this.callParticipantsCache.get(callId);
    if (!participants) {
      const parts = await this.prisma.callParticipant.findMany({
        where: { callId },
        select: { userId: true }
      });
      participants = new Set(parts.map((p) => p.userId));
      this.callParticipantsCache.set(callId, participants);
    }
    for (const id of participants) {
      if (id !== userId) return id;
    }
    return null;
  }

  async pushAudioChunk(userId: string, callId: string, chunkBase64: string) {
    const isParticipant = await this.verifyParticipantCached(callId, userId);
    if (!isParticipant) {
      throw new ForbiddenException('Not a participant in this call');
    }

    // Fast in-memory buffer (<1ms, zero DB latency)
    let callQueues = this.audioBuffers.get(callId);
    if (!callQueues) {
      callQueues = new Map();
      this.audioBuffers.set(callId, callQueues);
    }
    let userQueue = callQueues.get(userId);
    if (!userQueue) {
      userQueue = [];
      callQueues.set(userId, userQueue);
    }
    userQueue.push(chunkBase64);
    if (userQueue.length > 30) {
      userQueue.shift();
    }

    // Non-blocking Redis sync if available
    try {
      const redisClient = this.redis.getClient();
      if (redisClient) {
        const key = `call:${callId}:audio:${userId}`;
        redisClient.rpush(key, chunkBase64).catch(() => {});
        redisClient.ltrim(key, -30, -1).catch(() => {});
        redisClient.expire(key, 10).catch(() => {});
      }
    } catch (_) {}

    return { success: true };
  }

  async getAudioChunks(userId: string, callId: string) {
    const otherUserId = await this.getOtherParticipantId(callId, userId);
    if (!otherUserId) {
      return { chunks: [] };
    }

    // Return from in-memory queue first (instant, guaranteed)
    const callQueues = this.audioBuffers.get(callId);
    if (callQueues) {
      const otherQueue = callQueues.get(otherUserId);
      if (otherQueue && otherQueue.length > 0) {
        const chunks = [...otherQueue];
        otherQueue.length = 0; // drain
        return { chunks };
      }
    }

    // Redis fallback
    try {
      const redisClient = this.redis.getClient();
      if (redisClient) {
        const key = `call:${callId}:audio:${otherUserId}`;
        const chunks = await redisClient.lrange(key, 0, -1);
        if (chunks.length > 0) {
          await redisClient.del(key);
        }
        return { chunks };
      }
    } catch (_) {}

    return { chunks: [] };
  }

  async pushVideoFrame(userId: string, callId: string, frameBase64: string) {
    const isParticipant = await this.verifyParticipantCached(callId, userId);
    if (!isParticipant) {
      throw new ForbiddenException('Not a participant in this call');
    }

    let callFrames = this.videoFrames.get(callId);
    if (!callFrames) {
      callFrames = new Map();
      this.videoFrames.set(callId, callFrames);
    }
    callFrames.set(userId, {
      frame: frameBase64,
      updatedAt: Date.now()
    });

    try {
      const redisClient = this.redis.getClient();
      if (redisClient) {
        const key = `call:${callId}:video:${userId}`;
        redisClient.set(key, frameBase64, 'EX', 6).catch(() => {});
      }
    } catch (_) {}

    return { success: true };
  }

  async getVideoFrame(userId: string, callId: string) {
    const otherUserId = await this.getOtherParticipantId(callId, userId);
    if (!otherUserId) {
      return { frame: null };
    }

    const callFrames = this.videoFrames.get(callId);
    if (callFrames) {
      const data = callFrames.get(otherUserId);
      if (data && (Date.now() - data.updatedAt) < 6000) {
        return { frame: data.frame, timestamp: data.updatedAt };
      }
    }

    try {
      const redisClient = this.redis.getClient();
      if (redisClient) {
        const key = `call:${callId}:video:${otherUserId}`;
        const frame = await redisClient.get(key);
        if (frame) {
          return { frame };
        }
      }
    } catch (_) {}

    return { frame: null };
  }

  async syncMediaStream(userId: string, callId: string, data: { audioChunk?: string; videoFrame?: string }) {
    if (data.audioChunk) {
      await this.pushAudioChunk(userId, callId, data.audioChunk);
    }
    if (data.videoFrame) {
      await this.pushVideoFrame(userId, callId, data.videoFrame);
    }

    const audio = await this.getAudioChunks(userId, callId);
    const video = await this.getVideoFrame(userId, callId);

    return {
      audioChunks: audio.chunks,
      videoFrame: video.frame
    };
  }

  async getIncomingCall(userId: string) {
    const participant = await this.prisma.callParticipant.findFirst({
      where: {
        userId,
        state: 'RINGING',
        call: {
          state: 'INITIATED'
        }
      },
      include: {
        call: true
      },
      orderBy: { joinedAt: 'desc' }
    });

    if (!participant) {
      return null;
    }

    const initiator = await this.prisma.user.findUnique({
      where: { id: participant.call.initiatorId },
      select: { id: true, username: true }
    });

    let isVideo = false;
    try {
      const meta = await this.redis.get(`call:${participant.callId}:meta`);
      if (meta) {
        const parsed = JSON.parse(meta);
        isVideo = !!parsed.isVideo;
      }
    } catch (_) {}

    return {
      callId: participant.callId,
      initiatorId: participant.call.initiatorId,
      initiatorName: initiator?.username || 'Kontak',
      isVideo,
      createdAt: participant.call.startedAt
    };
  }

  async getCallById(userId: string, callId: string) {
    const call = await this.prisma.call.findUnique({
      where: { id: callId },
      include: {
        participants: {
          include: {
            user: { select: { id: true, username: true, phoneNumber: true } }
          }
        }
      }
    });

    if (!call) {
      throw new NotFoundException('Call not found');
    }

    let isVideo = false;
    try {
      const meta = await this.redis.get(`call:${call.id}:meta`);
      if (meta) {
        const parsed = JSON.parse(meta);
        isVideo = !!parsed.isVideo;
      }
    } catch (_) {}

    return {
      id: call.id,
      initiatorId: call.initiatorId,
      state: call.state,
      startedAt: call.startedAt,
      endedAt: call.endedAt,
      isVideo,
      participants: call.participants.map((p) => ({
        id: p.id,
        userId: p.userId,
        username: p.user?.username,
        phoneNumber: p.user?.phoneNumber,
        state: p.state,
        joinedAt: p.joinedAt,
        leftAt: p.leftAt
      }))
    };
  }

  async getCallHistory(userId: string) {
    const calls = await this.prisma.call.findMany({
      where: {
        participants: {
          some: { userId }
        }
      },
      include: {
        participants: {
          include: {
            user: { select: { id: true, username: true, phoneNumber: true } }
          }
        }
      },
      orderBy: { startedAt: 'desc' },
      take: 50
    });

    return Promise.all(
      calls.map(async (call) => {
        let isVideo = false;
        try {
          const meta = await this.redis.get(`call:${call.id}:meta`);
          if (meta) {
            const parsed = JSON.parse(meta);
            isVideo = !!parsed.isVideo;
          }
        } catch (_) {}

        const isInitiator = call.initiatorId === userId;
        const otherParticipant = call.participants.find((p) => p.userId !== userId);
        const contactUser = isInitiator
          ? otherParticipant?.user
          : call.participants.find((p) => p.userId === call.initiatorId)?.user;

        return {
          id: call.id,
          initiatorId: call.initiatorId,
          isOutgoing: isInitiator,
          state: call.state,
          startedAt: call.startedAt,
          endedAt: call.endedAt,
          isVideo,
          contactId: contactUser?.id || (isInitiator ? otherParticipant?.userId : call.initiatorId),
          contactName: contactUser?.username || 'Kontak',
          contactPhone: contactUser?.phoneNumber
        };
      })
    );
  }
}
