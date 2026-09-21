import { IsNotEmpty, IsString, IsArray, IsEnum, IsOptional } from 'class-validator';
import { ConversationType, ConversationRole } from '@secure-messenger/shared-types';

export class CreateConversationDto {
  @IsEnum(ConversationType)
  type: ConversationType;

  @IsString()
  @IsOptional()
  title?: string;

  @IsArray()
  @IsString({ each: true })
  @IsNotEmpty({ each: true })
  participantUserIds: string[];
}

export class AddMemberDto {
  @IsString()
  @IsNotEmpty()
  userId: string;

  @IsEnum(ConversationRole)
  @IsOptional()
  role?: ConversationRole;
}

export class ChangeMemberRoleDto {
  @IsEnum(ConversationRole)
  role: ConversationRole;
}

export class UpdateConversationDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsOptional()
  permissions?: {
    canEditGroupInfo?: boolean;
    canSendMessages?: boolean;
    canAddMembers?: boolean;
    requireApprovalToJoin?: boolean;
  };
}

