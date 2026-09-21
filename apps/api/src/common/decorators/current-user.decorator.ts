import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export interface AuthContext {
  userId: string;
  deviceId?: string;
  adminId?: string;
  roleId?: string;
  permissions?: string[];
}

export const CurrentUser = createParamDecorator(
  (data: keyof AuthContext | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user = request.user as AuthContext;
    return data ? user?.[data] : user;
  }
);
