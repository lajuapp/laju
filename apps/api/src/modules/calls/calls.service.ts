import {
  Injectable,
  NotFoundException,
  ForbiddenException
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';

@Injectable()
export class CallsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService
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

      await this.redis.publish(
        `user:${calleeUserId}`,
        JSON.stringify({
          type: 'CALL_INCOMING',
          callId: call.id,
          initiatorId: callerUserId,
          callerDeviceId
        })
      );

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
}
