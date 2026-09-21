import { IsNotEmpty, IsString, IsArray, ValidateNested, IsNumber, IsOptional } from 'class-validator';
import { Type } from 'class-transformer';

export class SignedPreKeyDto {
  @IsNumber()
  keyId: number;

  @IsString()
  @IsNotEmpty()
  publicKey: string;

  @IsString()
  @IsNotEmpty()
  signature: string;
}

export class OneTimePreKeyDto {
  @IsNumber()
  keyId: number;

  @IsString()
  @IsNotEmpty()
  publicKey: string;
}

export class RegisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  deviceUuid: string;

  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  devicePublicKey?: string;

  @IsString()
  @IsOptional()
  platform?: string;

  @IsString()
  @IsOptional()
  attestationData?: string;

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
  @IsNotEmpty()
  identityKey: string;

  @ValidateNested()
  @Type(() => SignedPreKeyDto)
  signedPreKey: SignedPreKeyDto;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => OneTimePreKeyDto)
  oneTimePreKeys: OneTimePreKeyDto[];
}

export class DeviceChallengeRequestDto {
  @IsString()
  @IsOptional()
  deviceUuid?: string;
}

export class DeviceVerifyChallengeDto {
  @IsString()
  @IsNotEmpty()
  deviceUuid: string;

  @IsString()
  @IsNotEmpty()
  challenge: string;

  @IsString()
  @IsNotEmpty()
  signature: string;
}

export class UpdatePushTokenDto {
  @IsString()
  @IsNotEmpty()
  deviceUuid: string;

  @IsString()
  @IsNotEmpty()
  pushToken: string;

  @IsString()
  @IsOptional()
  endpoint?: string;
}

