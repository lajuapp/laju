import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
  WsException
} from '@nestjs/websockets';
import { Server, WebSocket } from 'ws';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { RedisService } from '../../infrastructure/redis/redis.service';

interface CallClient {
  ws: WebSocket;
  userId: string;
  deviceId: string;
  callId?: string;
}

@WebSocketGateway({
  path: '/ws/calls',
  cors: { origin: '*' }
})
export class CallSignalingGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(CallSignalingGateway.name);
  private clients = new Map<string, CallClient>(); // socketId -> CallClient
  private userSockets = new Map<string, Set<string>>(); // userId -> Set<socketId>
  private callRooms = new Map<string, Set<string>>(); // callId -> Set<socketId>

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly redisService: RedisService
  ) {}

  async handleConnection(ws: WebSocket, req: any) {
    const socketId = this._generateId();
    (ws as any).__socketId = socketId;

    try {
      // Extract JWT from query string: /ws/calls?token=xxx
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

      const client: CallClient = { ws, userId, deviceId };
      this.clients.set(socketId, client);

      if (!this.userSockets.has(userId)) {
        this.userSockets.set(userId, new Set());
      }
      this.userSockets.get(userId)!.add(socketId);

      this.logger.log(`Client connected: userId=${userId} socketId=${socketId}`);

      // Subscribe Redis channel for user-level events (incoming calls, etc.)
      const redisSubscriber = this.redisService.getSubscriber();
      const channelKey = `user:${userId}`;
      try {
        await redisSubscriber.subscribe(channelKey);
        (redisSubscriber as any).__callHandler = (channel: string, message: string) => {
          if (channel === channelKey) {
            this._sendToUser(userId, message);
          }
        };
        redisSubscriber.on('message', (channel: string, message: string) => {
          const targets = this._getUserSocketIds(userId);
          for (const sid of targets) {
            const c = this.clients.get(sid);
            if (c && c.ws.readyState === WebSocket.OPEN) {
              try { c.ws.send(message); } catch (_) {}
            }
          }
        });
      } catch (_) {}

      ws.send(JSON.stringify({ type: 'CONNECTED', userId, socketId }));
    } catch (err: any) {
      this.logger.warn(`Auth failed: ${err.message}`);
      ws.close(4001, 'Invalid token');
    }
  }

  handleDisconnect(ws: WebSocket) {
    const socketId = (ws as any).__socketId;
    if (!socketId) return;

    const client = this.clients.get(socketId);
    if (client) {
      // Remove from call room
      if (client.callId) {
        const room = this.callRooms.get(client.callId);
        if (room) {
          room.delete(socketId);
          if (room.size === 0) this.callRooms.delete(client.callId);
        }
      }

      // Remove from user sockets
      const userSids = this.userSockets.get(client.userId);
      if (userSids) {
        userSids.delete(socketId);
        if (userSids.size === 0) this.userSockets.delete(client.userId);
      }

      this.clients.delete(socketId);
      this.logger.log(`Client disconnected: userId=${client.userId} socketId=${socketId}`);
    }
  }

  // ── Handled via raw ws.on('message') routing below ──
  // NestJS WS @SubscribeMessage works for platform-ws but we handle manually for flexibility

  @SubscribeMessage('join_call')
  handleJoinCall(@ConnectedSocket() ws: WebSocket, @MessageBody() data: { callId: string }) {
    const socketId = (ws as any).__socketId;
    const client = this.clients.get(socketId);
    if (!client || !data?.callId) return;

    client.callId = data.callId;
    if (!this.callRooms.has(data.callId)) {
      this.callRooms.set(data.callId, new Set());
    }
    this.callRooms.get(data.callId)!.add(socketId);

    this.logger.log(`User ${client.userId} joined call room ${data.callId}`);

    // Notify others in the room
    this._broadcastToCallRoom(data.callId, JSON.stringify({
      type: 'PEER_JOINED',
      callId: data.callId,
      userId: client.userId
    }), socketId);
  }

  @SubscribeMessage('webrtc_offer')
  handleWebRTCOffer(@ConnectedSocket() ws: WebSocket, @MessageBody() data: { callId: string; sdp: any; targetUserId?: string }) {
    const socketId = (ws as any).__socketId;
    const client = this.clients.get(socketId);
    if (!client || !data?.callId || !data?.sdp) return;

    this.logger.log(`WebRTC Offer from ${client.userId} for call ${data.callId}`);

    const payload = JSON.stringify({
      type: 'WEBRTC_OFFER',
      callId: data.callId,
      sdp: data.sdp,
      fromUserId: client.userId,
      fromDeviceId: client.deviceId
    });

    // Always broadcast to the call room so any peer in the call gets the signal reliably
    this._broadcastToCallRoom(data.callId, payload, socketId);

    if (data.targetUserId) {
      this._sendToUser(data.targetUserId, payload);
    }
  }

  @SubscribeMessage('webrtc_answer')
  handleWebRTCAnswer(@ConnectedSocket() ws: WebSocket, @MessageBody() data: { callId: string; sdp: any; targetUserId?: string }) {
    const socketId = (ws as any).__socketId;
    const client = this.clients.get(socketId);
    if (!client || !data?.callId || !data?.sdp) return;

    this.logger.log(`WebRTC Answer from ${client.userId} for call ${data.callId}`);

    const payload = JSON.stringify({
      type: 'WEBRTC_ANSWER',
      callId: data.callId,
      sdp: data.sdp,
      fromUserId: client.userId,
      fromDeviceId: client.deviceId
    });

    // Always broadcast to the call room so any peer in the call gets the signal reliably
    this._broadcastToCallRoom(data.callId, payload, socketId);

    if (data.targetUserId) {
      this._sendToUser(data.targetUserId, payload);
    }
  }

  @SubscribeMessage('ice_candidate')
  handleIceCandidate(@ConnectedSocket() ws: WebSocket, @MessageBody() data: { callId: string; candidate: any; targetUserId?: string }) {
    const socketId = (ws as any).__socketId;
    const client = this.clients.get(socketId);
    if (!client || !data?.callId) return;

    const payload = JSON.stringify({
      type: 'ICE_CANDIDATE',
      callId: data.callId,
      candidate: data.candidate,
      fromUserId: client.userId,
      fromDeviceId: client.deviceId
    });

    // Always broadcast to the call room so any peer in the call gets the signal reliably
    this._broadcastToCallRoom(data.callId, payload, socketId);

    if (data.targetUserId) {
      this._sendToUser(data.targetUserId, payload);
    }
  }

  @SubscribeMessage('call_event')
  handleCallEvent(@ConnectedSocket() ws: WebSocket, @MessageBody() data: { callId: string; event: string; payload?: any }) {
    const socketId = (ws as any).__socketId;
    const client = this.clients.get(socketId);
    if (!client || !data?.callId || !data?.event) return;

    this._broadcastToCallRoom(data.callId, JSON.stringify({
      type: data.event,
      callId: data.callId,
      fromUserId: client.userId,
      payload: data.payload
    }), socketId);
  }

  // ── Public API for broadcasting from service layer ──
  notifyUser(userId: string, message: object) {
    this._sendToUser(userId, JSON.stringify(message));
  }

  notifyCallRoom(callId: string, message: object, excludeSocketId?: string) {
    this._broadcastToCallRoom(callId, JSON.stringify(message), excludeSocketId);
  }

  private _sendToUser(userId: string, message: string) {
    const sids = this.userSockets.get(userId);
    if (!sids) return;
    for (const sid of sids) {
      const c = this.clients.get(sid);
      if (c && c.ws.readyState === WebSocket.OPEN) {
        try { c.ws.send(message); } catch (_) {}
      }
    }
  }

  private _broadcastToCallRoom(callId: string, message: string, excludeSocketId?: string) {
    const room = this.callRooms.get(callId);
    if (!room) return;
    for (const sid of room) {
      if (sid === excludeSocketId) continue;
      const c = this.clients.get(sid);
      if (c && c.ws.readyState === WebSocket.OPEN) {
        try { c.ws.send(message); } catch (_) {}
      }
    }
  }

  private _getUserSocketIds(userId: string): string[] {
    return Array.from(this.userSockets.get(userId) || []);
  }

  private _generateId(): string {
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
  }
}
