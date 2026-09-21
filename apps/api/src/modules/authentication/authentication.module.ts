import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { AuthenticationService } from './authentication.service';
import { AuthenticationController } from './authentication.controller';
import { IdentityController } from './identity.controller';

@Module({
  imports: [
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET') || 'default_secret',
        signOptions: {
          expiresIn: config.get<string>('JWT_EXPIRES_IN') || '7d'
        }
      })
    })
  ],
  controllers: [AuthenticationController, IdentityController],
  providers: [AuthenticationService],
  exports: [AuthenticationService, JwtModule]
})
export class AuthenticationModule {}
