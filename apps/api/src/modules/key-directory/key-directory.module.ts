import { Module } from '@nestjs/common';
import { KeyDirectoryService } from './key-directory.service';
import { KeyDirectoryController } from './key-directory.controller';
import { AuthenticationModule } from '../authentication/authentication.module';

@Module({
  imports: [AuthenticationModule],
  controllers: [KeyDirectoryController],
  providers: [KeyDirectoryService],
  exports: [KeyDirectoryService]
})
export class KeyDirectoryModule {}
