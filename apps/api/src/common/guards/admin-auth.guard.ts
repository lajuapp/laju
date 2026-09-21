import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
  ForbiddenException
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';

@Injectable()
export class AdminAuthGuard implements CanActivate {
  constructor(
    private readonly prisma: PrismaService,
    private readonly reflector: Reflector
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const adminToken = request.headers['x-admin-token'] || (request.cookies && request.cookies['admin_session']);

    if (!adminToken) {
      throw new UnauthorizedException('Missing admin session token');
    }

    const session = await this.prisma.adminSession.findFirst({
      where: {
        tokenHash: adminToken,
        expiresAt: { gt: new Date() }
      },
      include: {
        role: {
          include: {
            permissions: {
              include: {
                permission: true
              }
            }
          }
        }
      }
    });

    if (!session) {
      throw new UnauthorizedException('Invalid or expired admin session');
    }

    const permissions = session.role.permissions.map((rp) => rp.permission.slug);

    request.admin = {
      adminId: session.adminId,
      roleId: session.roleId,
      roleName: session.role.name,
      permissions
    };

    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()]
    );

    if (requiredPermissions && requiredPermissions.length > 0) {
      // Super Admin bypasses individual permission check
      if (session.role.name !== 'Super Admin') {
        const hasAllPermissions = requiredPermissions.every((perm) =>
          permissions.includes(perm)
        );
        if (!hasAllPermissions) {
          throw new ForbiddenException(
            `Insufficient permissions. Required: ${requiredPermissions.join(', ')}`
          );
        }
      }
    }

    return true;
  }
}
