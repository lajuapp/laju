import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class StartMigrationDto {
  @IsString()
  @IsNotEmpty()
  sourceEphemeralKey: string;
}

export class JoinMigrationDto {
  @IsString()
  @IsNotEmpty()
  targetDeviceUuid: string;

  @IsString()
  @IsNotEmpty()
  targetPublicKey: string;

  @IsString()
  @IsNotEmpty()
  targetEphemeralKey: string;

  @IsString()
  @IsOptional()
  deviceName?: string;

  @IsString()
  @IsOptional()
  platform?: string;

  @IsString()
  @IsOptional()
  attestationData?: string;
}

export class VerifySasDto {
  @IsString()
  @IsNotEmpty()
  sasCode: string;

  @IsString()
  @IsOptional()
  signature?: string;
}

export class CommitMigrationDto {
  @IsString()
  @IsOptional()
  signature?: string;
}
