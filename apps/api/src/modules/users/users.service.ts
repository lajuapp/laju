import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException
} from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { UpdateUserProfileDto } from './dto/users.dto';
import { CreateUserReportDto, ReviewUserReportDto } from './dto/reports.dto';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService
  ) {}

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        username: true,
        email: true,
        phoneNumber: true,
        status: true,
        trustScore: true,
        twoFactorEnabled: true,
        avatarUrl: true,
        createdAt: true,
        updatedAt: true,
        devices: {
          where: { status: 'ACTIVE' },
          select: { id: true, deviceUuid: true, name: true, lastSeenAt: true }
        }
      }
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const [avatarUrl, about] = await Promise.all([
      this.redis.get(`user:${userId}:avatar`),
      this.redis.get(`user:${userId}:about`)
    ]);
    return { ...user, avatarUrl: avatarUrl || user.avatarUrl || null, about: about ?? 'Available' };
  }

  async updateProfile(userId: string, dto: UpdateUserProfileDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId }
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Check unique conflicts if username is changing
    if (dto.username && dto.username !== user.username) {
      const existing = await this.prisma.user.findUnique({
        where: { username: dto.username }
      });
      if (existing) {
        throw new ConflictException('Username is already taken');
      }
    }

    // Check unique conflicts if email is changing
    if (dto.email && dto.email !== user.email) {
      const existing = await this.prisma.user.findUnique({
        where: { email: dto.email }
      });
      if (existing) {
        throw new ConflictException('Email address is already in use');
      }
    }

    // Check unique conflicts if phoneNumber is changing
    if (dto.phoneNumber && dto.phoneNumber !== user.phoneNumber) {
      const existing = await this.prisma.user.findUnique({
        where: { phoneNumber: dto.phoneNumber }
      });
      if (existing) {
        throw new ConflictException('Phone number is already in use');
      }
    }

    if (dto.avatarUrl !== undefined) {
      if (dto.avatarUrl && dto.avatarUrl.length > 0) {
        await this.redis.set(`user:${userId}:avatar`, dto.avatarUrl);
      } else {
        await this.redis.del(`user:${userId}:avatar`);
      }
    }

    if (dto.status !== undefined) {
      if (dto.status && dto.status.length > 0) {
        await this.redis.set(`user:${userId}:about`, dto.status);
      } else {
        await this.redis.del(`user:${userId}:about`);
      }
    }

    let hashedPin: string | undefined = undefined;
    if (dto.twoFactorPin !== undefined) {
      const pinStr = dto.twoFactorPin?.trim();
      if (pinStr && pinStr.length > 0) {
        if (pinStr.startsWith('$2a$') || pinStr.startsWith('$2b$')) {
          hashedPin = pinStr;
        } else {
          const salt = await bcrypt.genSalt(10);
          hashedPin = await bcrypt.hash(pinStr, salt);
        }
      }
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: {
        username: dto.username,
        email: dto.email,
        phoneNumber: dto.phoneNumber,
        twoFactorEnabled: dto.twoFactorEnabled,
        ...(dto.avatarUrl !== undefined ? { avatarUrl: dto.avatarUrl && dto.avatarUrl.length > 0 ? dto.avatarUrl : null } : {}),
        ...(hashedPin !== undefined ? { twoFactorPin: hashedPin } : {})
      },
      select: {
        id: true,
        username: true,
        email: true,
        phoneNumber: true,
        status: true,
        twoFactorEnabled: true,
        avatarUrl: true,
        createdAt: true,
        updatedAt: true
      }
    });

    const [avatarUrl, about] = await Promise.all([
      this.redis.get(`user:${userId}:avatar`),
      this.redis.get(`user:${userId}:about`)
    ]);
    return { ...updated, avatarUrl: avatarUrl || updated.avatarUrl || null, about: about ?? 'Available' };
  }

  async searchUsers(currentUserId: string, query?: string, limitStr?: string, offsetStr?: string) {
    const limit = limitStr ? Math.min(parseInt(limitStr, 10), 100) : 50;
    const offset = offsetStr ? parseInt(offsetStr, 10) : 0;
    const q = query?.trim();

    const whereClause: any = {
      status: 'ACTIVE',
      id: { not: currentUserId }
    };

    if (q && q.length > 0) {
      whereClause.OR = [
        { username: { contains: q, mode: 'insensitive' } },
        { email: { contains: q, mode: 'insensitive' } },
        { phoneNumber: { contains: q } }
      ];
    }

    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where: whereClause,
        select: {
          id: true,
          username: true,
          email: true,
          phoneNumber: true,
          status: true,
          avatarUrl: true,
          createdAt: true
        },
        take: limit,
        skip: offset,
        orderBy: { username: 'asc' }
      }),
      this.prisma.user.count({ where: whereClause })
    ]);

    const usersWithAvatar = await Promise.all(
      users.map(async (u) => {
        const [avatarUrl, onlineRaw] = await Promise.all([
          this.redis.get(`user:${u.id}:avatar`),
          this.redis.get(`user:${u.id}:online`),
        ]);
        return {
          ...u,
          avatarUrl: avatarUrl || u.avatarUrl || null,
          isOnline: onlineRaw === '1'
        };
      })
    );

    return {
      users: usersWithAvatar,
      total,
      limit,
      offset
    };
  }

  async getUserById(userId: string) {
    let user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        username: true,
        phoneNumber: true,
        email: true,
        status: true,
        trustScore: true,
        avatarUrl: true,
        createdAt: true
      }
    });

    if (!user) {
      user = await this.prisma.user.findUnique({
        where: { username: userId },
        select: {
          id: true,
          username: true,
          phoneNumber: true,
          email: true,
          status: true,
          trustScore: true,
          avatarUrl: true,
          createdAt: true
        }
      });
    }

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const [avatarUrl, about, onlineRaw] = await Promise.all([
      this.redis.get(`user:${user.id}:avatar`),
      this.redis.get(`user:${user.id}:about`),
      this.redis.get(`user:${user.id}:online`),
    ]);
    return { ...user, avatarUrl: avatarUrl || user.avatarUrl || null, about: about ?? 'Available', isOnline: onlineRaw === '1' };
  }

  async createUserReport(reporterId: string, dto: CreateUserReportDto) {
    if (reporterId === dto.reportedUserId) {
      throw new BadRequestException('You cannot report your own account');
    }

    const reportedUser = await this.prisma.user.findUnique({
      where: { id: dto.reportedUserId }
    });

    if (!reportedUser) {
      throw new NotFoundException('Reported user not found');
    }

    const report = await (this.prisma as any).userReport.create({
      data: {
        reporterId,
        reportedUserId: dto.reportedUserId,
        category: dto.category,
        reason: dto.reason.trim(),
        scoreDeduction: dto.scoreDeduction ?? 10,
        status: 'PENDING'
      },
      include: {
        reporter: {
          select: { id: true, username: true }
        },
        reportedUser: {
          select: { id: true, username: true, trustScore: true }
        }
      }
    });

    return {
      success: true,
      message: 'Report submitted successfully. Moderation team will review your report.',
      report
    };
  }

  async getUserTrustScore(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        username: true,
        trustScore: true,
        status: true
      }
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    let level = 'EXCELLENT';
    if (user.trustScore < 30) {
      level = 'HIGH_RISK';
    } else if (user.trustScore < 60) {
      level = 'FAIR';
    } else if (user.trustScore < 85) {
      level = 'GOOD';
    }

    return {
      userId: user.id,
      username: user.username,
      trustScore: user.trustScore,
      reputationLevel: level,
      status: user.status
    };
  }

  async listReports(status?: string, limitStr?: string, offsetStr?: string) {
    const limit = limitStr ? Math.min(parseInt(limitStr, 10), 100) : 50;
    const offset = offsetStr ? parseInt(offsetStr, 10) : 0;
    const whereClause: any = {};
    if (status) {
      whereClause.status = status.toUpperCase();
    }

    const [reports, total] = await Promise.all([
      (this.prisma as any).userReport.findMany({
        where: whereClause,
        include: {
          reporter: {
            select: { id: true, username: true }
          },
          reportedUser: {
            select: { id: true, username: true, trustScore: true, status: true }
          }
        },
        take: limit,
        skip: offset,
        orderBy: { createdAt: 'desc' }
      }),
      (this.prisma as any).userReport.count({ where: whereClause })
    ]);

    return {
      reports,
      total,
      limit,
      offset
    };
  }

  async reviewReport(reportId: string, reviewerId: string, dto: ReviewUserReportDto) {
    const report = await (this.prisma as any).userReport.findUnique({
      where: { id: reportId },
      include: {
        reportedUser: true
      }
    });

    if (!report) {
      throw new NotFoundException('Report not found');
    }

    if (report.status !== 'PENDING') {
      throw new BadRequestException(`Report has already been reviewed (Status: ${report.status})`);
    }

    if (dto.action === 'APPROVE') {
      const deduction = dto.scoreDeduction ?? report.scoreDeduction ?? 10;
      const currentScore = report.reportedUser.trustScore ?? 100;
      const newScore = Math.max(0, currentScore - deduction);

      const updateData: any = {
        trustScore: newScore
      };

      // Auto-suspend if trust score drops to high-risk threshold (<= 20)
      if (newScore <= 20) {
        updateData.status = 'SUSPENDED';
      }

      await this.prisma.user.update({
        where: { id: report.reportedUserId },
        data: updateData
      });

      const updatedReport = await (this.prisma as any).userReport.update({
        where: { id: reportId },
        data: {
          status: 'APPROVED',
          scoreDeduction: deduction,
          reviewNotes: dto.reviewNotes,
          reviewedAt: new Date(),
          reviewedBy: reviewerId
        },
        include: {
          reportedUser: {
            select: { id: true, username: true, trustScore: true, status: true }
          }
        }
      });

      return {
        success: true,
        message: `Report approved. User trust score deducted by ${deduction} points (New score: ${newScore}).`,
        report: updatedReport
      };
    } else {
      const updatedReport = await (this.prisma as any).userReport.update({
        where: { id: reportId },
        data: {
          status: 'REJECTED',
          reviewNotes: dto.reviewNotes,
          reviewedAt: new Date(),
          reviewedBy: reviewerId
        },
        include: {
          reportedUser: {
            select: { id: true, username: true, trustScore: true, status: true }
          }
        }
      });

      return {
        success: true,
        message: 'Report rejected. No trust score was deducted.',
        report: updatedReport
      };
    }
  }
}
