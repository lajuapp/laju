import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { DevicesService } from './devices.service';
import {
  RegisterDeviceDto,
  DeviceChallengeRequestDto,
  DeviceVerifyChallengeDto,
  UpdatePushTokenDto
} from './dto/devices.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('devices')
export class DevicesController {
  constructor(private readonly devicesService: DevicesService) {}

  /**
   * Request cryptographic authentication challenge nonce (Public)
   */
  @Post('challenge')
  challenge(@Body() dto?: DeviceChallengeRequestDto) {
    return this.devicesService.createChallenge(dto);
  }

  /**
   * Submit signed challenge to authenticate device and receive JWT session (Public)
   */
  @Post('verify')
  verify(@Body() dto: DeviceVerifyChallengeDto) {
    return this.devicesService.verifyChallenge(dto);
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  register(
    @CurrentUser('userId') userId: string,
    @Body() dto: RegisterDeviceDto
  ) {
    return this.devicesService.registerDevice(userId, dto);
  }

  @Post('push-token')
  @UseGuards(JwtAuthGuard)
  updatePushToken(
    @CurrentUser('userId') userId: string,
    @Body() dto: UpdatePushTokenDto
  ) {
    return this.devicesService.updatePushToken(userId, dto);
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  list(@CurrentUser('userId') userId: string) {
    return this.devicesService.listDevices(userId);
  }

  @Post(':id/revoke')
  @UseGuards(JwtAuthGuard)
  revoke(
    @CurrentUser('userId') userId: string,
    @Param('id') deviceId: string
  ) {
    return this.devicesService.revokeDevice(userId, deviceId);
  }
}

