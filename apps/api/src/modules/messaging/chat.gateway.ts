import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit
} from '@nestjs/websockets';
import { Server, WebSocket } from 'ws';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { MessagingService } from './messaging.service';
import { ConversationsService } from '../conversations/conversations.service';

interface ChatClient {
  ws: WebSocket;
  userId: string;
  deviceId: string;
}

@WebSocketGateway({
  path: '/ws/chat',
  cors: { origin: '*' }
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect, OnGatewayInit {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(ChatGateway.name);
  private clients = new Map<string, ChatClient>(); // socketId -> ChatClient
  private userSockets = new Map<string, Set<string>>(); // userId -> Set<socketId>

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly redisService: RedisService,
    private readonly messagingService: MessagingService,
    private readonly conversationsService: ConversationsService
  ) {}

  afterInit() {
    this.logger.log('ChatGateway initialized at /ws/chat');
    try {
      const redisSubscriber = this.redisService.getSubscriber();
      redisSubscriber.on('message', (channel: string, message: string) => {
        if (channel.startsWith('user:')) {
          const userId = channel.substring(5);
          const socketIds = this.userSockets.get(userId);
          if (socketIds && socketIds.size > 0) {
            for (const sid of socketIds) {
              const client = this.clients.get(sid);
              if (client && client.ws.readyState === WebSocket.OPEN) {
                try {
                  client.ws.send(message);
                } catch (_) {}
              }
            }
          }
        }
      });
    } catch (err: any) {
      this.logger.warn(`Redis subscriber init error in ChatGateway: ${err.message}`);
    }
  }

  async handleConnection(ws: WebSocket, req: any) {
    const socketId = this._generateId();
    (ws as any).__socketId = socketId;

    try {
      const url = new URL(req.url || '', 'ws://localhost');
      const token = url.searchParams.get('token') || '';
      if (!token) {
        ws.close(4001, 'Missing token');
        return;
      }

      const secret = this.configService.get<string>('JWT_SECRET');
      const payload = this.jwtService.verify(token, { secret });
      const userId: string = payload.sub;
      const deviceId: string = payload.deviceId || '';

      const client: ChatClient = { ws, userId, deviceId };
      this.clients.set(socketId, client);

      if (!this.userSockets.has(userId)) {
        this.userSockets.set(userId, new Set());
      }
      this.userSockets.get(userId)!.add(socketId);

      // Subscribe to Redis channel for this user
      try {
        await this.redisService.subscribeChannel(`user:${userId}`);
      } catch (_) {}

      // Setup raw message listener
      ws.on('message', async (raw: string | Buffer) => {
        try {
          const data = JSON.parse(raw.toString());
          await this._handleClientMessage(client, data);
        } catch (_) {}
      });

      this.logger.log(`Chat client connected: userId=${userId} socketId=${socketId}`);
      ws.send(JSON.stringify({ type: 'CONNECTED', userId, socketId }));
    } catch (err: any) {
      this.logger.warn(`ChatGateway auth failed: ${err.message}`);
      ws.close(4001, 'Invalid token');
    }
  }

  handleDisconnect(ws: WebSocket) {
    const socketId = (ws as any).__socketId;
    if (!socketId) return;

    const client = this.clients.get(socketId);
    if (client) {
      const userSids = this.userSockets.get(client.userId);
      if (userSids) {
        userSids.delete(socketId);
        if (userSids.size === 0) {
          this.userSockets.delete(client.userId);
          this.redisService.unsubscribeChannel(`user:${client.userId}`).catch(() => {});
        }
      }
      this.clients.delete(socketId);
      this.logger.log(`Chat client disconnected: userId=${client.userId} socketId=${socketId}`);
    }
  }

  private async _handleClientMessage(client: ChatClient, data: any) {
    const event = data.event || data.type;
    if (!event) return;

    switch (event) {
      case 'ping':
        if (client.ws.readyState === WebSocket.OPEN) {
          client.ws.send(JSON.stringify({ type: 'PONG', timestamp: Date.now() }));
        }
        break;

      case 'typing':
        if (data.conversationId) {
          await this.conversationsService.setTyping(
            client.userId,
            data.conversationId,
            !!data.isTyping
          );
        }
        break;

      case 'send_message':
        if (data.conversationId && data.dto) {
          try {
            const result = await this.messagingService.sendMessage(
              client.userId,
              client.deviceId,
              data.conversationId,
              data.dto
            );
            if (client.ws.readyState === WebSocket.OPEN) {
              client.ws.send(JSON.stringify({
                type: 'MESSAGE_ACK',
                clientMsgId: data.clientMsgId,
                message: result
              }));
            }
          } catch (err: any) {
            if (client.ws.readyState === WebSocket.OPEN) {
              client.ws.send(JSON.stringify({
                type: 'MESSAGE_ERROR',
                clientMsgId: data.clientMsgId,
                error: err.message
              }));
            }
          }
        }
        break;

      case 'recall_message':
        if (data.messageId) {
          try {
            await this.messagingService.deleteForEveryone(client.userId, data.messageId);
            if (client.ws.readyState === WebSocket.OPEN) {
              client.ws.send(JSON.stringify({
                type: 'RECALL_ACK',
                messageId: data.messageId,
                success: true
              }));
            }
          } catch (err: any) {
            if (client.ws.readyState === WebSocket.OPEN) {
              client.ws.send(JSON.stringify({
                type: 'RECALL_ERROR',
                messageId: data.messageId,
                error: err.message
              }));
            }
          }
        }
        break;
    }
  }

  private _generateId(): string {
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
  }
}
