import { IsOptional, IsString, IsEmail, Matches, MinLength, MaxLength, IsBoolean } from 'class-validator';

export class UpdateUserProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(30)
  @Matches(/^[a-zA-Z0-9_]+$/, { message: 'Username can only contain letters, numbers, and underscores' })
  username?: string;

  @IsOptional()
  @IsEmail({}, { message: 'Must be a valid email address' })
  email?: string;

  @IsOptional()
  @IsString()
  @Matches(/^\+?[1-9]\d{1,14}$/, { message: 'Must be a valid E.164 phone number' })
  phoneNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(140)
  status?: string;

  @IsOptional()
  @IsBoolean()
  twoFactorEnabled?: boolean;

  @IsOptional()
  @IsString()
  @MinLength(4)
  @MaxLength(6)
  twoFactorPin?: string;
}

export class SearchUsersQueryDto {
  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  limit?: string;

  @IsOptional()
  offset?: string;
}
