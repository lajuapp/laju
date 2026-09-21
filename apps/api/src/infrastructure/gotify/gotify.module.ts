import { Global, Module } from '@nestjs/common';
import { GotifyService } from './gotify.service';

@Global()
@Module({
  providers: [GotifyService],
  exports: [GotifyService]
})
export class GotifyModule {}
