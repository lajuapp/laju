import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis;
  private subscriber: Redis;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const redisUrl = this.configService.get<string>('REDIS_URL') || 'redis://localhost:6379';
    this.client = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 3 });
    this.subscriber = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 3 });

    this.client.connect().catch((err) => {
      this.logger.warn(`Redis client initial connect error: ${err.message}`);
    });
    this.subscriber.connect().catch((err) => {
      this.logger.warn(`Redis subscriber initial connect error: ${err.message}`);
    });
  }

  async onModuleDestroy() {
    await this.client?.quit();
    await this.subscriber?.quit();
  }

  getClient(): Redis {
    return this.client;
  }

  getSubscriber(): Redis {
    return this.subscriber;
  }

  async get(key: string): Promise<string | null> {
    return this.client.get(key);
  }

  async set(key: string, value: string, mode?: string, duration?: number): Promise<'OK' | null> {
    if (mode && duration) {
      return (this.client as any).set(key, value, mode, duration);
    }
    return this.client.set(key, value);
  }

  async del(key: string): Promise<number> {
    return this.client.del(key);
  }

  async publish(channel: string, message: string): Promise<number> {
    return this.client.publish(channel, message);
  }

  private readonly channelSubscribers = new Map<string, number>();

  async subscribeChannel(channel: string): Promise<void> {
    const current = this.channelSubscribers.get(channel) || 0;
    this.channelSubscribers.set(channel, current + 1);
    try {
      await this.subscriber.subscribe(channel);
    } catch (err: any) {
      this.logger.warn(`Redis subscribeChannel error for ${channel}: ${err.message}`);
    }
  }

  async unsubscribeChannel(channel: string): Promise<void> {
    const current = this.channelSubscribers.get(channel) || 0;
    if (current <= 1) {
      this.channelSubscribers.delete(channel);
      try {
        await this.subscriber.unsubscribe(channel);
      } catch (err: any) {
        this.logger.warn(`Redis unsubscribeChannel error for ${channel}: ${err.message}`);
      }
    } else {
      this.channelSubscribers.set(channel, current - 1);
    }
  }

  async ping(): Promise<string> {
    return this.client.ping();
  }
}
