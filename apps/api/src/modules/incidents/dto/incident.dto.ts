import { IsNotEmpty, IsString, IsEnum, IsOptional, IsBoolean } from 'class-validator';
import { IncidentSeverity } from '@secure-messenger/shared-types';

export class CreateIncidentDto {
  @IsString()
  @IsNotEmpty()
  title: string;

  @IsString()
  @IsNotEmpty()
  description: string;

  @IsEnum(IncidentSeverity)
  @IsOptional()
  severity?: IncidentSeverity;

  @IsString()
  @IsOptional()
  targetUserId?: string;

  @IsString()
  @IsOptional()
  targetDeviceId?: string;
}

export class ContainTargetDto {
  @IsString()
  @IsNotEmpty()
  targetId: string;

  @IsBoolean()
  @IsOptional()
  wipeApplicationData?: boolean;
}
