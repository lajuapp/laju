import { Controller, Post, Get, Body, UseGuards, Req } from '@nestjs/common';
import { AuthenticationService } from './authentication.service';
import { RegisterIdentityDto, RestoreIdentityDto } from './dto/auth.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('identity')
export class IdentityController {
  constructor(private readonly authService: AuthenticationService) {}

  @Post('register')
  register(@Body() dto: RegisterIdentityDto, @Req() req: any) {
    if (!dto.registrationIp) {
      dto.registrationIp = req.ip || req.headers?.['x-forwarded-for']?.toString() || '127.0.0.1';
    }
    return this.authService.registerIdentity(dto);
  }

  @Post('restore')
  restore(@Body() dto: RestoreIdentityDto) {
    return this.authService.restoreIdentity(dto);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  getMe(@CurrentUser('userId') userId: string) {
    return this.authService.getIdentityMe(userId);
  }
}
