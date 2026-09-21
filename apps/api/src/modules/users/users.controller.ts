import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  Query,
  UseGuards
} from '@nestjs/common';
import { UsersService } from './users.service';
import { UpdateUserProfileDto, SearchUsersQueryDto } from './dto/users.dto';
import { CreateUserReportDto, ReviewUserReportDto } from './dto/reports.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  getProfile(@CurrentUser('userId') userId: string) {
    return this.usersService.getProfile(userId);
  }

  @Patch('me')
  updateProfile(
    @CurrentUser('userId') userId: string,
    @Body() dto: UpdateUserProfileDto
  ) {
    return this.usersService.updateProfile(userId, dto);
  }

  @Post('report')
  createReport(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateUserReportDto
  ) {
    return this.usersService.createUserReport(userId, dto);
  }

  @Get('reports/all')
  listReports(
    @Query('status') status?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string
  ) {
    return this.usersService.listReports(status, limit, offset);
  }

  @Patch('reports/:id/review')
  reviewReport(
    @CurrentUser('userId') reviewerId: string,
    @Param('id') reportId: string,
    @Body() dto: ReviewUserReportDto
  ) {
    return this.usersService.reviewReport(reportId, reviewerId, dto);
  }

  @Get(':id/trust-score')
  getTrustScore(@Param('id') id: string) {
    return this.usersService.getUserTrustScore(id);
  }

  @Get()
  searchUsers(
    @CurrentUser('userId') userId: string,
    @Query() query: SearchUsersQueryDto
  ) {
    return this.usersService.searchUsers(userId, query.q, query.limit, query.offset);
  }

  @Get(':id')
  getUserById(@Param('id') id: string) {
    return this.usersService.getUserById(id);
  }
}

