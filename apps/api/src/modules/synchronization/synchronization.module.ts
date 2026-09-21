import { Module } from '@nestjs/common';
import { SynchronizationService } from './synchronization.service';
import { SynchronizationController } from './synchronization.controller';
import { AuthenticationModule } from '../authentication/authentication.module';

@Module({
  imports: [AuthenticationModule],
  controllers: [SynchronizationController],
  providers: [SynchronizationService],
  exports: [SynchronizationService]
})
export class SynchronizationModule {}
