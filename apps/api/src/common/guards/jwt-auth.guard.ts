import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
  ForbiddenException,
  Optional
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  private static lastTouchMap = new Map<string, number>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
    @Optional() private readonly redis?: RedisService
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing authorization token');
    }

    const token = authHeader.substring(7);
    try {
      const secret = this.configService.get<string>('JWT_SECRET');
      const payload = this.jwtService.verify(token, { secret });

      // Verify device and user status
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub }
      });
      if (!user) {
        throw new UnauthorizedException('User not found');
      }
      if (user.status === 'SUSPENDED') {
        throw new ForbiddenException({
          statusCode: 403,
          error: 'ACCOUNT_SUSPENDED',
          message: 'Akun Anda telah ditangguhkan.',
          reason: user.suspendedReason || 'Pelanggaran ketentuan layanan'
        });
      }
      if (user.status !== 'ACTIVE') {
        throw new UnauthorizedException('User is not active');
      }

      if (payload.deviceId) {
        try {
          const device = await this.prisma.device.findUnique({
            where: { id: payload.deviceId }
          });
          if (device && (device.status === 'REVOKED' || device.status === 'CONTAINED' || device.status === 'DECOMMISSIONED' || device.status === 'INACTIVE')) {
            throw new UnauthorizedException('Device session has been displaced or inactivated');
          }

          // Verify that this device still holds an active, non-expired session
          const session = await this.prisma.session.findFirst({
            where: {
              userId: payload.sub,
              deviceId: payload.deviceId
            }
          });
          if (!session) {
            throw new UnauthorizedException('Session has been terminated or displaced');
          }
        } catch (err: any) {
          if (err instanceof UnauthorizedException) throw err;
          // DB lookup error — allow through so the request can proceed
        }
      }

      request.user = {
        userId: payload.sub,
        deviceId: payload.deviceId
      };

      // Realtime online presence update in Redis (TTL: 120s)
      if (this.redis) {
        this.redis.set(`user:${payload.sub}:online`, '1', 'EX', 120).catch(() => {});
      }

      // Throttled update of device lastSeenAt (at most once every 20s)
      const now = Date.now();
      if (payload.deviceId) {
        const lastTouch = JwtAuthGuard.lastTouchMap.get(payload.deviceId) || 0;
        if (now - lastTouch > 20000) {
          JwtAuthGuard.lastTouchMap.set(payload.deviceId, now);
          this.prisma.device.update({
            where: { id: payload.deviceId },
            data: { lastSeenAt: new Date() }
          }).catch(() => {});
        }
      } else {
        const lastTouch = JwtAuthGuard.lastTouchMap.get(`user_${payload.sub}`) || 0;
        if (now - lastTouch > 20000) {
          JwtAuthGuard.lastTouchMap.set(`user_${payload.sub}`, now);
          this.prisma.device.updateMany({
            where: { userId: payload.sub, status: 'ACTIVE' },
            data: { lastSeenAt: new Date() }
          }).catch(() => {});
        }
      }
      return true;
    } catch (err: any) {
      if (err instanceof ForbiddenException) {
        throw err;
      }
      throw new UnauthorizedException(err.message || 'Invalid token');
    }
  }
}
