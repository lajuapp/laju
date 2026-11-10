import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

export type RedisMessageCallback = (message: string) => void;

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis;
  private subscriber: Redis;

  private readonly channelListeners = new Map<string, Set<RedisMessageCallback>>();
  private readonly channelSubscribers = new Map<string, number>();

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const redisUrl = this.configService.get<string>('REDIS_URL') || 'redis://localhost:6379';
    this.client = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 3 });
    this.subscriber = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 3 });

    // Guard against Node.js EventEmitter defaultMaxListeners (10) warnings on ioredis Commander
    this.client.setMaxListeners(0);
    this.subscriber.setMaxListeners(0);

    // Single centralized message dispatcher across the entire subscriber lifecycle
    this.subscriber.on('message', (channel: string, message: string) => {
      const listeners = this.channelListeners.get(channel);
      if (listeners && listeners.size > 0) {
        for (const listener of listeners) {
          try {
            listener(message);
          } catch (err: any) {
            this.logger.error(`Error in Redis listener callback for ${channel}: ${err.message}`, err.stack);
          }
        }
      }
    });

    this.client.connect().catch((err) => {
      this.logger.warn(`Redis client initial connect error: ${err.message}`);
    });
    this.subscriber.connect().catch((err) => {
      this.logger.warn(`Redis subscriber initial connect error: ${err.message}`);
    });
  }

  async onModuleDestroy() {
    this.channelListeners.clear();
    this.channelSubscribers.clear();
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

  /**
   * Subscribe a callback to messages on a specific Redis channel.
   * Returns a cleanup function that automatically unsubscribes this callback.
   */
  async subscribe(channel: string, callback: RedisMessageCallback): Promise<() => void> {
    let listeners = this.channelListeners.get(channel);
    const isFirstListener = !listeners || listeners.size === 0;

    if (!listeners) {
      listeners = new Set();
      this.channelListeners.set(channel, listeners);
    }
    listeners.add(callback);

    if (isFirstListener) {
      try {
        await this.subscriber.subscribe(channel);
      } catch (err: any) {
        this.logger.warn(`Redis subscribe error for ${channel}: ${err.message}`);
      }
    }

    return () => {
      this.unsubscribe(channel, callback).catch(() => {});
    };
  }

  /**
   * Unsubscribe a specific callback from a channel.
   * If no callbacks remain for this channel, it unsubscribes from the Redis server.
   */
  async unsubscribe(channel: string, callback: RedisMessageCallback): Promise<void> {
    const listeners = this.channelListeners.get(channel);
    if (!listeners) return;

    listeners.delete(callback);
    if (listeners.size === 0) {
      this.channelListeners.delete(channel);
      try {
        await this.subscriber.unsubscribe(channel);
      } catch (err: any) {
        this.logger.warn(`Redis unsubscribe error for ${channel}: ${err.message}`);
      }
    }
  }

  async subscribeChannel(channel: string): Promise<void> {
    const current = this.channelSubscribers.get(channel) || 0;
    this.channelSubscribers.set(channel, current + 1);
    if (current === 0) {
      try {
        await this.subscriber.subscribe(channel);
      } catch (err: any) {
        this.logger.warn(`Redis subscribeChannel error for ${channel}: ${err.message}`);
      }
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
