import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface GotifyMessage {
  title?: string;
  message: string;
  priority?: number;
}

@Injectable()
export class GotifyService {
  private readonly logger = new Logger(GotifyService.name);
  private readonly gotifyUrl: string;
  private readonly token: string;

  constructor(private readonly configService: ConfigService) {
    this.gotifyUrl = this.configService.get<string>('GOTIFY_URL') || 'http://localhost:80';
    this.token = this.configService.get<string>('GOTIFY_CLIENT_TOKEN') || '';
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
        priority: 5
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
