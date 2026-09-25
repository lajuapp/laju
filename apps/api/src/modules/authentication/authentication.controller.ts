import { Controller, Post, Body, UseGuards, Get } from '@nestjs/common';
import { AuthenticationService } from './authentication.service';
import {
  RegisterDto,
  LoginDto,
  SendOtpDto,
  VerifyOtpDto,
  Verify2FaDto
} from './dto/auth.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('auth')
export class AuthenticationController {
  constructor(private readonly authService: AuthenticationService) {}

  @Post('send-otp')
  sendOtp(@Body() dto: SendOtpDto) {
    return this.authService.sendOtp(dto);
  }

  @Post('verify-otp')
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto);
  }

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('verify-2fa')
  verify2Fa(@Body() dto: Verify2FaDto) {
    return this.authService.verify2Fa(dto);
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  logout(
    @CurrentUser('userId') userId: string,
    @CurrentUser('deviceId') deviceId: string
  ) {
    return this.authService.logout(userId, deviceId);
  }

  /**
   * Called on every app startup: ensures device record is current and
   * re-issues a fresh JWT token so the app always has a valid session.
   */
  @Post('refresh-device')
  @UseGuards(JwtAuthGuard)
  refreshDevice(
    @CurrentUser('userId') userId: string,
    @Body() body: { deviceUuid: string; deviceName?: string }
  ) {
    return this.authService.refreshDevice(userId, body.deviceUuid, body.deviceName);
  }
}
