import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService
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
      if (!user || user.status !== 'ACTIVE') {
        throw new UnauthorizedException('User is not active');
      }

      if (payload.deviceId) {
        const device = await this.prisma.device.findUnique({
          where: { id: payload.deviceId }
        });
        if (!device || device.status !== 'ACTIVE') {
          throw new UnauthorizedException('Device is revoked or contained');
        }
      }

      request.user = {
        userId: payload.sub,
        deviceId: payload.deviceId
      };
      return true;
    } catch (err: any) {
      throw new UnauthorizedException(err.message || 'Invalid token');
    }
  }
}
