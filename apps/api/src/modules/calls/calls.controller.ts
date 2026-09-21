import {
  Controller,
  Post,
  Body,
  Param,
  UseGuards
} from '@nestjs/common';
import { CallsService } from './calls.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('calls')
@UseGuards(JwtAuthGuard)
export class CallsController {
  constructor(private readonly callsService: CallsService) {}

  @Post()
  createCall(
    @CurrentUser('userId') userId: string,
    @CurrentUser('deviceId') deviceId: string,
    @Body('calleeUserId') calleeUserId: string
  ) {
    return this.callsService.createCall(userId, deviceId, calleeUserId);
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
    @Body('signal') signalData: any
  ) {
    return this.callsService.exchangeSignal(userId, deviceId, callId, signalData);
  }
}
