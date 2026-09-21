import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

@Injectable()
export class KeyDirectoryService {
  constructor(private readonly prisma: PrismaService) {}

  async getPreKeyBundle(userId: string, targetDeviceId?: string) {
    // Find active device(s)
    const deviceWhere: any = {
      userId,
      status: 'ACTIVE'
    };
    if (targetDeviceId) {
      deviceWhere.id = targetDeviceId;
    }

    const device = await this.prisma.device.findFirst({
      where: deviceWhere,
      include: {
        deviceKeys: {
          orderBy: { createdAt: 'desc' },
          take: 1
        },
        preKeys: {
          where: { isOneTime: false },
          orderBy: { createdAt: 'desc' },
          take: 1
        }
      }
    });

    if (!device || device.deviceKeys.length === 0 || device.preKeys.length === 0) {
      throw new NotFoundException('Pre-key bundle not available for user/device');
    }

    // Atomically consume one one-time prekey if available
    let oneTimePreKey = null;
    const availableOtk = await this.prisma.preKey.findFirst({
      where: {
        deviceId: device.id,
        isOneTime: true,
        consumedAt: null
      }
    });

    if (availableOtk) {
      await this.prisma.preKey.update({
        where: { id: availableOtk.id },
        data: { consumedAt: new Date() }
      });
      oneTimePreKey = {
        keyId: availableOtk.keyId,
        publicKey: availableOtk.publicKey
      };
    }

    const signedPreKey = device.preKeys[0];
    const identityKey = device.deviceKeys[0];

    return {
      userId,
      deviceId: device.id,
      identityKey: identityKey.identityKey,
      signedPreKey: {
        keyId: signedPreKey.keyId,
        publicKey: signedPreKey.publicKey,
        signature: signedPreKey.signature
      },
      oneTimePreKey
    };
  }
}
