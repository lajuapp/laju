import { Controller, Get, Res, HttpStatus } from '@nestjs/common';
import { Response } from 'express';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';

@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService
  ) {}

  @Get()
  async checkHealth(@Res() res: Response) {
    let dbStatus = 'down';
    let redisStatus = 'down';

    try {
      await this.prisma.$queryRaw`SELECT 1`;
      dbStatus = 'up';
    } catch (err) {
      dbStatus = 'down';
    }

    try {
      const pong = await this.redis.ping();
      if (pong === 'PONG') {
        redisStatus = 'up';
      }
    } catch (err) {
      redisStatus = 'down';
    }

    const healthy = dbStatus === 'up' && redisStatus === 'up';
    return res.status(HttpStatus.OK).json({
      status: healthy ? 'ok' : 'degraded',
      timestamp: new Date().toISOString(),
      services: {
        database: dbStatus,
        redis: redisStatus
      }
    });
  }
}
