import { IsNotEmpty, IsString, IsEnum, MinLength, MaxLength, IsOptional, IsInt, Min, Max } from 'class-validator';

export enum ReportCategory {
  SPAM = 'SPAM',
  SCAM = 'SCAM',
  HARASSMENT = 'HARASSMENT',
  IMPERSONATION = 'IMPERSONATION',
  INAPPROPRIATE_CONTENT = 'INAPPROPRIATE_CONTENT',
  OTHER = 'OTHER',
}

export enum ReportAction {
  APPROVE = 'APPROVE',
  REJECT = 'REJECT',
}

export class CreateUserReportDto {
  @IsNotEmpty({ message: 'Reported user ID is required' })
  @IsString()
  reportedUserId!: string;

  @IsNotEmpty({ message: 'Report category is required' })
  @IsEnum(ReportCategory, { message: 'Invalid report category' })
  category!: ReportCategory;

  @IsNotEmpty({ message: 'Reason is required and cannot be empty' })
  @IsString()
  @MinLength(10, { message: 'Reason must be at least 10 characters long' })
  @MaxLength(1000, { message: 'Reason cannot exceed 1000 characters' })
  reason!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(50)
  scoreDeduction?: number;
}

export class ReviewUserReportDto {
  @IsNotEmpty({ message: 'Action is required (APPROVE or REJECT)' })
  @IsEnum(ReportAction, { message: 'Action must be APPROVE or REJECT' })
  action!: ReportAction;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reviewNotes?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  scoreDeduction?: number;
}
