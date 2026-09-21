import { Module } from '@nestjs/common';
import { StatusController } from './status.controller';
import { StatusService } from './status.service';
import { PrismaModule } from '../../infrastructure/prisma/prisma.module';
import { AuthenticationModule } from '../authentication/authentication.module';

@Module({
  imports: [PrismaModule, AuthenticationModule],
  controllers: [StatusController],
  providers: [StatusService],
  exports: [StatusService]
})
export class StatusModule {}
