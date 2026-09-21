import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './infrastructure/prisma/prisma.module';
import { RedisModule } from './infrastructure/redis/redis.module';
import { GotifyModule } from './infrastructure/gotify/gotify.module';
import { SeaweedFsModule } from './infrastructure/seaweedfs/seaweedfs.module';
import { HealthModule } from './modules/health/health.module';
import { AuthenticationModule } from './modules/authentication/authentication.module';
import { DevicesModule } from './modules/devices/devices.module';
import { KeyDirectoryModule } from './modules/key-directory/key-directory.module';
import { ConversationsModule } from './modules/conversations/conversations.module';
import { MessagingModule } from './modules/messaging/messaging.module';
import { SynchronizationModule } from './modules/synchronization/synchronization.module';
import { AttachmentsModule } from './modules/attachments/attachments.module';
import { CallsModule } from './modules/calls/calls.module';
import { IncidentsModule } from './modules/incidents/incidents.module';
import { AdminModule } from './modules/admin/admin.module';
import { UsersModule } from './modules/users/users.module';
import { MigrationModule } from './modules/migration/migration.module';
import { StatusModule } from './modules/status/status.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env']
    }),
    PrismaModule,
    RedisModule,
    GotifyModule,
    SeaweedFsModule,
    HealthModule,
    AuthenticationModule,
    UsersModule,
    DevicesModule,
    KeyDirectoryModule,
    ConversationsModule,
    MessagingModule,
    SynchronizationModule,
    AttachmentsModule,
    CallsModule,
    IncidentsModule,
    AdminModule,
    MigrationModule,
    StatusModule
  ]
})
export class AppModule {}
