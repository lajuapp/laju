import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  UseGuards,
  UseInterceptors,
  Req,
  Res,
  HttpStatus,
  Optional,
  Logger,
  BadRequestException,
  InternalServerErrorException,
  Query
} from '@nestjs/common';
import { Request, Response } from 'express';
import { AdminService } from './admin.service';
import { SeaweedFsService } from '../../infrastructure/seaweedfs/seaweedfs.service';
import {
  AdminLoginDto,
  AdminPasswordLoginDto,
  CreateAdminDto,
  UpdateAdminDto,
  CreateWallpaperDto,
  UpdateWallpaperDto,
  CreateStickerPackDto,
  UpdateStickerPackDto,
  CreateStickerItemDto,
  CreateBulkStickersDto,
  RequestConversationAccessDto,
  ApproveConversationAccessDto,
  SuspendUserDto,
  CreateAnnouncementDto,
  UpdateAnnouncementDto,
  UpdateAppConfigDto,
  ReviewReportDto
} from './dto/admin.dto';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';
import { AdminAuditInterceptor } from '../../common/interceptors/admin-audit.interceptor';
import { AdminPermission } from '@secure-messenger/shared-types';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';

const MEDIA_DIR = process.env.ADMIN_MEDIA_DIR || path.join(process.cwd(), 'uploads', 'admin-media');
const RELEASES_DIR = process.env.APP_RELEASES_DIR || path.join(process.cwd(), 'uploads', 'releases');

@Controller('admin')
@UseInterceptors(AdminAuditInterceptor)
export class AdminController {
  private readonly logger = new Logger(AdminController.name);

  constructor(
    private readonly adminService: AdminService,
    @Optional() private readonly seaweedFs?: SeaweedFsService
  ) {
    try {
      if (!fs.existsSync(MEDIA_DIR)) {
        fs.mkdirSync(MEDIA_DIR, { recursive: true });
      }
    } catch (_) {}
  }

  // ─── AUTHENTICATION ──────────────────────────────────────────────
  @Post('auth/login')
  loginWithPassword(@Body() dto: AdminPasswordLoginDto) {
    return this.adminService.loginWithPassword(dto);
  }

  @Get('auth/me')
  @UseGuards(AdminAuthGuard)
  getMe(@Req() req: any) {
    return this.adminService.getMe(req.admin.adminId);
  }

  @Post('auth/logout')
  @UseGuards(AdminAuthGuard)
  logout(@Req() req: any) {
    const authHeader = req.headers['authorization'];
    const bearer = typeof authHeader === 'string' && authHeader.startsWith('Bearer ')
      ? authHeader.substring(7)
      : null;
    const token = bearer || req.headers['x-admin-token'];
    return this.adminService.logout(token);
  }

  // Legacy Session bootstrap
  @Post('session')
  createSession(@Body() dto: AdminLoginDto) {
    return this.adminService.createAdminSession(dto.roleName, dto.adminIdentifier);
  }

  // ─── DASHBOARD STATS ────────────────────────────────────────────
  @Get('stats')
  @UseGuards(AdminAuthGuard)
  getDashboardStats() {
    return this.adminService.getDashboardStats();
  }

  // ─── ADMIN TEAM MANAGEMENT ──────────────────────────────────────
  @Get('admins')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.ADMIN_ROLE_MANAGE)
  listAdmins() {
    return this.adminService.listAdmins();
  }

  @Get('roles')
  @UseGuards(AdminAuthGuard)
  listRoles() {
    return this.adminService.listRoles();
  }

  @Post('admins')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.ADMIN_ROLE_MANAGE)
  createAdmin(@Body() dto: CreateAdminDto) {
    return this.adminService.createAdmin(dto);
  }

  @Patch('admins/:id')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.ADMIN_ROLE_MANAGE)
  updateAdmin(@Param('id') id: string, @Body() dto: UpdateAdminDto) {
    return this.adminService.updateAdmin(id, dto);
  }

  @Delete('admins/:id')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.ADMIN_ROLE_MANAGE)
  deleteAdmin(@Param('id') id: string) {
    return this.adminService.deleteAdmin(id);
  }

  // ─── USERS MANAGEMENT ───────────────────────────────────────────
  @Get('users')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.USER_SUSPEND)
  listUsers() {
    return this.adminService.listUsers();
  }

  @Post('users/:id/suspend')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.USER_SUSPEND)
  suspendUser(@Param('id') userId: string, @Body() dto?: SuspendUserDto) {
    return this.adminService.suspendUser(userId, dto?.reason);
  }

  @Post('users/:id/restore')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.USER_SUSPEND)
  restoreUser(@Param('id') userId: string) {
    return this.adminService.restoreUser(userId);
  }

  @Get('users/:id/details')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.USER_SUSPEND)
  getUserDetails(@Param('id') userId: string) {
    return this.adminService.getUserDetails(userId);
  }

  // ─── USER REPORTS & MODERATION ──────────────────────────────────
  @Get('reports')
  @UseGuards(AdminAuthGuard)
  listReports(
    @Query('status') status?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string
  ) {
    return this.adminService.listReports(
      status,
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 20
    );
  }

  @Post('reports/:id/review')
  @UseGuards(AdminAuthGuard)
  @RequirePermissions(AdminPermission.USER_SUSPEND)
  reviewReport(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: ReviewReportDto
  ) {
    return this.adminService.reviewReport(id, req.admin.adminId, dto);
  }

  // ─── DEVICES MANAGEMENT ─────────────────────────────────────────
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

  // ─── WALLPAPERS MANAGEMENT ──────────────────────────────────────
  @Get('wallpapers')
  @UseGuards(AdminAuthGuard)
  listWallpapers() {
    return this.adminService.listWallpapers();
  }

  @Get('wallpapers/public')
  getActiveWallpapers() {
    return this.adminService.getActiveWallpapers();
  }

  @Post('wallpapers')
  @UseGuards(AdminAuthGuard)
  createWallpaper(@Body() dto: CreateWallpaperDto) {
    return this.adminService.createWallpaper(dto);
  }

  @Patch('wallpapers/:id')
  @UseGuards(AdminAuthGuard)
  updateWallpaper(@Param('id') id: string, @Body() dto: UpdateWallpaperDto) {
    return this.adminService.updateWallpaper(id, dto);
  }

  @Delete('wallpapers/:id')
  @UseGuards(AdminAuthGuard)
  deleteWallpaper(@Param('id') id: string) {
    return this.adminService.deleteWallpaper(id);
  }

  // ─── STICKERS MANAGEMENT ────────────────────────────────────────
  @Get('stickers/packs')
  @UseGuards(AdminAuthGuard)
  listStickerPacks() {
    return this.adminService.listStickerPacks();
  }

  @Get('stickers/public')
  getActiveStickerPacks() {
    return this.adminService.getActiveStickerPacks();
  }

  @Post('stickers/packs')
  @UseGuards(AdminAuthGuard)
  createStickerPack(@Body() dto: CreateStickerPackDto) {
    return this.adminService.createStickerPack(dto);
  }

  @Patch('stickers/packs/:id')
  @UseGuards(AdminAuthGuard)
  updateStickerPack(@Param('id') id: string, @Body() dto: UpdateStickerPackDto) {
    return this.adminService.updateStickerPack(id, dto);
  }

  @Delete('stickers/packs/:id')
  @UseGuards(AdminAuthGuard)
  deleteStickerPack(@Param('id') id: string) {
    return this.adminService.deleteStickerPack(id);
  }

  @Post('stickers/packs/:packId/stickers')
  @UseGuards(AdminAuthGuard)
  addStickerItem(
    @Param('packId') packId: string,
    @Body() dto: CreateStickerItemDto
  ) {
    return this.adminService.addStickerItem(packId, dto);
  }

  @Post('stickers/packs/:packId/stickers/bulk')
  @UseGuards(AdminAuthGuard)
  addBulkStickers(
    @Param('packId') packId: string,
    @Body() dto: CreateBulkStickersDto
  ) {
    return this.adminService.addBulkStickers(packId, dto.items);
  }

  @Delete('stickers/:id')
  @UseGuards(AdminAuthGuard)
  deleteStickerItem(@Param('id') id: string) {
    return this.adminService.deleteStickerItem(id);
  }

  // ─── MEDIA UPLOAD & SERVING ─────────────────────────────────────
  @Post('upload')
  @UseGuards(AdminAuthGuard)
  async uploadMedia(
    @Body() body: { filename: string; mimeType: string; base64Data: string }
  ) {
    if (!body?.base64Data) {
      throw new BadRequestException('base64Data is required');
    }

    const rawData = body.base64Data.includes(',')
      ? body.base64Data.split(',')[1]
      : body.base64Data;
    const buffer = Buffer.from(rawData, 'base64');
    const rawExt = body.filename?.split('.').pop()?.toLowerCase() || 'png';
    const cleanExt = rawExt.replace(/[^a-zA-Z0-9]/g, '') || 'png';
    const blobId = `asset-${crypto.randomBytes(12).toString('hex')}.${cleanExt}`;
    const contentType = body.mimeType || 'image/png';

    // 1. Primary: Persist directly to SeaweedFS Object Storage
    let seaweedUploaded = false;
    if (this.seaweedFs) {
      try {
        await this.seaweedFs.uploadBlob(blobId, buffer, contentType);
        seaweedUploaded = true;
      } catch (swErr: any) {
        this.logger.error(`Failed to upload media to SeaweedFS: ${swErr.message}`);
      }
    }

    // 2. Also keep local copy as cache/fallback if configured
    try {
      if (!fs.existsSync(MEDIA_DIR)) {
        fs.mkdirSync(MEDIA_DIR, { recursive: true });
      }
      const localFilePath = path.join(MEDIA_DIR, blobId);
      await fs.promises.writeFile(localFilePath, buffer);
    } catch (fsErr: any) {
      this.logger.warn(`Notice: Local disk backup skipped: ${fsErr.message}`);
    }

    if (!seaweedUploaded && !fs.existsSync(path.join(MEDIA_DIR, blobId))) {
      throw new InternalServerErrorException('Gagal menyimpan berkas ke media storage.');
    }

    // Return URL accessible via GET /admin/media/:blobId
    return {
      url: `/admin/media/${blobId}`,
      blobId,
      filename: body.filename,
      size: buffer.length
    };
  }

  @Get('media/:blobId')
  async getMedia(
    @Param('blobId') blobId: string,
    @Req() req: Request,
    @Res() res: Response
  ) {
    const safeBlobId = path.basename(blobId);
    if (!safeBlobId || safeBlobId.includes('..')) {
      return res.status(HttpStatus.BAD_REQUEST).json({ error: 'Invalid blob ID' });
    }

    const ext = safeBlobId.split('.').pop()?.toLowerCase() || 'png';
    let mime = 'image/png';
    if (ext === 'jpg' || ext === 'jpeg') mime = 'image/jpeg';
    else if (ext === 'webp') mime = 'image/webp';
    else if (ext === 'gif') mime = 'image/gif';
    else if (ext === 'svg') mime = 'image/svg+xml';
    else if (ext === 'apng') mime = 'image/apng';
    else if (ext === 'mp4') mime = 'video/mp4';
    else if (ext === 'webm') mime = 'video/webm';
    else if (ext === 'mov') mime = 'video/quicktime';
    else if (ext === 'mkv') mime = 'video/x-matroska';

    // 1. Primary: Stream directly from SeaweedFS Object Storage
    if (this.seaweedFs) {
      const streamed = await this.seaweedFs.streamBlob(safeBlobId, req, res, mime);
      if (streamed) return;
    }

    // 2. Fallback: Check local disk directories (legacy migration support)
    const candidateDirs = [
      MEDIA_DIR,
      '/app/uploads/admin-media',
      '/app/apps/api/uploads/admin-media',
      path.join(process.cwd(), 'uploads', 'admin-media'),
    ].filter(Boolean) as string[];

    for (const dir of candidateDirs) {
      const localFilePath = path.join(dir, safeBlobId);
      if (fs.existsSync(localFilePath)) {
        try {
          // Auto-migrate legacy file to SeaweedFS in background
          if (this.seaweedFs) {
            fs.promises.readFile(localFilePath)
              .then(buf => this.seaweedFs?.uploadBlob(safeBlobId, buf, mime))
              .catch(() => {});
          }

          const stat = fs.statSync(localFilePath);
          const fileSize = stat.size;
          const range = req.headers.range;

          res.setHeader('Accept-Ranges', 'bytes');
          res.setHeader('Cache-Control', 'public, max-age=86400');
          res.setHeader('Access-Control-Allow-Origin', '*');
          res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');

          if (range) {
            const parts = range.replace(/bytes=/, '').split('-');
            const start = parseInt(parts[0], 10);
            const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;

            if (start >= fileSize || end >= fileSize || start > end) {
              res.setHeader('Content-Range', `bytes */${fileSize}`);
              return res.status(HttpStatus.REQUESTED_RANGE_NOT_SATISFIABLE).end();
            }

            const chunksize = end - start + 1;
            const stream = fs.createReadStream(localFilePath, { start, end });
            res.writeHead(HttpStatus.PARTIAL_CONTENT, {
              'Content-Range': `bytes ${start}-${end}/${fileSize}`,
              'Accept-Ranges': 'bytes',
              'Content-Length': chunksize,
              'Content-Type': mime,
              'Access-Control-Allow-Origin': '*',
              'Cross-Origin-Resource-Policy': 'cross-origin',
            });
            return stream.pipe(res);
          }

          res.setHeader('Content-Type', mime);
          res.setHeader('Content-Length', fileSize);
          const stream = fs.createReadStream(localFilePath);
          return stream.pipe(res);
        } catch (err: any) {
          this.logger.error(`Error reading local file: ${err.message}`);
        }
      }
    }

    return res.status(HttpStatus.NOT_FOUND).json({ error: 'Media not found' });
  }

  // ─── CONVERSATIONS AUDIT & CONTROLLED ACCESS ────────────────────
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

  // ─── ANNOUNCEMENTS ───────────────────────────────────────────────
  @Get('announcements')
  @UseGuards(AdminAuthGuard)
  listAnnouncements() {
    return this.adminService.listAnnouncements();
  }

  @Get('announcements/public')
  getActiveAnnouncements(@Query('userId') userId?: string) {
    return this.adminService.getActiveAnnouncements(userId);
  }

  @Post('announcements')
  @UseGuards(AdminAuthGuard)
  createAnnouncement(@Body() dto: CreateAnnouncementDto) {
    return this.adminService.createAnnouncement(dto);
  }

  @Patch('announcements/:id')
  @UseGuards(AdminAuthGuard)
  updateAnnouncement(@Param('id') id: string, @Body() dto: UpdateAnnouncementDto) {
    return this.adminService.updateAnnouncement(id, dto);
  }

  @Delete('announcements/:id')
  @UseGuards(AdminAuthGuard)
  deleteAnnouncement(@Param('id') id: string) {
    return this.adminService.deleteAnnouncement(id);
  }

  // ─── APP SYSTEM CONFIG ───────────────────────────────────────────
  @Get('app-config')
  @UseGuards(AdminAuthGuard)
  getAppConfig() {
    return this.adminService.getAppConfig();
  }

  @Get('app-config/public')
  getPublicAppConfig() {
    return this.adminService.getAppConfig();
  }

  @Patch('app-config')
  @UseGuards(AdminAuthGuard)
  updateAppConfig(@Body() dto: UpdateAppConfigDto) {
    return this.adminService.updateAppConfig(dto);
  }

  @Post('app-config/upload-apk')
  @UseGuards(AdminAuthGuard)
  async uploadApk(
    @Body()
    body: {
      filename: string;
      base64Data: string;
      version?: string;
      minVersion?: string;
      forceUpdate?: boolean;
      releaseNotes?: string;
    }
  ) {
    if (!body?.base64Data) {
      throw new BadRequestException('base64Data berkas APK wajib disertakan');
    }

    const rawFilename = body.filename || 'laju-latest.apk';
    if (!rawFilename.toLowerCase().endsWith('.apk')) {
      throw new BadRequestException('Berkas yang diunggah harus memiliki ekstensi .apk');
    }

    const rawData = body.base64Data.includes(',')
      ? body.base64Data.split(',')[1]
      : body.base64Data;
    const buffer = Buffer.from(rawData, 'base64');

    if (buffer.length < 1000) {
      throw new BadRequestException('Ukuran berkas APK tidak valid (terlalu kecil)');
    }

    const sha256 = crypto.createHash('sha256').update(buffer).digest('hex');
    const version = body.version?.trim() || '1.0.0';
    const cleanVersion = version.replace(/[^a-zA-Z0-9.-]/g, '') || '1.0.0';
    const versionedFilename = `laju-v${cleanVersion}.apk`;

    // 1. Primary: Simpan langsung ke SeaweedFS Object Storage
    let seaweedApkUploaded = false;
    if (this.seaweedFs) {
      try {
        await this.seaweedFs.uploadBlob(versionedFilename, buffer, 'application/vnd.android.package-archive');
        await this.seaweedFs.uploadBlob('laju-latest.apk', buffer, 'application/vnd.android.package-archive');
        seaweedApkUploaded = true;
      } catch (swErr: any) {
        this.logger.error(`SeaweedFS upload APK failed: ${swErr.message}`);
      }
    }

    // 2. Simpan backup lokal jika direktori tersedia
    try {
      if (!fs.existsSync(RELEASES_DIR)) {
        fs.mkdirSync(RELEASES_DIR, { recursive: true });
      }
      const versionedPath = path.join(RELEASES_DIR, versionedFilename);
      const latestPath = path.join(RELEASES_DIR, 'laju-latest.apk');
      await fs.promises.writeFile(versionedPath, buffer);
      await fs.promises.writeFile(latestPath, buffer);
    } catch (fsErr: any) {
      this.logger.warn(`Notice: Local disk APK backup skipped: ${fsErr.message}`);
    }

    if (!seaweedApkUploaded && !fs.existsSync(path.join(RELEASES_DIR, versionedFilename))) {
      throw new InternalServerErrorException('Gagal menyimpan berkas APK ke storage');
    }

    // 3. Update database AppSystemConfig
    const updatedConfig = await this.adminService.updateAppConfig({
      latestAndroidVersion: version,
      minAndroidVersion: body.minVersion || undefined,
      forceUpdate: body.forceUpdate !== undefined ? body.forceUpdate : undefined,
      apkUrl: '/admin/app-config/download-apk',
      apkFilename: versionedFilename,
      apkSize: buffer.length,
      apkSha256: sha256,
      releaseNotes: body.releaseNotes || undefined,
    });

    return {
      success: true,
      message: `Berkas APK ${versionedFilename} (${(buffer.length / (1024 * 1024)).toFixed(1)} MB) berhasil diunggah dan dirilis.`,
      config: updatedConfig,
      sha256,
      size: buffer.length,
      filename: versionedFilename,
    };
  }

  @Get('app-config/download-apk')
  async downloadApk(@Req() req: Request, @Res() res: Response) {
    const config = await this.adminService.getAppConfig();
    const filename = config.apkFilename || 'laju-latest.apk';

    // 1. Primary: Stream langsung dari SeaweedFS
    if (this.seaweedFs) {
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      const streamed = await this.seaweedFs.streamBlob(filename, req, res, 'application/vnd.android.package-archive');
      if (streamed) return;
      const streamedLatest = await this.seaweedFs.streamBlob('laju-latest.apk', req, res, 'application/vnd.android.package-archive');
      if (streamedLatest) return;
    }

    // 2. Fallback: Cari di disk lokal releases
    const candidateDirs = [
      RELEASES_DIR,
      '/app/uploads/releases',
      '/app/apps/api/uploads/releases',
      path.join(process.cwd(), 'uploads', 'releases'),
    ].filter(Boolean) as string[];

    for (const dir of candidateDirs) {
      const latestPath = path.join(dir, 'laju-latest.apk');
      const versionedPath = path.join(dir, filename);
      const targetPath = fs.existsSync(latestPath)
        ? latestPath
        : fs.existsSync(versionedPath)
        ? versionedPath
        : null;

      if (targetPath) {
        res.setHeader('Content-Type', 'application/vnd.android.package-archive');
        res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
        res.setHeader('Cache-Control', 'no-cache');
        return fs.createReadStream(targetPath).pipe(res);
      }
    }

    return res.status(HttpStatus.NOT_FOUND).json({
      error: 'Berkas APK belum diunggah dari Backoffice',
    });
  }
}

