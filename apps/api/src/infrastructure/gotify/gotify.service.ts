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
  private token: string;
  private readonly fcmServerKey: string;

  constructor(private readonly configService: ConfigService) {
    this.gotifyUrl = this.configService.get<string>('GOTIFY_URL') || 'http://localhost:80';
    this.token = this.configService.get<string>('GOTIFY_CLIENT_TOKEN') || '';
    this.fcmServerKey = this.configService.get<string>('FCM_SERVER_KEY') || '';
  }

  private async getOrProvisionAppToken(): Promise<string | null> {
    const username = this.configService.get<string>('GOTIFY_DEFAULTUSER_NAME') || 'lajuadmin';
    const password = this.configService.get<string>('GOTIFY_DEFAULTUSER_PASS') || 'laju_gotify_secure_pass_123';
    const authHeader = 'Basic ' + Buffer.from(`${username}:${password}`).toString('base64');

    try {
      const appsRes = await fetch(`${this.gotifyUrl}/application`, {
        headers: { Authorization: authHeader }
      });
      if (appsRes.ok) {
        const apps = await appsRes.json();
        if (Array.isArray(apps) && apps.length > 0) {
          const found = apps.find((a: any) => a.name === 'LajuMessenger') || apps[0];
          if (found && found.token) {
            this.token = found.token;
            return found.token;
          }
        }
      }

      const createRes = await fetch(`${this.gotifyUrl}/application`, {
        method: 'POST',
        headers: {
          Authorization: authHeader,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          name: 'LajuMessenger',
          description: 'Laju Secure Messenger Push Service'
        })
      });

      if (createRes.ok) {
        const newApp = await createRes.json();
        if (newApp && newApp.token) {
          this.token = newApp.token;
          this.logger.log(`Provisioned new Gotify Application Token successfully`);
          return newApp.token;
        }
      }
    } catch (e: any) {
      this.logger.debug(`Could not auto-provision Gotify app token: ${e.message}`);
    }
    return null;
  }

  /**
   * Send a high-priority push notification (Heads-up notification for killed app state)
   */
  async sendPushNotification(params: PushNotificationPayload): Promise<boolean> {
    const { targetToken, title, message, conversationId, priority = 6 } = params;
    let delivered = false;

    // 1. Try sending via Gotify (use specific token or fallback to provisioned app token for gotify_device_*)
    let activeGotifyToken =
      targetToken && !targetToken.startsWith('fcm_') && !targetToken.startsWith('gotify_device_')
        ? targetToken
        : (!targetToken || targetToken.startsWith('gotify_device_') ? (this.token || (await this.getOrProvisionAppToken())) : null);
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

        let res = await fetch(`${this.gotifyUrl}/message?token=${activeGotifyToken}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });

        if (res.ok) {
          delivered = true;
          this.logger.debug(`Gotify push sent successfully for conversation: ${conversationId}`);
        } else {
          this.logger.debug(`Gotify push request responded with status: ${res.status}`);
        }
      } catch (err: any) {
        this.logger.debug(`Failed to dispatch Gotify push notification: ${err.message}`);
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
