import { IsNotEmpty, IsString, IsOptional, IsInt, IsEmail, IsBoolean, MinLength, IsArray } from 'class-validator';

export class AdminLoginDto {
  @IsString()
  @IsNotEmpty()
  roleName: string;

  @IsString()
  @IsNotEmpty()
  adminIdentifier: string;
}

export class AdminPasswordLoginDto {
  @IsString()
  @IsNotEmpty()
  identifier: string; // username or email

  @IsString()
  @IsNotEmpty()
  @MinLength(6)
  password: string;
}

export class CreateAdminDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  username: string;

  @IsEmail()
  @IsNotEmpty()
  email: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(6)
  password: string;

  @IsString()
  @IsNotEmpty()
  roleId: string;
}

export class UpdateAdminDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  username?: string;

  @IsEmail()
  @IsOptional()
  email?: string;

  @IsString()
  @IsOptional()
  @MinLength(6)
  password?: string;

  @IsString()
  @IsOptional()
  roleId?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

export class CreateWallpaperDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsOptional()
  category?: string; // SOLID, GRADIENT, PATTERN, IMAGE

  @IsString()
  @IsOptional()
  colorHex?: string;

  @IsString()
  @IsOptional()
  imageUrl?: string;

  @IsString()
  @IsOptional()
  thumbnailUrl?: string;

  @IsBoolean()
  @IsOptional()
  isDefault?: boolean;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsInt()
  @IsOptional()
  sortOrder?: number;
}

export class UpdateWallpaperDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  category?: string;

  @IsString()
  @IsOptional()
  colorHex?: string;

  @IsString()
  @IsOptional()
  imageUrl?: string;

  @IsString()
  @IsOptional()
  thumbnailUrl?: string;

  @IsBoolean()
  @IsOptional()
  isDefault?: boolean;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsInt()
  @IsOptional()
  sortOrder?: number;
}

export class CreateStickerPackDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsString()
  @IsOptional()
  publisher?: string;

  @IsString()
  @IsOptional()
  coverUrl?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsInt()
  @IsOptional()
  sortOrder?: number;
}

export class UpdateStickerPackDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsString()
  @IsOptional()
  publisher?: string;

  @IsString()
  @IsOptional()
  coverUrl?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsInt()
  @IsOptional()
  sortOrder?: number;
}

export class CreateStickerItemDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  imageUrl: string;

  @IsString()
  @IsOptional()
  emoji?: string;
}

export class CreateBulkStickersDto {
  @IsArray()
  items: CreateStickerItemDto[];
}

export class RequestConversationAccessDto {
  @IsString()
  @IsNotEmpty()
  reason: string;

  @IsInt()
  @IsOptional()
  validityMinutes?: number;
}

export class ApproveConversationAccessDto {
  @IsString()
  @IsNotEmpty()
  grantId: string;
}

export class SuspendUserDto {
  @IsString()
  @IsOptional()
  reason?: string;
}

export class CreateAnnouncementDto {
  @IsString()
  @IsNotEmpty()
  title: string;

  @IsString()
  @IsNotEmpty()
  content: string;

  @IsString()
  @IsOptional()
  type?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsString()
  @IsOptional()
  targetType?: string; // 'ALL' | 'SPECIFIC' | 'BULK'

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  targetUserIds?: string[];

  @IsString()
  @IsOptional()
  mediaType?: string; // 'TEXT' | 'IMAGE'

  @IsString()
  @IsOptional()
  mediaUrl?: string;

  @IsString()
  @IsOptional()
  backgroundColor?: string;

  @IsString()
  @IsOptional()
  actionUrl?: string;

  @IsString()
  @IsOptional()
  actionTitle?: string;

  @IsInt()
  @IsOptional()
  durationHours?: number;
}

export class UpdateAnnouncementDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  content?: string;

  @IsString()
  @IsOptional()
  type?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsString()
  @IsOptional()
  targetType?: string;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  targetUserIds?: string[];

  @IsString()
  @IsOptional()
  mediaType?: string;

  @IsString()
  @IsOptional()
  mediaUrl?: string;

  @IsString()
  @IsOptional()
  backgroundColor?: string;

  @IsString()
  @IsOptional()
  actionUrl?: string;

  @IsString()
  @IsOptional()
  actionTitle?: string;

  @IsInt()
  @IsOptional()
  durationHours?: number;
}

export class UpdateAppConfigDto {
  @IsString()
  @IsOptional()
  minAndroidVersion?: string;

  @IsString()
  @IsOptional()
  latestAndroidVersion?: string;

  @IsBoolean()
  @IsOptional()
  forceUpdate?: boolean;

  @IsBoolean()
  @IsOptional()
  maintenanceMode?: boolean;

  @IsString()
  @IsOptional()
  maintenanceMessage?: string;

  @IsString()
  @IsOptional()
  apkUrl?: string;

  @IsString()
  @IsOptional()
  apkFilename?: string;

  @IsInt()
  @IsOptional()
  apkSize?: number;

  @IsString()
  @IsOptional()
  apkSha256?: string;

  @IsString()
  @IsOptional()
  releaseNotes?: string;
}

export class ReviewReportDto {
  @IsString()
  @IsNotEmpty()
  action: 'APPROVE' | 'REJECT';

  @IsInt()
  @IsOptional()
  scoreDeduction?: number;

  @IsString()
  @IsOptional()
  reviewNotes?: string;

  @IsBoolean()
  @IsOptional()
  suspendUser?: boolean;
}

export class UpdateTicketDto {
  @IsString()
  @IsOptional()
  status?: 'OPEN' | 'IN_PROGRESS' | 'RESOLVED' | 'CLOSED';

  @IsString()
  @IsOptional()
  priority?: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

  @IsString()
  @IsOptional()
  adminNotes?: string;

  @IsString()
  @IsOptional()
  responseMessage?: string;

  @IsString()
  @IsOptional()
  assignedToId?: string;
}

export class MaintenanceResetDto {
  @IsBoolean()
  @IsOptional()
  resetChats?: boolean;

  @IsBoolean()
  @IsOptional()
  resetGroups?: boolean;

  @IsBoolean()
  @IsOptional()
  resetUserStatuses?: boolean;

  @IsBoolean()
  @IsOptional()
  resetCalls?: boolean;

  @IsBoolean()
  @IsOptional()
  resetUserAccountStatuses?: boolean;

  @IsBoolean()
  @IsOptional()
  wipeAllUsers?: boolean;

  @IsBoolean()
  @IsOptional()
  reseedDefaults?: boolean;

  @IsBoolean()
  @IsOptional()
  deleteWallpapers?: boolean;

  @IsBoolean()
  @IsOptional()
  deleteStickers?: boolean;

  @IsString()
  @IsNotEmpty()
  confirmationCode: string;
}

export class TrackDownloadEventDto {
  @IsString()
  @IsOptional()
  version?: string;

  @IsString()
  @IsOptional()
  source?: string;

  @IsString()
  @IsOptional()
  referrer?: string;
}



