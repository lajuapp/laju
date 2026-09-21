import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { KeyDirectoryService } from './key-directory.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@Controller('keys')
@UseGuards(JwtAuthGuard)
export class KeyDirectoryController {
  constructor(private readonly keyDirectoryService: KeyDirectoryService) {}

  @Get(':userId/bundle')
  getBundle(
    @Param('userId') userId: string,
    @Query('deviceId') deviceId?: string
  ) {
    return this.keyDirectoryService.getPreKeyBundle(userId, deviceId);
  }
}
