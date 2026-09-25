import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export enum StatusTypeDto {
  TEXT = 'TEXT',
  IMAGE = 'IMAGE',
  VIDEO = 'VIDEO'
}

export class CreateStatusDto {
  @IsEnum(StatusTypeDto)
  @IsOptional()
  type?: StatusTypeDto;

  @IsString()
  @IsNotEmpty()
  content: string;

  @IsString()
  @IsOptional()
  caption?: string;

  @IsString()
  @IsOptional()
  backgroundColor?: string;

  @IsString()
  @IsOptional()
  fontStyle?: string;
}

export class ReactStatusDto {
  @IsString()
  @IsNotEmpty()
  emoji: string;
}

