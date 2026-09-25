import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  UseGuards
} from '@nestjs/common';
import { StatusService } from './status.service';
import { CreateStatusDto, ReactStatusDto } from './dto/status.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('status')
@UseGuards(JwtAuthGuard)
export class StatusController {
  constructor(private readonly statusService: StatusService) {}

  @Post()
  createStatus(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateStatusDto
  ) {
    return this.statusService.createStatus(userId, dto);
  }

  @Get('me')
  getMyStatuses(@CurrentUser('userId') userId: string) {
    return this.statusService.getMyStatuses(userId);
  }

  @Get('contacts')
  getContactsStatuses(@CurrentUser('userId') userId: string) {
    return this.statusService.getContactsStatuses(userId);
  }

  @Get(':id/views')
  getStatusViewers(
    @CurrentUser('userId') userId: string,
    @Param('id') storyId: string
  ) {
    return this.statusService.getStatusViewers(userId, storyId);
  }

  @Post(':id/view')
  markStatusViewed(
    @CurrentUser('userId') userId: string,
    @Param('id') storyId: string
  ) {
    return this.statusService.markStatusViewed(userId, storyId);
  }

  @Post(':id/react')
  reactToStatus(
    @CurrentUser('userId') userId: string,
    @Param('id') storyId: string,
    @Body() dto: ReactStatusDto
  ) {
    return this.statusService.reactToStatus(userId, storyId, dto.emoji);
  }

  @Delete(':id')
  deleteStatus(
    @CurrentUser('userId') userId: string,
    @Param('id') storyId: string
  ) {
    return this.statusService.deleteStatus(userId, storyId);
  }
}
