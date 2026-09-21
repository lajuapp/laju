import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
  UseInterceptors,
  Req
} from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminLoginDto, RequestConversationAccessDto, ApproveConversationAccessDto } from './dto/admin.dto';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';
import { AdminAuditInterceptor } from '../../common/interceptors/admin-audit.interceptor';
import { AdminPermission } from '@secure-messenger/shared-types';

@Controller('admin')
@UseInterceptors(AdminAuditInterceptor)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  // Session bootstrap / auth
  @Post('session')
  createSession(@Body() dto: AdminLoginDto) {
    return this.adminService.createAdminSession(dto.roleName, dto.adminIdentifier);
  }

  @Get('users')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.USER_SUSPEND)
  listUsers() {
    return this.adminService.listUsers();
  }

  @Post('users/:id/suspend')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.USER_SUSPEND)
  suspendUser(@Param('id') userId: string) {
    return this.adminService.suspendUser(userId);
  }

  @Post('users/:id/restore')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.USER_SUSPEND)
  restoreUser(@Param('id') userId: string) {
    return this.adminService.restoreUser(userId);
  }

  @Get('devices')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.DEVICE_REVOKE)
  listDevices() {
    return this.adminService.listDevices();
  }

  @Post('devices/:id/revoke')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.DEVICE_REVOKE)
  revokeDevice(@Param('id') deviceId: string) {
    return this.adminService.revokeDevice(deviceId);
  }

  @Get('conversations')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.CONVERSATION_METADATA_READ)
  listConversations() {
    return this.adminService.listConversations();
  }

  @Get('groups')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.CONVERSATION_METADATA_READ)
  listGroups() {
    return this.adminService.listGroups();
  }

  @Post('conversations/:id/access-request')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.CONVERSATION_CONTENT_REQUEST)
  requestAccess(
    @Req() req: any,
    @Param('id') conversationId: string,
    @Body() dto: RequestConversationAccessDto
  ) {
    return this.adminService.requestConversationAccess(req.admin.adminId, conversationId, dto);
  }

  @Post('conversations/:id/access-approve')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.CONVERSATION_CONTENT_APPROVE)
  approveAccess(
    @Req() req: any,
    @Body() dto: ApproveConversationAccessDto
  ) {
    return this.adminService.approveConversationAccess(req.admin.adminId, dto.grantId);
  }

  @Get('conversations/:id/messages')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.CONVERSATION_METADATA_READ)
  getAuthorizedMessages(@Req() req: any, @Param('id') conversationId: string) {
    return this.adminService.readAuthorizedConversationMessages(req.admin.adminId, conversationId);
  }

  @Get('location')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.LOCATION_READ_COARSE)
  getLocation() {
    return this.adminService.getLocationTrails();
  }

  @Get('security-events')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.AUDIT_READ)
  getSecurityEvents() {
    return this.adminService.getSecurityEvents();
  }

  @Get('audit')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.AUDIT_READ)
  getAuditLogs() {
    return this.adminService.getAuditLogs();
  }
}
