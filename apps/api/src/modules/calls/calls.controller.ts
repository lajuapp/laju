import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  UseGuards,
  Req
} from '@nestjs/common';
import { Request } from 'express';
import { CallsService } from './calls.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('calls')
@UseGuards(JwtAuthGuard)
export class CallsController {
  constructor(private readonly callsService: CallsService) {}

  @Get('incoming')
  getIncomingCall(@CurrentUser('userId') userId: string) {
    return this.callsService.getIncomingCall(userId);
  }

  @Get('history')
  getCallHistory(@CurrentUser('userId') userId: string) {
    return this.callsService.getCallHistory(userId);
  }

  @Delete('history')
  clearCallHistory(@CurrentUser('userId') userId: string) {
    return this.callsService.clearCallHistory(userId);
  }

  @Delete(':id')
  deleteCallFromHistory(
    @CurrentUser('userId') userId: string,
    @Param('id') callId: string
  ) {
    return this.callsService.deleteCallFromHistory(userId, callId);
  }

  @Get(':id')
  getCallById(
    @CurrentUser('userId') userId: string,
    @Param('id') callId: string
  ) {
    return this.callsService.getCallById(userId, callId);
  }

  @Post()
  createCall(
    @CurrentUser('userId') userId: string,
    @CurrentUser('deviceId') deviceId: string,
    @Body('calleeUserId') calleeUserId: string,
    @Body('isVideo') isVideo?: boolean
  ) {
    return this.callsService.createCall(userId, deviceId, calleeUserId, isVideo);
  }

  @Post(':id/accept')
  acceptCall(
    @CurrentUser('userId') userId: string,
    @CurrentUser('deviceId') deviceId: string,
    @Param('id') callId: string
  ) {
    return this.callsService.acceptCall(userId, deviceId, callId);
  }

  @Post(':id/reject')
  rejectCall(
    @CurrentUser('userId') userId: string,
    @Param('id') callId: string
  ) {
    return this.callsService.rejectCall(userId, callId);
  }

  @Post(':id/end')
  endCall(
    @CurrentUser('userId') userId: string,
    @Param('id') callId: string
  ) {
    return this.callsService.endCall(userId, callId);
  }

  @Post(':id/signal')
  signal(
    @CurrentUser('userId') userId: string,
    @CurrentUser('deviceId') deviceId: string,
    @Param('id') callId: string,
    @Body('signal') signalData: any,
    @Req() req: Request
  ) {
    const clientIp = (req.headers['x-forwarded-for'] as string)?.split(',')[0].trim() || req.ip;
    return this.callsService.exchangeSignal(userId, deviceId, callId, signalData, clientIp);
  }

  @Get(':id/signals')
  getSignals(
    @CurrentUser('userId') userId: string,
    @Param('id') callId: string
  ) {
    return this.callsService.getSignals(userId, callId);
  }

  @Post(':id/audio-chunk')
  pushAudioChunk(
    @CurrentUser('userId') userId: string,
    @Param('id') callId: string,
    @Body('chunk') chunk: string
  ) {
    return this.callsService.pushAudioChunk(userId, callId, chunk);
  }

  @Get(':id/audio-chunks')
  getAudioChunks(
    @CurrentUser('userId') userId: string,
    @Param('id') callId: string
  ) {
    return this.callsService.getAudioChunks(userId, callId);
  }

  @Post(':id/video-frame')
  pushVideoFrame(
    @CurrentUser('userId') userId: string,
    @Param('id') callId: string,
    @Body('frame') frame: string
  ) {
    return this.callsService.pushVideoFrame(userId, callId, frame);
  }

  @Get(':id/video-frame')
  getVideoFrame(
    @CurrentUser('userId') userId: string,
    @Param('id') callId: string
  ) {
    return this.callsService.getVideoFrame(userId, callId);
  }

  @Post(':id/media-stream')
  syncMediaStream(
    @CurrentUser('userId') userId: string,
    @Param('id') callId: string,
    @Body() body: { audioChunk?: string; videoFrame?: string }
  ) {
    return this.callsService.syncMediaStream(userId, callId, body || {});
  }
}
