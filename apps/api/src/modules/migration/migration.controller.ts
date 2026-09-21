import { Controller, Post, Get, Body, Param, UseGuards } from '@nestjs/common';
import { MigrationService } from './migration.service';
import {
  StartMigrationDto,
  JoinMigrationDto,
  VerifySasDto,
  CommitMigrationDto
} from './dto/migration.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('migration')
export class MigrationController {
  constructor(private readonly migrationService: MigrationService) {}

  /**
   * Phase 1: Source device requests migration initiation (Dynamic QR payload).
   */
  @Post('start')
  @UseGuards(JwtAuthGuard)
  start(
    @CurrentUser('userId') userId: string,
    @CurrentUser('deviceId') deviceId: string,
    @Body() dto: StartMigrationDto
  ) {
    return this.migrationService.startMigration(userId, deviceId, dto);
  }

  /**
   * Phase 2: Target device joins migration via scanned QR material.
   */
  @Post(':id/join')
  join(
    @Param('id') migrationId: string,
    @Body() dto: JoinMigrationDto
  ) {
    return this.migrationService.joinMigration(migrationId, dto);
  }

  /**
   * Phase 3: Out-of-band SAS code confirmation.
   */
  @Post(':id/verify')
  verify(
    @Param('id') migrationId: string,
    @Body() dto: VerifySasDto
  ) {
    return this.migrationService.verifyMigration(migrationId, dto);
  }

  /**
   * Phase 4: Atomic Two-Phase Commit (2PC) Device Swap.
   */
  @Post(':id/commit')
  commit(
    @Param('id') migrationId: string,
    @Body() dto?: CommitMigrationDto
  ) {
    return this.migrationService.commitMigration(migrationId, dto);
  }

  /**
   * Cancel pending migration.
   */
  @Post(':id/cancel')
  @UseGuards(JwtAuthGuard)
  cancel(
    @Param('id') migrationId: string,
    @CurrentUser('userId') userId: string
  ) {
    return this.migrationService.cancelMigration(migrationId, userId);
  }

  /**
   * Poll migration status.
   */
  @Get(':id/status')
  status(@Param('id') migrationId: string) {
    return this.migrationService.getMigrationStatus(migrationId);
  }
}
