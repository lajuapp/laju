import { Module } from '@nestjs/common';
import { MigrationService } from './migration.service';
import { MigrationController } from './migration.controller';
import { AuthenticationModule } from '../authentication/authentication.module';

@Module({
  imports: [AuthenticationModule],
  controllers: [MigrationController],
  providers: [MigrationService],
  exports: [MigrationService]
})
export class MigrationModule {}
