import { Injectable, Logger, MessageEvent } from '@nestjs/common';
import { Subject, Observable, interval, merge } from 'rxjs';
import { filter, map } from 'rxjs/operators';

export interface RealtimeNotificationEvent {
  userId: string;
  type: 'notification' | 'unread_count' | 'read' | 'ping';
  data: any;
  timestamp: string;
}

@Injectable()
export class NotificationRealtimeService {
  private readonly logger = new Logger(NotificationRealtimeService.name);
  private readonly eventBus = new Subject<RealtimeNotificationEvent>();

  /**
   * Broadcasts a real-time event to an authenticated user's active SSE connections.
   */
  emitToUser(
    userId: string,
    type: 'notification' | 'unread_count' | 'read',
    data: any,
  ) {
    this.logger.debug(`[REALTIME_SSE] Emitting ${type} to user ${userId}`);
    this.eventBus.next({
      userId,
      type,
      data,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Returns an Observable SSE event stream for a specific authenticated user.
   * Merges user-targeted operational events with a 30s keep-alive ping to prevent proxy timeouts.
   */
  getUserStream(userId: string): Observable<MessageEvent> {
    const userEvents$ = this.eventBus.pipe(
      filter((evt) => evt.userId === userId),
      map(
        (evt) =>
          ({
            type: evt.type,
            data: {
              type: evt.type,
              payload: evt.data,
              timestamp: evt.timestamp,
            },
          }) as MessageEvent,
      ),
    );

    // 30-second heartbeat ping to prevent connection drops across Render / Nginx / ALB
    const keepAlive$ = interval(30000).pipe(
      map(
        () =>
          ({
            type: 'ping',
            data: { type: 'ping', timestamp: new Date().toISOString() },
          }) as MessageEvent,
      ),
    );

    return merge(userEvents$, keepAlive$);
  }
}
