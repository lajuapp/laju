import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface GotifyMessage {
  title?: string;
  message: string;
  priority?: number;
}

export interface PushNotificationPayload {
  targetToken?: string;
  title: string;
  message: string;
  conversationId?: string;
  priority?: number;
}

@Injectable()
export class GotifyService {
  private readonly logger = new Logger(GotifyService.name);
  private readonly gotifyUrl: string;
  private readonly token: string;
  private readonly fcmServerKey: string;

  constructor(private readonly configService: ConfigService) {
    this.gotifyUrl = this.configService.get<string>('GOTIFY_URL') || 'http://localhost:80';
    this.token = this.configService.get<string>('GOTIFY_CLIENT_TOKEN') || '';
    this.fcmServerKey = this.configService.get<string>('FCM_SERVER_KEY') || '';
  }

  /**
   * Send a high-priority push notification (Heads-up notification for killed app state)
   */
  async sendPushNotification(params: PushNotificationPayload): Promise<boolean> {
    const { targetToken, title, message, conversationId, priority = 6 } = params;
    let delivered = false;

    // 1. Try sending via Gotify if token or default token available
    const activeGotifyToken = targetToken && !targetToken.startsWith('fcm_') ? targetToken : this.token;
    if (activeGotifyToken) {
      try {
        const payload: any = {
          title,
          message,
          priority: Math.max(priority, 6), // Priority >= 6 triggers popup/heads-up notification on Android
          extras: {
            'client::notification': {
              click: {
                url: conversationId ? `laju://conversation/${conversationId}` : 'laju://home'
              }
            }
          }
        };

        const res = await fetch(`${this.gotifyUrl}/message?token=${activeGotifyToken}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });

        if (res.ok) {
          delivered = true;
          this.logger.debug(`Gotify push sent successfully for conversation: ${conversationId}`);
        } else {
          this.logger.warn(`Gotify push request responded with status: ${res.status}`);
        }
      } catch (err: any) {
        this.logger.warn(`Failed to dispatch Gotify push notification: ${err.message}`);
      }
    }

    // 2. If target is FCM token and FCM server key is configured
    if (targetToken && (targetToken.startsWith('fcm_') || this.fcmServerKey)) {
      try {
        if (this.fcmServerKey) {
          const fcmPayload = {
            to: targetToken,
            priority: 'high',
            notification: {
              title,
              body: message,
              sound: 'default'
            },
            data: {
              conversationId,
              click_action: 'FLUTTER_NOTIFICATION_CLICK'
            }
          };

          const fcmRes = await fetch('https://fcm.googleapis.com/fcm/send', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `key=${this.fcmServerKey}`
            },
            body: JSON.stringify(fcmPayload)
          });

          if (fcmRes.ok) {
            delivered = true;
            this.logger.debug(`FCM push sent successfully to token ${targetToken.substring(0, 10)}...`);
          }
        }
      } catch (err: any) {
        this.logger.warn(`Failed to dispatch FCM push notification: ${err.message}`);
      }
    }

    return delivered;
  }

  async sendWakeup(conversationId: string, customToken?: string): Promise<boolean> {
    const token = customToken || this.token;
    if (!token) {
      this.logger.debug('Gotify token not configured, skipping wakeup notification');
      return false;
    }

    try {
      const payload = {
        title: 'Wakeup',
        message: JSON.stringify({
          type: 'message_available',
          conversation: conversationId
        }),
        priority: 6
      };

      const res = await fetch(`${this.gotifyUrl}/message?token=${token}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      if (!res.ok) {
        this.logger.warn(`Gotify wakeup request failed with status: ${res.status}`);
        return false;
      }
      return true;
    } catch (err: any) {
      this.logger.warn(`Failed to send Gotify wakeup: ${err.message}`);
      return false;
    }
  }
}
