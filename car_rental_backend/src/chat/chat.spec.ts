import { Test, TestingModule } from '@nestjs/testing';
import { ChatService } from './chat.service';
import { ChatController } from './chat.controller';
import { PrismaService } from '../prisma/prisma.service';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';

describe('ChatService and ChatController', () => {
  let service: ChatService;
  let controller: ChatController;
  let prisma: any;

  const mockConversation = {
    id: 'conv-1',
    customerId: 'cust-1',
    vendorId: 'vend-1',
    bookingId: 'book-1',
    status: 'ACTIVE',
    lastMessageAt: new Date(),
    vendor: { id: 'vend-1', userId: 'vend-user-1', businessName: 'Speedy Wheels' },
    customer: { id: 'cust-1', name: 'John Customer', phone: '+919876543210' },
    booking: { id: 'book-1', bookingNumber: 'BK-1001', status: 'CONFIRMED' },
    messages: [],
  };

  const mockMessage = {
    id: 'msg-1',
    conversationId: 'conv-1',
    senderId: 'cust-1',
    senderRole: 'CUSTOMER',
    content: 'Hi, where is the pickup point?',
    attachmentUrl: null,
    isRead: false,
    readAt: null,
    metadata: null,
    createdAt: new Date(),
  };

  beforeEach(async () => {
    prisma = {
      chatConversation: {
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      chatMessage: {
        findMany: jest.fn(),
        create: jest.fn(),
        updateMany: jest.fn(),
      },
      vendor: {
        findFirst: jest.fn(),
      },
      $transaction: jest.fn().mockImplementation((promises) => Promise.all(promises)),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ChatController],
      providers: [
        ChatService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<ChatService>(ChatService);
    controller = module.get<ChatController>(ChatController);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
    expect(controller).toBeDefined();
  });

  describe('getOrCreateConversation', () => {
    it('returns existing conversation if found by bookingId', async () => {
      prisma.chatConversation.findFirst.mockResolvedValue(mockConversation);

      const res = await service.getOrCreateConversation('cust-1', 'vend-1', 'book-1');
      expect(res).toEqual(mockConversation);
      expect(prisma.chatConversation.findFirst).toHaveBeenCalledWith({
        where: { bookingId: 'book-1', customerId: 'cust-1' },
        include: expect.any(Object),
      });
      expect(prisma.chatConversation.create).not.toHaveBeenCalled();
    });

    it('creates new conversation if none exists', async () => {
      prisma.chatConversation.findFirst.mockResolvedValue(null);
      prisma.chatConversation.create.mockResolvedValue(mockConversation);

      const res = await service.getOrCreateConversation('cust-1', 'vend-1', 'book-1');
      expect(res).toEqual(mockConversation);
      expect(prisma.chatConversation.create).toHaveBeenCalledWith({
        data: {
          customerId: 'cust-1',
          vendorId: 'vend-1',
          bookingId: 'book-1',
          status: 'ACTIVE',
        },
        include: expect.objectContaining({
          customer: { select: { id: true, name: true, profilePhotoUrl: true } },
        }),
      });
    });

    it('never includes customer phone in customer select projection', async () => {
      prisma.chatConversation.findFirst.mockResolvedValue(null);
      prisma.chatConversation.create.mockResolvedValue(mockConversation);

      await service.getOrCreateConversation('cust-1', 'vend-1');
      const createCall = prisma.chatConversation.create.mock.calls[0][0];
      expect(createCall.include.customer.select).toEqual({
        id: true,
        name: true,
        profilePhotoUrl: true,
      });
      expect(createCall.include.customer.select.phone).toBeUndefined();
    });

    it('throws BadRequestException if customerId is missing', async () => {
      await expect(service.getOrCreateConversation('', 'vend-1')).rejects.toThrow(BadRequestException);
    });
  });

  describe('sendMessage', () => {
    it('successfully creates message and updates conversation lastMessageAt', async () => {
      prisma.chatConversation.findUnique.mockResolvedValue(mockConversation);
      prisma.chatMessage.create.mockResolvedValue(mockMessage);
      prisma.chatConversation.update.mockResolvedValue({ ...mockConversation, lastMessageAt: new Date() });

      const res = await service.sendMessage('conv-1', 'cust-1', 'CUSTOMER', 'Where is the key?');
      expect(res).toEqual(mockMessage);
      expect(prisma.chatMessage.create).toHaveBeenCalledWith({
        data: {
          conversationId: 'conv-1',
          senderId: 'cust-1',
          senderRole: 'CUSTOMER',
          content: 'Where is the key?',
          attachmentUrl: null,
        },
      });
      expect(prisma.chatConversation.update).toHaveBeenCalledWith({
        where: { id: 'conv-1' },
        data: { lastMessageAt: expect.any(Date) },
      });
    });

    it('rejects message if content is empty or whitespace', async () => {
      await expect(service.sendMessage('conv-1', 'cust-1', 'CUSTOMER', '   ')).rejects.toThrow(BadRequestException);
    });

    it('rejects message if conversation not found', async () => {
      prisma.chatConversation.findUnique.mockResolvedValue(null);
      await expect(service.sendMessage('conv-none', 'cust-1', 'CUSTOMER', 'Hello')).rejects.toThrow(NotFoundException);
    });

    it('rejects message if sender is neither customer, vendor, nor admin', async () => {
      prisma.chatConversation.findUnique.mockResolvedValue(mockConversation);
      await expect(
        service.sendMessage('conv-1', 'intruder-user', 'CUSTOMER', 'Unauthorized message'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('getConversationMessages', () => {
    it('returns messages for authorized customer', async () => {
      prisma.chatConversation.findUnique.mockResolvedValue(mockConversation);
      prisma.chatMessage.findMany.mockResolvedValue([mockMessage]);

      const res = await service.getConversationMessages('conv-1', 'cust-1', 'CUSTOMER');
      expect(res).toEqual([mockMessage]);
      expect(prisma.chatMessage.findMany).toHaveBeenCalledWith({
        where: { conversationId: 'conv-1' },
        orderBy: { createdAt: 'asc' },
      });
    });

    it('throws ForbiddenException for unauthorized user', async () => {
      prisma.chatConversation.findUnique.mockResolvedValue(mockConversation);
      await expect(
        service.getConversationMessages('conv-1', 'random-user', 'CUSTOMER'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('markMessagesAsRead', () => {
    it('marks unread messages sent by others as read', async () => {
      prisma.chatMessage.updateMany.mockResolvedValue({ count: 3 });
      const res = await service.markMessagesAsRead('conv-1', 'cust-1');
      expect(res).toEqual({ count: 3 });
      expect(prisma.chatMessage.updateMany).toHaveBeenCalledWith({
        where: {
          conversationId: 'conv-1',
          senderId: { not: 'cust-1' },
          isRead: false,
        },
        data: {
          isRead: true,
          readAt: expect.any(Date),
        },
      });
    });
  });

  describe('ChatController', () => {
    it('POST /chat/conversations delegates to service with user ID', async () => {
      prisma.chatConversation.findFirst.mockResolvedValue(mockConversation);
      const req = { user: { userId: 'cust-1', role: 'CUSTOMER' } };
      const res = await controller.getOrCreateConversation(req, { vendorId: 'vend-1' });
      expect(res).toEqual(mockConversation);
    });

    it('POST /chat/conversations/:id/messages sends message using authenticated sender', async () => {
      prisma.chatConversation.findUnique.mockResolvedValue(mockConversation);
      prisma.chatMessage.create.mockResolvedValue(mockMessage);
      prisma.chatConversation.update.mockResolvedValue(mockConversation);

      const req = { user: { userId: 'cust-1', role: 'CUSTOMER' } };
      const res = await controller.sendMessage(req, 'conv-1', { content: 'Is car fueled?' });
      expect(res).toEqual(mockMessage);
    });
  });
});
