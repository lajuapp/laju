import { IsNotEmpty, IsString, IsEnum, IsOptional, IsNumber } from 'class-validator';
import { MessageType } from '@secure-messenger/shared-types';

export class SendMessageDto {
  @IsString()
  @IsNotEmpty()
  clientMessageId: string;

  @IsString()
  @IsNotEmpty()
  ciphertext: string;

  @IsString()
  @IsNotEmpty()
  nonce: string;

  @IsEnum(MessageType)
  @IsOptional()
  messageType?: MessageType;

  @IsNumber()
  @IsOptional()
  expiresInSeconds?: number;
}

export class EditMessageDto {
  @IsString()
  @IsNotEmpty()
  ciphertext: string;
}

export class AddReactionDto {
  @IsString()
  @IsNotEmpty()
  emoji: string;
}

