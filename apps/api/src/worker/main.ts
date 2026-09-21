import { Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';

const logger = new Logger('OutboxWorker');
const prisma = new PrismaClient();
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
const redis = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 3 });
const gotifyUrl = process.env.GOTIFY_URL || 'http://localhost:80';
const gotifyToken = process.env.GOTIFY_CLIENT_TOKEN || '';

let isRunning = true;

async function sendGotifyWakeup(conversationId: string) {
  if (!gotifyToken) return;
  try {
    const payload = {
      title: 'Wakeup',
      message: JSON.stringify({
        type: 'message_available',
        conversation: conversationId
      }),
      priority: 5
    };
    await fetch(`${gotifyUrl}/message?token=${gotifyToken}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
  } catch (err: any) {
    logger.warn(`Failed to send Gotify wakeup: ${err.message}`);
  }
}

async function processOutboxBatch() {
  try {
    // Fetch pending events with limit
    const pendingEvents = await prisma.outboxEvent.findMany({
      where: { status: 'PENDING' },
      orderBy: { createdAt: 'asc' },
      take: 20
    });

    if (pendingEvents.length === 0) {
      return 0;
    }

    for (const event of pendingEvents) {
      try {
        // 1. Publish to Redis realtime channel
        const channel = `conversation:${event.aggregateId}`;
        await redis.publish(channel, JSON.stringify({
          eventType: event.eventType,
          payload: JSON.parse(event.payload),
          timestamp: Date.now()
        }));

        // 2. Trigger Gotify generic wakeup
        await sendGotifyWakeup(event.aggregateId);

        // 3. Mark processed
        await prisma.outboxEvent.update({
          where: { id: event.id },
          data: {
            status: 'PROCESSED',
            processedAt: new Date()
          }
        });

        logger.debug(`Processed outbox event ${event.id} for ${event.aggregateType}:${event.aggregateId}`);
      } catch (err: any) {
        logger.error(`Error processing event ${event.id}: ${err.message}`);
        await prisma.outboxEvent.update({
          where: { id: event.id },
          data: {
            retryCount: { increment: 1 },
            lastError: err.message,
            status: event.retryCount >= 5 ? 'FAILED' : 'PENDING'
          }
        });
      }
    }

    return pendingEvents.length;
  } catch (err: any) {
    logger.error(`Error in outbox polling batch: ${err.message}`);
    await new Promise((resolve) => setTimeout(resolve, 3000));
    return 0;
  }
}

async function startWorker() {
  logger.log('Starting Transactional Outbox Worker...');

  try {
    await prisma.$connect();
    await redis.connect();
    logger.log('Prisma and Redis connected successfully');
  } catch (err: any) {
    logger.error(`Worker initial connection failed: ${err.message}`);
  }

  while (isRunning) {
    const processedCount = await processOutboxBatch();
    // If no records processed, sleep for a short interval (500ms)
    const delay = processedCount > 0 ? 50 : 500;
    await new Promise((resolve) => setTimeout(resolve, delay));
  }

  logger.log('Worker loop stopped. Cleaning up connections...');
  await prisma.$disconnect();
  await redis.quit();
  process.exit(0);
}

process.on('SIGINT', () => {
  logger.log('Received SIGINT. Shutting down worker gracefully...');
  isRunning = false;
});

process.on('SIGTERM', () => {
  logger.log('Received SIGTERM. Shutting down worker gracefully...');
  isRunning = false;
});

startWorker().catch((err) => {
  logger.error(`Fatal error in outbox worker: ${err.message}`);
  process.exit(1);
});
