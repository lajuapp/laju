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

  async createCall(callerUserId: string, callerDeviceId: string, calleeUserId: string) {
    return this.prisma.$transaction(async (tx) => {
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

      // Find callee active device
      const calleeDevice = await tx.device.findFirst({
        where: { userId: calleeUserId, status: 'ACTIVE' }
      });

      if (calleeDevice) {
        await tx.callParticipant.create({
          data: {
            callId: call.id,
            userId: calleeUserId,
            deviceId: calleeDevice.id,
            state: 'RINGING'
          }
        });
      }

      const caller = await tx.user.findUnique({
        where: { id: callerUserId },
        select: { username: true }
      });

      await this.redis.publish(
        `user:${calleeUserId}`,
        JSON.stringify({
          type: 'CALL_INCOMING',
          callId: call.id,
          initiatorId: callerUserId,
          initiatorName: caller?.username || 'Kontak',
          callerDeviceId
        })
      );

      // Trigger high-priority push notification (Priority 8 - Call Wakeup)
      if (this.gotifyService) {
        this.gotifyService.sendPushNotification({
          targetToken: calleeDevice?.pushToken || undefined,
          title: `Panggilan Masuk dari ${caller?.username || 'Kontak'}`,
          message: 'Panggilan Suara Masuk',
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
    await this.prisma.call.update({
      where: { id: callId },
      data: { state: 'REJECTED', endedAt: new Date() }
    });

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
    await this.prisma.call.update({
      where: { id: callId },
      data: { state: 'ENDED', endedAt: new Date() }
    });

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

    return {
      callId: participant.callId,
      initiatorId: participant.call.initiatorId,
      initiatorName: initiator?.username || 'Kontak',
      createdAt: participant.call.startedAt
    };
  }
}
