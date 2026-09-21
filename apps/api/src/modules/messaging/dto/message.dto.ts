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
