import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Optional
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { GotifyService } from '../../infrastructure/gotify/gotify.service';

@Injectable()
export class CallsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    @Optional() private readonly gotifyService?: GotifyService
  ) {}

  async createCall(callerUserId: string, callerDeviceId: string, calleeUserId: string, isVideo?: boolean) {
    return this.prisma.$transaction(async (tx) => {
      // Find target callee user by ID or username
      const cleanUsername = calleeUserId.startsWith('@') ? calleeUserId.substring(1) : calleeUserId;
      const targetUser = await tx.user.findFirst({
        where: {
          OR: [
            { id: calleeUserId },
            { username: { equals: calleeUserId, mode: 'insensitive' } },
            { username: { equals: cleanUsername, mode: 'insensitive' } }
          ]
        }
      });
      const resolvedCalleeUserId = targetUser ? targetUser.id : calleeUserId;

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

      await this.redis.publish(
        `user:${resolvedCalleeUserId}`,
        JSON.stringify({
          type: 'CALL_INCOMING',
          callId: call.id,
          initiatorId: callerUserId,
          initiatorName: caller?.username || 'Kontak',
          callerDeviceId,
          isVideo: !!isVideo
        })
      );

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

    await this.redis.publish(
      `call:${callId}`,
      JSON.stringify({
        type: 'CALL_ACCEPTED',
        callId,
        participantId: calleeUserId,
        deviceId: calleeDeviceId
      })
    );

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

    await this.redis.publish(
      `call:${callId}`,
      JSON.stringify({
        type: 'CALL_REJECTED',
        callId,
        userId
      })
    );

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

    await this.redis.publish(
      `call:${callId}`,
      JSON.stringify({
        type: 'CALL_ENDED',
        callId,
        userId
      })
    );

    return { success: true };
  }

  async exchangeSignal(userId: string, deviceId: string, callId: string, signalData: any) {
    const participant = await this.prisma.callParticipant.findFirst({
      where: { callId, userId }
    });
    if (!participant) {
      throw new ForbiddenException('Not a participant in this call');
    }

    await this.redis.publish(
      `call:${callId}`,
      JSON.stringify({
        type: 'CALL_SIGNAL',
        callId,
        fromUserId: userId,
        fromDeviceId: deviceId,
        signal: signalData
      })
    );

    return { success: true };
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
