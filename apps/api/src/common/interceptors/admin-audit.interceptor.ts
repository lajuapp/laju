import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

@Injectable()
export class AdminAuditInterceptor implements NestInterceptor {
  constructor(private readonly prisma: PrismaService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const admin = request.admin;
    const method = request.method;
    const path = request.path;

    // Only audit mutating or sensitive endpoints
    const isSensitive =
      method !== 'GET' ||
      path.includes('/messages') ||
      path.includes('/location');

    return next.handle().pipe(
      tap(async () => {
        if (admin && isSensitive) {
          try {
            await this.prisma.adminAuditEvent.create({
              data: {
                adminId: admin.adminId,
                action: `${method} ${path}`,
                resource: path.split('/')[2] || 'unknown',
                resourceId: request.params?.id || null,
                details: JSON.stringify({
                  params: request.params,
                  query: request.query,
                  bodyKeys: Object.keys(request.body || {})
                }),
                ipAddress: request.ip || 'unknown'
              }
            });
          } catch (err) {
            // Never block response on audit failure, but log to console
            console.error('Failed to write admin audit event:', err);
          }
        }
      })
    );
  }
}
