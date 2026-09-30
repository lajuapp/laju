import { IsNotEmpty, IsOptional, IsString, MinLength, IsArray, ValidateNested, IsBoolean } from 'class-validator';
import { Type } from 'class-transformer';
import { SignedPreKeyDto, OneTimePreKeyDto } from '../../devices/dto/devices.dto';

export class RegisterIdentityDto {
  @IsString()
  @IsNotEmpty()
  identityPublicKey: string;

  @IsString()
  @IsNotEmpty()
  username: string;

  @IsString()
  @IsNotEmpty()
  deviceUuid: string;

  @IsString()
  @IsNotEmpty()
  devicePublicKey: string;

  @IsString()
  @IsOptional()
  deviceName?: string;

  @IsString()
  @IsOptional()
  platform?: string;

  @IsString()
  @IsOptional()
  deviceModel?: string;

  @IsString()
  @IsOptional()
  osVersion?: string;

  @IsString()
  @IsOptional()
  appVersion?: string;

  @IsString()
  @IsOptional()
  registrationLocation?: string;

  @IsString()
  @IsOptional()
  registrationIp?: string;

  @IsString()
  @IsOptional()
  pushToken?: string;

  @IsString()
  @IsOptional()
  attestationData?: string;

  @ValidateNested()
  @Type(() => SignedPreKeyDto)
  signedPreKey: SignedPreKeyDto;

  @IsArray()
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => OneTimePreKeyDto)
  oneTimePreKeys?: OneTimePreKeyDto[];

  @IsString()
  @IsOptional()
  pin?: string;
}

export class SendOtpDto {
  @IsString()
  @IsNotEmpty()
  identifier: string; // phone number (+62...) or email address

  @IsString()
  @IsOptional()
  type?: string; // 'REGISTER' | 'LOGIN' | 'RECOVERY'
}

export class VerifyOtpDto {
  @IsString()
  @IsNotEmpty()
  identifier: string;

  @IsString()
  @IsNotEmpty()
  code: string;
}

export class RegisterDto {
  @IsString()
  @IsNotEmpty()
  username: string;

  @IsString()
  @IsOptional()
  identifier?: string; // phone or email

  @IsString()
  @IsOptional()
  email?: string;

  @IsString()
  @IsOptional()
  phoneNumber?: string;

  @IsString()
  @IsOptional()
  @MinLength(6)
  password?: string;

  @IsString()
  @IsOptional()
  otpCode?: string;

  @IsString()
  @IsNotEmpty()
  deviceUuid: string;

  @IsString()
  @IsOptional()
  deviceName?: string;
}

export class LoginDto {
  @IsString()
  @IsNotEmpty()
  identifier: string; // username, email, or phone number

  @IsString()
  @IsOptional()
  password?: string;

  @IsString()
  @IsOptional()
  otpCode?: string;

  @IsString()
  @IsNotEmpty()
  deviceUuid: string;

  @IsString()
  @IsOptional()
  deviceName?: string;
}

export class Verify2FaDto {
  @IsString()
  @IsNotEmpty()
  tempToken: string;

  @IsString()
  @IsNotEmpty()
  pin: string; // 6-digit security PIN

  @IsString()
  @IsNotEmpty()
  deviceUuid: string;

  @IsString()
  @IsOptional()
  deviceName?: string;
}

export class RefreshDto {
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class RestoreIdentityDto {
  @IsString()
  @IsNotEmpty()
  identitySecret: string;

  @IsString()
  @IsOptional()
  identityPublicKey?: string;

  @IsString()
  @IsNotEmpty()
  deviceUuid: string;

  @IsString()
  @IsOptional()
  deviceName?: string;

  @IsString()
  @IsOptional()
  devicePublicKey?: string;

  @IsString()
  @IsOptional()
  platform?: string;

  @IsString()
  @IsOptional()
  pin?: string;

  @IsBoolean()
  @IsOptional()
  emergencyOverride?: boolean;
}

export class TransferResponseDto {
  @IsString()
  @IsNotEmpty()
  requestId: string;

  @IsString()
  @IsNotEmpty()
  action: 'APPROVE' | 'REJECT';
}
