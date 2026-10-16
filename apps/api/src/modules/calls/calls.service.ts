import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  Optional,
  Logger
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { GotifyService } from '../../infrastructure/gotify/gotify.service';
import { CallSignalingGateway } from './calls.gateway';

@Injectable()
export class CallsService {
  private readonly logger = new Logger(CallsService.name);
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

      const ringingCutoff = new Date(Date.now() - 65 * 1000);
      const connectedCutoff = new Date(Date.now() - 3600 * 1000);

      // Auto-expire any stale unanswered INITIATED calls older than 65s
      await tx.call.updateMany({
        where: {
          state: 'INITIATED',
          startedAt: { lt: ringingCutoff },
          participants: {
            some: { userId: { in: [resolvedCalleeUserId, callerUserId] } }
          }
        },
        data: { state: 'ENDED', endedAt: new Date() }
      });

      // 1. Check if callee is currently in an active or ringing call (Busy)
      const calleeActiveCall = await tx.callParticipant.findFirst({
        where: {
          userId: resolvedCalleeUserId,
          OR: [
            {
              state: 'CONNECTED',
              call: { state: 'CONNECTED', startedAt: { gte: connectedCutoff } }
            },
            {
              state: 'RINGING',
              call: { state: 'INITIATED', startedAt: { gte: ringingCutoff } }
            }
          ]
        }
      });

      if (calleeActiveCall) {
        throw new ConflictException('Pengguna sedang dalam panggilan lain (Sibuk)');
      }

      // 2. Check if caller is already in another call
      const callerActiveCall = await tx.callParticipant.findFirst({
        where: {
          userId: callerUserId,
          OR: [
            {
              state: 'CONNECTED',
              call: { state: 'CONNECTED', startedAt: { gte: connectedCutoff } }
            },
            {
              state: 'RINGING',
              call: { state: 'INITIATED', startedAt: { gte: ringingCutoff } }
            }
          ]
        }
      });

      if (callerActiveCall) {
        throw new ConflictException('Anda sedang dalam panggilan lain');
      }

      const call = await tx.call.create({
        data: {
          initiatorId: callerUserId,
          state: 'INITIATED'
        }
      });

      // Ensure caller device ID is safe and valid
      let safeCallerDeviceId = callerDeviceId;
      if (!safeCallerDeviceId) {
        const callerDevice = await tx.device.findFirst({
          where: { userId: callerUserId, status: 'ACTIVE' },
          orderBy: { lastSeenAt: 'desc' }
        });
        safeCallerDeviceId = callerDevice?.id || `dev-${callerUserId.substring(0, 8)}`;
      }

      await tx.callParticipant.create({
        data: {
          callId: call.id,
          userId: callerUserId,
          deviceId: safeCallerDeviceId,
          state: 'CONNECTED',
          joinedAt: new Date()
        }
      });

      // Find callee device
      const calleeDevice = await tx.device.findFirst({
        where: { userId: resolvedCalleeUserId },
        orderBy: { lastSeenAt: 'desc' }
      });

      let safeCalleeDeviceId = calleeDevice?.id || `dev-${resolvedCalleeUserId.substring(0, 8)}`;
      // Prevent unique constraint collision if both users share same device in test environment
      if (safeCalleeDeviceId === safeCallerDeviceId) {
        safeCalleeDeviceId = `${safeCalleeDeviceId}-callee`;
      }

      // ALWAYS create callParticipant with state 'RINGING' for callee so incoming call query succeeds
      await tx.callParticipant.create({
        data: {
          callId: call.id,
          userId: resolvedCalleeUserId,
          deviceId: safeCalleeDeviceId,
          state: 'RINGING',
          joinedAt: new Date()
        }
      });

      // Find or create personal conversation between caller and callee
      let conv = await tx.conversation.findFirst({
        where: {
          type: 'PERSONAL',
          AND: [
            { members: { some: { userId: callerUserId, leftAt: null } } },
            { members: { some: { userId: resolvedCalleeUserId, leftAt: null } } }
          ]
        }
      });

      if (!conv) {
        conv = await tx.conversation.create({
          data: {
            type: 'PERSONAL'
          }
        });
        await tx.conversationMember.createMany({
          data: [
            { conversationId: conv.id, userId: callerUserId, role: 'MEMBER' },
            { conversationId: conv.id, userId: resolvedCalleeUserId, role: 'MEMBER' }
          ]
        });
      }

      // Store call metadata (e.g. isVideo, conversationId, participants) in Redis
      await this.redis.set(
        `call:${call.id}:meta`,
        JSON.stringify({
          isVideo: !!isVideo,
          conversationId: conv.id,
          callerUserId,
          calleeUserId: resolvedCalleeUserId,
          safeCallerDeviceId
        }),
        'EX',
        86400
      );

      const caller = await tx.user.findUnique({
        where: { id: callerUserId },
        select: { username: true }
      });

      const incomingPayload = {
        type: 'CALL_INCOMING',
        callId: call.id,
        conversationId: conv.id,
        initiatorId: callerUserId,
        initiatorName: caller?.username || 'Kontak',
        callerDeviceId: safeCallerDeviceId,
        isVideo: !!isVideo
      };

      await this.redis.publish(
        `user:${resolvedCalleeUserId}`,
        JSON.stringify(incomingPayload)
      );

      // Notify callee via WebSocket gateway directly (instant, no polling needed)
      this.callGateway?.notifyUser(resolvedCalleeUserId, incomingPayload);

      // Trigger high-priority push notification across all registered tokens for callee
      if (this.gotifyService) {
        const calleeDevices = await tx.device.findMany({
          where: { userId: resolvedCalleeUserId, status: 'ACTIVE' },
          include: { pushDevices: true }
        });
        const pushTokens: string[] = [];
        for (const d of calleeDevices) {
          if (d.pushToken && !pushTokens.includes(d.pushToken)) pushTokens.push(d.pushToken);
          if (d.pushDevices) {
            for (const pd of d.pushDevices) {
              if (pd.clientToken && !pushTokens.includes(pd.clientToken)) {
                pushTokens.push(pd.clientToken);
              }
            }
          }
        }

        for (const tok of pushTokens) {
          this.gotifyService.sendPushNotification({
            targetToken: tok,
            title: `Panggilan Masuk dari ${caller?.username || 'Kontak'}`,
            message: isVideo ? 'Panggilan Video Masuk' : 'Panggilan Suara Masuk',
            conversationId: conv.id,
            priority: 8
          }).catch(() => {});
        }
      }

      this.scheduleRingingTimeout(call.id, callerUserId);

      return call;
    });
  }

  private scheduleRingingTimeout(callId: string, initiatorId: string) {
    const timer = setTimeout(async () => {
      try {
        const current = await this.prisma.call.findUnique({
          where: { id: callId },
          select: { id: true, state: true }
        });
        if (current && current.state === 'INITIATED') {
          await this.endCall(initiatorId, callId);
        }
      } catch (_) {}
    }, 60000);
    if (typeof (timer as any).unref === 'function') {
      (timer as any).unref();
    }
  }

  async createGroupCall(callerUserId: string, callerDeviceId: string, conversationId: string, isVideo?: boolean) {
    if (!conversationId) {
      throw new BadRequestException('ID percakapan grup tidak valid');
    }

    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: {
        members: {
          where: { leftAt: null },
          include: {
            user: {
              include: {
                devices: {
                  where: { status: 'ACTIVE' },
                  orderBy: { lastSeenAt: 'desc' }
                }
              }
            }
          }
        }
      }
    });

    if (!conversation) {
      throw new NotFoundException('Grup tidak ditemukan');
    }

    const isMember = conversation.members.some((m) => m.userId === callerUserId);
    if (!isMember) {
      throw new ForbiddenException('Bukan anggota dari grup ini');
    }

    const caller = await this.prisma.user.findUnique({
      where: { id: callerUserId },
      select: { username: true }
    });

    return this.prisma.$transaction(async (tx) => {
      const call = await tx.call.create({
        data: {
          initiatorId: callerUserId,
          state: 'INITIATED'
        }
      });

      let safeCallerDeviceId = callerDeviceId;
      if (!safeCallerDeviceId) {
        const callerDevice = await tx.device.findFirst({
          where: { userId: callerUserId, status: 'ACTIVE' },
          orderBy: { lastSeenAt: 'desc' }
        });
        safeCallerDeviceId = callerDevice?.id || `dev-${callerUserId.substring(0, 8)}`;
      }

      await tx.callParticipant.create({
        data: {
          callId: call.id,
          userId: callerUserId,
          deviceId: safeCallerDeviceId,
          state: 'CONNECTED',
          joinedAt: new Date()
        }
      });

      const otherMembers = conversation.members.filter((m) => m.userId !== callerUserId);

      for (const member of otherMembers) {
        const memberDevice = member.user.devices[0];
        let safeMemberDeviceId = memberDevice?.id || `dev-${member.userId.substring(0, 8)}`;
        if (safeMemberDeviceId === safeCallerDeviceId) {
          safeMemberDeviceId = `${safeMemberDeviceId}-${member.userId.substring(0, 4)}`;
        }

        try {
          await tx.callParticipant.create({
            data: {
              callId: call.id,
              userId: member.userId,
              deviceId: safeMemberDeviceId,
              state: 'RINGING',
              joinedAt: new Date()
            }
          });
        } catch (_) {}
      }

      const groupName = conversation.title || 'Panggilan Grup';
      await this.redis.set(
        `call:${call.id}:meta`,
        JSON.stringify({
          isVideo: !!isVideo,
          isGroup: true,
          conversationId,
          groupName
        }),
        'EX',
        3600
      );

      const incomingPayload = {
        type: 'CALL_INCOMING',
        callId: call.id,
        conversationId,
        groupName,
        isGroup: true,
        initiatorId: callerUserId,
        initiatorName: caller?.username || 'Kontak',
        callerDeviceId: safeCallerDeviceId,
        isVideo: !!isVideo
      };

      for (const member of otherMembers) {
        await this.redis.publish(
          `user:${member.userId}`,
          JSON.stringify(incomingPayload)
        ).catch(() => {});

        this.callGateway?.notifyUser(member.userId, incomingPayload);

        if (this.gotifyService) {
          const pushToken = member.user.devices[0]?.pushToken;
          this.gotifyService.sendPushNotification({
            targetToken: pushToken || undefined,
            title: `${groupName}: Panggilan Masuk dari ${caller?.username || 'Kontak'}`,
            message: isVideo ? 'Panggilan Video Grup Masuk' : 'Panggilan Suara Grup Masuk',
            conversationId: call.id,
            priority: 8
          }).catch(() => {});
        }
      }

      this.scheduleRingingTimeout(call.id, callerUserId);

      return {
        ...call,
        conversationId,
        groupName,
        isGroup: true,
        isVideo: !!isVideo
      };
    });
  }

  async acceptCall(calleeUserId: string, calleeDeviceId: string, callId: string) {
    const participant = await this.prisma.callParticipant.findFirst({
      where: { callId, userId: calleeUserId }
    });
    if (!participant) {
      throw new ForbiddenException('Not a participant in this call');
    }

    let safeCalleeDeviceId = calleeDeviceId;
    if (!safeCalleeDeviceId) {
      const dev = await this.prisma.device.findFirst({
        where: { userId: calleeUserId, status: 'ACTIVE' },
        orderBy: { lastSeenAt: 'desc' }
      });
      safeCalleeDeviceId = dev?.id || participant.deviceId || `dev-${calleeUserId.substring(0, 8)}`;
    }

    // Check caller participant deviceId to prevent @@unique([callId, deviceId]) crash
    const callerPart = await this.prisma.callParticipant.findFirst({
      where: { callId, userId: { not: calleeUserId } }
    });
    if (callerPart && callerPart.deviceId === safeCalleeDeviceId) {
      safeCalleeDeviceId = `${safeCalleeDeviceId}-callee`;
    }

    await this.prisma.$transaction([
      this.prisma.call.update({
        where: { id: callId },
        data: { state: 'CONNECTED' }
      }),
      this.prisma.callParticipant.update({
        where: { id: participant.id },
        data: { state: 'CONNECTED', joinedAt: new Date(), deviceId: safeCalleeDeviceId }
      })
    ]);

    const acceptedPayload = {
      type: 'CALL_ACCEPTED',
      callId,
      participantId: calleeUserId,
      deviceId: safeCalleeDeviceId
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

    this.recordCallLogMessage(callId, 'REJECTED', 0).catch((err) => {
      this.logger.warn(`Failed to record rejected call log: ${err.message}`);
    });

    return { success: true };
  }

  async endCall(userId: string, callId: string) {
    const call = await this.prisma.call.findUnique({
      where: { id: callId },
      include: { participants: true }
    });

    if (!call || call.state === 'ENDED' || call.state === 'REJECTED') {
      return { success: true };
    }

    const metaStr = await this.redis.get(`call:${callId}:meta`);
    const isGroup = metaStr?.includes('"isGroup":true');

    // If it's a group call and the leaving user is NOT the initiator,
    // and there are still other active/ringing participants, only leave this participant.
    if (isGroup && call.initiatorId !== userId) {
      const activeOthers = call.participants.filter(
        (p) => p.userId !== userId && (p.state === 'CONNECTED' || p.state === 'RINGING') && !p.leftAt
      );

      if (activeOthers.length > 0) {
        await this.prisma.callParticipant.updateMany({
          where: { callId, userId },
          data: { leftAt: new Date() }
        });

        const leftPayload = {
          type: 'PEER_LEFT',
          callId,
          userId
        };

        await this.redis.publish(`call:${callId}`, JSON.stringify(leftPayload));
        this.callGateway?.notifyCallRoom(callId, leftPayload);

        return { success: true };
      }
    }

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

    const calleeParticipant = call.participants.find((p) => p.userId !== call.initiatorId);
    const isMissed = !calleeParticipant || calleeParticipant.state === 'RINGING' || !calleeParticipant.joinedAt;
    const status = isMissed ? 'MISSED' : 'COMPLETED';
    const durationSeconds = isMissed
      ? 0
      : Math.max(0, Math.round((Date.now() - (calleeParticipant.joinedAt || call.startedAt).getTime()) / 1000));

    this.recordCallLogMessage(callId, status, durationSeconds).catch((err) => {
      this.logger.warn(`Failed to record call log: ${err.message}`);
    });

    return { success: true };
  }

  private async recordCallLogMessage(
    callId: string,
    status: 'COMPLETED' | 'MISSED' | 'REJECTED' | 'CANCELLED',
    durationSeconds: number
  ) {
    try {
      const metaStr = await this.redis.get(`call:${callId}:meta`);
      if (!metaStr) return;
      let meta: any = {};
      try {
        meta = JSON.parse(metaStr);
      } catch (_) {
        return;
      }

      const conversationId = meta.conversationId;
      const callerUserId = meta.callerUserId;
      const calleeUserId = meta.calleeUserId;
      const safeCallerDeviceId = meta.safeCallerDeviceId;
      const isVideo = !!meta.isVideo;

      if (!conversationId || !callerUserId) return;

      const caller = await this.prisma.user.findUnique({
        where: { id: callerUserId },
        select: { username: true }
      });
      const callerName = caller?.username || 'Kontak';

      // Find valid caller device
      let activeDeviceId = safeCallerDeviceId;
      const dev = await this.prisma.device.findFirst({
        where: { id: activeDeviceId }
      });
      if (!dev) {
        const anyDev = await this.prisma.device.findFirst({
          where: { userId: callerUserId, status: 'ACTIVE' },
          orderBy: { lastSeenAt: 'desc' }
        });
        if (anyDev) {
          activeDeviceId = anyDev.id;
        } else {
          return;
        }
      }

      const clientMessageId = `call-log-${callId}`;

      // Avoid duplicate log if already created
      const existing = await this.prisma.message.findFirst({
        where: { conversationId, clientMessageId }
      });
      if (existing) return;

      const callLogPayload = {
        type: 'call_log',
        callId,
        isVideo,
        status,
        durationSeconds,
        initiatorId: callerUserId,
        callerName
      };

      const ciphertext = JSON.stringify(callLogPayload);

      const createdMessage = await this.prisma.$transaction(async (tx) => {
        const message = await tx.message.create({
          data: {
            conversationId,
            senderUserId: callerUserId,
            senderDeviceId: activeDeviceId,
            clientMessageId,
            ciphertext,
            nonce: 'call-log',
            messageType: 'CONTROL',
            state: 'SENT'
          }
        });

        await tx.conversation.update({
          where: { id: conversationId },
          data: { updatedAt: new Date() }
        });

        await tx.conversationEvent.create({
          data: {
            conversationId,
            eventType: 'MESSAGE_CREATED',
            payload: JSON.stringify({
              messageId: message.id,
              sequence: message.sequence,
              senderUserId: callerUserId,
              senderDeviceId: activeDeviceId,
              messageType: message.messageType,
              createdAt: message.createdAt
            })
          }
        });

        return message;
      });

      const messagePreview = isVideo
        ? (status === 'MISSED' ? '📹 Panggilan video tak terjawab' : '📹 Panggilan video')
        : (status === 'MISSED' ? '📞 Panggilan suara tak terjawab' : '📞 Panggilan suara');

      const messageEventPayload = {
        type: 'NEW_MESSAGE',
        conversationId,
        senderName: callerName,
        preview: messagePreview,
        messageId: createdMessage.id,
        message: {
          id: createdMessage.id,
          conversationId,
          senderUserId: callerUserId,
          senderDeviceId: activeDeviceId,
          ciphertext,
          nonce: 'call-log',
          messageType: 'CONTROL',
          state: 'SENT',
          createdAt: createdMessage.createdAt,
          sequence: createdMessage.sequence,
          senderUser: {
            id: callerUserId,
            username: callerName
          }
        }
      };

      const strPayload = JSON.stringify(messageEventPayload);
      if (this.redis) {
        const client = this.redis.getClient();
        if (client) {
          // Send silent sync to caller, and full event to callee
          client.publish(`user:${callerUserId}`, JSON.stringify({ ...messageEventPayload, type: 'MESSAGE_SYNC', isSilent: true })).catch(() => {});
          if (calleeUserId) {
            client.publish(`user:${calleeUserId}`, strPayload).catch(() => {});
          }
        }
      }
    } catch (e: any) {
      this.logger.warn(`Failed to record call log message: ${e.message}`);
    }
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
    const ringingCutoff = new Date(Date.now() - 65 * 1000);

    // Auto-expire any stale unanswered calls targeting this user
    const staleParticipant = await this.prisma.callParticipant.findFirst({
      where: {
        userId,
        state: 'RINGING',
        call: {
          state: 'INITIATED',
          startedAt: { lt: ringingCutoff }
        }
      },
      include: { call: true }
    });
    if (staleParticipant) {
      await this.endCall(staleParticipant.call.initiatorId, staleParticipant.callId).catch(() => {});
    }

    const participant = await this.prisma.callParticipant.findFirst({
      where: {
        userId,
        state: 'RINGING',
        call: {
          state: 'INITIATED',
          startedAt: { gte: ringingCutoff }
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
      select: { id: true, username: true, phoneNumber: true }
    });

    let isVideo = false;
    let isGroup = false;
    let groupName: string | undefined;
    let conversationId: string | undefined;

    try {
      const meta = await this.redis.get(`call:${participant.callId}:meta`);
      if (meta) {
        const parsed = JSON.parse(meta);
        isVideo = !!parsed.isVideo;
        isGroup = !!parsed.isGroup;
        groupName = parsed.groupName;
        conversationId = parsed.conversationId;
      }
    } catch (_) {}

    return {
      callId: participant.callId,
      initiatorId: participant.call.initiatorId,
      initiatorName: initiator?.username || 'Kontak',
      initiatorPhone: initiator?.phoneNumber || null,
      isVideo,
      isGroup,
      groupName,
      conversationId,
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
        let isGroup = false;
        let groupName: string | undefined;
        let conversationId: string | undefined;

        try {
          const meta = await this.redis.get(`call:${call.id}:meta`);
          if (meta) {
            const parsed = JSON.parse(meta);
            isVideo = !!parsed.isVideo;
            isGroup = !!parsed.isGroup;
            groupName = parsed.groupName;
            conversationId = parsed.conversationId;
          }
        } catch (_) {}

        const isInitiator = call.initiatorId === userId;
        const otherParticipant = call.participants.find((p) => p.userId !== userId);

        let contactUser: { id: string; username: string; phoneNumber?: string | null } | null = null;
        if (isInitiator) {
          contactUser = otherParticipant?.user || null;
          if (!contactUser && otherParticipant?.userId) {
            contactUser = await this.prisma.user.findUnique({
              where: { id: otherParticipant.userId },
              select: { id: true, username: true, phoneNumber: true }
            });
          }
        } else {
          contactUser = call.participants.find((p) => p.userId === call.initiatorId)?.user || null;
          if (!contactUser && call.initiatorId) {
            contactUser = await this.prisma.user.findUnique({
              where: { id: call.initiatorId },
              select: { id: true, username: true, phoneNumber: true }
            });
          }
        }

        const calleePart = call.participants.find((p) => p.userId !== call.initiatorId);
        const wasConnected = calleePart?.state === 'CONNECTED' || (calleePart?.joinedAt != null && calleePart?.leftAt != null);

        let status = 'completed';
        if (call.state === 'REJECTED') {
          status = 'rejected';
        } else if (call.state === 'INITIATED' || call.state === 'RINGING' || (!wasConnected && call.state === 'ENDED')) {
          status = isInitiator ? 'cancelled' : 'missed';
        }

        let durationSeconds = 0;
        if (wasConnected && call.startedAt && call.endedAt) {
          durationSeconds = Math.max(0, Math.floor((call.endedAt.getTime() - call.startedAt.getTime()) / 1000));
        }

        return {
          id: call.id,
          initiatorId: call.initiatorId,
          isOutgoing: isInitiator,
          state: call.state,
          status,
          startedAt: call.startedAt,
          endedAt: call.endedAt,
          durationSeconds,
          isVideo,
          isGroup: !!isGroup,
          groupName: groupName || undefined,
          conversationId: conversationId || undefined,
          contactId: isGroup ? conversationId : (contactUser?.id || (isInitiator ? otherParticipant?.userId : call.initiatorId)),
          contactName: isGroup ? (groupName || 'Panggilan Grup') : (contactUser?.username || 'Kontak'),
          contactPhone: contactUser?.phoneNumber || null
        };
      })
    );
  }

  async clearCallHistory(userId: string) {
    // Delete all call participant records for this user
    await this.prisma.callParticipant.deleteMany({
      where: { userId }
    });

    // Delete any orphaned calls that have no participants left
    await this.prisma.call.deleteMany({
      where: {
        participants: {
          none: {}
        }
      }
    });

    return { success: true, message: 'Riwayat panggilan berhasil dibersihkan' };
  }

  async deleteCallFromHistory(userId: string, callId: string) {
    // Delete this user's participation in this call
    await this.prisma.callParticipant.deleteMany({
      where: {
        callId,
        userId
      }
    });

    // Delete the call if no participants remain
    await this.prisma.call.deleteMany({
      where: {
        id: callId,
        participants: {
          none: {}
        }
      }
    });

    return { success: true, message: 'Log panggilan berhasil dihapus' };
  }
}
