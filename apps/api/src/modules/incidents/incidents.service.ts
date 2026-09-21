import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { CreateIncidentDto } from './dto/incident.dto';

@Injectable()
export class IncidentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService
  ) {}

  async createIncident(dto: CreateIncidentDto) {
    return this.prisma.$transaction(async (tx) => {
      const incident = await tx.incident.create({
        data: {
          title: dto.title,
          description: dto.description,
          severity: dto.severity || 'MEDIUM',
          status: 'OPEN'
        }
      });

      if (dto.targetUserId || dto.targetDeviceId) {
        await tx.incidentTarget.create({
          data: {
            incidentId: incident.id,
            userId: dto.targetUserId,
            deviceId: dto.targetDeviceId,
            isContained: false
          }
        });
      }

      return incident;
    });
  }

  async listIncidents() {
    return this.prisma.incident.findMany({
      include: {
        targets: {
          include: {
            user: { select: { id: true, username: true } }
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });
  }

  async containIncident(incidentId: string, wipeApplicationData: boolean = false) {
    const incident = await this.prisma.incident.findUnique({
      where: { id: incidentId },
      include: { targets: true }
    });

    if (!incident) {
      throw new NotFoundException('Incident not found');
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.incident.update({
        where: { id: incidentId },
        data: {
          status: 'CONTAINED',
          containedAt: new Date()
        }
      });

      for (const target of incident.targets) {
        await tx.incidentTarget.update({
          where: { id: target.id },
          data: { isContained: true, containedAt: new Date() }
        });

        if (target.deviceId) {
          await tx.device.update({
            where: { id: target.deviceId },
            data: { status: 'CONTAINED' }
          });
          await tx.session.deleteMany({
            where: { deviceId: target.deviceId }
          });

          // Dispatch containment command to device via Redis
          await this.redis.publish(
            `device:${target.deviceId}`,
            JSON.stringify({
              type: 'CONTAINMENT_ORDER',
              incidentId,
              wipeApplicationData,
              timestamp: Date.now()
            })
          );
        }

        if (target.userId && !target.deviceId) {
          await tx.user.update({
            where: { id: target.userId },
            data: { status: 'SUSPENDED' }
          });
          await tx.session.deleteMany({
            where: { userId: target.userId }
          });
        }
      }

      return { success: true, message: 'Incident targets contained' };
    });
  }

  async restoreIncident(incidentId: string) {
    const incident = await this.prisma.incident.findUnique({
      where: { id: incidentId },
      include: { targets: true }
    });

    if (!incident) {
      throw new NotFoundException('Incident not found');
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.incident.update({
        where: { id: incidentId },
        data: { status: 'RESOLVED', resolvedAt: new Date() }
      });

      for (const target of incident.targets) {
        await tx.incidentTarget.update({
          where: { id: target.id },
          data: { isContained: false }
        });

        if (target.deviceId) {
          await tx.device.update({
            where: { id: target.deviceId },
            data: { status: 'ACTIVE' }
          });
        }

        if (target.userId) {
          await tx.user.update({
            where: { id: target.userId },
            data: { status: 'ACTIVE' }
          });
        }
      }

      return { success: true, message: 'Incident resolved and targets restored' };
    });
  }
}
