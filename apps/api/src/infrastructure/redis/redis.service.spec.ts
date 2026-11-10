import { ConfigService } from '@nestjs/config';
import { RedisService } from './redis.service';

const mockClient = {
  connect: jest.fn().mockResolvedValue(undefined),
  quit: jest.fn().mockResolvedValue('OK'),
  setMaxListeners: jest.fn(),
  get: jest.fn(),
  set: jest.fn(),
  del: jest.fn(),
  publish: jest.fn(),
  ping: jest.fn(),
};

const messageListeners: Array<(channel: string, message: string) => void> = [];

const mockSubscriber = {
  connect: jest.fn().mockResolvedValue(undefined),
  quit: jest.fn().mockResolvedValue('OK'),
  setMaxListeners: jest.fn(),
  subscribe: jest.fn().mockResolvedValue('OK'),
  unsubscribe: jest.fn().mockResolvedValue('OK'),
  on: jest.fn().mockImplementation((event: string, handler: any) => {
    if (event === 'message') {
      messageListeners.push(handler);
    }
  }),
};

let callCount = 0;
jest.mock('ioredis', () => {
  return {
    __esModule: true,
    default: jest.fn().mockImplementation(() => {
      callCount++;
      return callCount % 2 === 0 ? mockSubscriber : mockClient;
    }),
  };
});

describe('RedisService', () => {
  let service: RedisService;
  let configService: ConfigService;

  beforeEach(() => {
    jest.clearAllMocks();
    messageListeners.length = 0;
    callCount = 0;

    configService = {
      get: jest.fn().mockReturnValue('redis://localhost:6379'),
    } as any;

    service = new RedisService(configService);
    service.onModuleInit();
  });

  afterEach(async () => {
    await service.onModuleDestroy();
  });

  it('sets maxListeners to 0 on client and subscriber to prevent warnings', () => {
    expect(mockClient.setMaxListeners).toHaveBeenCalledWith(0);
    expect(mockSubscriber.setMaxListeners).toHaveBeenCalledWith(0);
  });

  it('attaches exactly 1 message listener to subscriber', () => {
    expect(mockSubscriber.on).toHaveBeenCalledWith('message', expect.any(Function));
    expect(messageListeners.length).toBe(1);
  });

  it('dispatches messages to the matching channel subscriber', async () => {
    const callback1 = jest.fn();
    const callback2 = jest.fn();

    await service.subscribe('user:user1', callback1);
    await service.subscribe('user:user2', callback2);

    expect(mockSubscriber.subscribe).toHaveBeenCalledWith('user:user1');
    expect(mockSubscriber.subscribe).toHaveBeenCalledWith('user:user2');

    // Simulate incoming Redis message on user:user1
    const dispatcher = messageListeners[0];
    dispatcher('user:user1', JSON.stringify({ type: 'NEW_MESSAGE' }));

    expect(callback1).toHaveBeenCalledWith(JSON.stringify({ type: 'NEW_MESSAGE' }));
    expect(callback2).not.toHaveBeenCalled();
  });

  it('multiplexes multiple callbacks on the same channel', async () => {
    const cbA = jest.fn();
    const cbB = jest.fn();

    const unsubA = await service.subscribe('announcements:global', cbA);
    const unsubB = await service.subscribe('announcements:global', cbB);

    // Only 1 Redis subscribe call for the channel
    expect(mockSubscriber.subscribe).toHaveBeenCalledTimes(1);
    expect(mockSubscriber.subscribe).toHaveBeenCalledWith('announcements:global');

    // Dispatch message
    messageListeners[0]('announcements:global', 'Hello all');
    expect(cbA).toHaveBeenCalledWith('Hello all');
    expect(cbB).toHaveBeenCalledWith('Hello all');

    // Unsubscribe A
    unsubA();
    expect(mockSubscriber.unsubscribe).not.toHaveBeenCalled();

    // Dispatch again
    messageListeners[0]('announcements:global', 'Hello again');
    expect(cbA).toHaveBeenCalledTimes(1);
    expect(cbB).toHaveBeenCalledWith('Hello again');

    // Unsubscribe B (last subscriber)
    unsubB();
    expect(mockSubscriber.unsubscribe).toHaveBeenCalledWith('announcements:global');
  });
});
