import { IsNotEmpty, IsString, IsOptional, IsInt } from 'class-validator';

export class AdminLoginDto {
  @IsString()
  @IsNotEmpty()
  roleName: string;

  @IsString()
  @IsNotEmpty()
  adminIdentifier: string;
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
