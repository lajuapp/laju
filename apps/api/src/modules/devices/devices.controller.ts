import { Controller, Get, Post, Body, Param, UseGuards, Req, Res } from '@nestjs/common';
import { Request, Response } from 'express';
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

  @Post('test-push')
  @UseGuards(JwtAuthGuard)
  testPush(@CurrentUser('userId') userId: string) {
    return this.devicesService.testPushNotification(userId);
  }

  @Get('gotify-config')
  @UseGuards(JwtAuthGuard)
  gotifyConfig() {
    return this.devicesService.getGotifyConfig();
  }

  @Get('push-stream')
  @UseGuards(JwtAuthGuard)
  async pushStream(
    @CurrentUser('userId') userId: string,
    @Req() req: Request,
    @Res() res: Response
  ) {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders?.();

    res.write(`data: ${JSON.stringify({ type: 'CONNECTED', userId, timestamp: Date.now() })}\n\n`);

    const channel = `user:${userId}`;
    const globalChannel = 'announcements:global';
    const redisService = this.devicesService.getRedisService();
    const subscriber = this.devicesService.getRedisSubscriber();

    const onMessage = (chan: string, msg: string) => {
      if (chan === channel || chan === globalChannel) {
        res.write(`data: ${msg}\n\n`);
      }
    };

    if (subscriber && redisService) {
      await redisService.subscribeChannel(channel);
      await redisService.subscribeChannel(globalChannel);
      subscriber.on('message', onMessage);
    }

    // Replay any active ringing call, missed calls, or unread messages missed while offline/in Doze
    const sinceParam = req.query?.since ? Number(req.query.since) : undefined;
    this.devicesService
      .getPendingPushEvents(userId, sinceParam)
      .then((pendingEvents) => {
        if (!res.writableEnded && Array.isArray(pendingEvents)) {
          for (const ev of pendingEvents) {
            res.write(`data: ${JSON.stringify(ev)}\n\n`);
          }
        }
      })
      .catch(() => {});

    const heartbeat = setInterval(() => {
      if (!res.writableEnded) {
        res.write(`: heartbeat ${Date.now()}\n\n`);
      }
    }, 25000);

    req.on('close', () => {
      clearInterval(heartbeat);
      if (subscriber && redisService) {
        subscriber.removeListener('message', onMessage);
        redisService.unsubscribeChannel(channel).catch(() => {});
        redisService.unsubscribeChannel(globalChannel).catch(() => {});
      }
      res.end();
    });
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

