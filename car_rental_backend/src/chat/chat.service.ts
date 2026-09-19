import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService) {}

  async getOrCreateConversation(customerId: string, vendorId?: string, bookingId?: string) {
    if (!customerId) {
      throw new BadRequestException('customerId is required');
    }

    // If bookingId is provided, check if a conversation already exists for it
    if (bookingId) {
      const existing = await this.prisma.chatConversation.findFirst({
        where: { bookingId, customerId },
        include: {
          customer: { select: { id: true, name: true, phone: true } },
          vendor: { select: { id: true, businessName: true } },
          booking: { select: { id: true, status: true } },
        },
      });
      if (existing) return existing;
    }

    // Otherwise check by customer + vendor
    if (vendorId) {
      const existing = await this.prisma.chatConversation.findFirst({
        where: { customerId, vendorId, bookingId: bookingId || null },
        include: {
          customer: { select: { id: true, name: true, phone: true } },
          vendor: { select: { id: true, businessName: true } },
          booking: { select: { id: true, status: true } },
        },
      });
      if (existing) return existing;
    }

    return this.prisma.chatConversation.create({
      data: {
        customerId,
        vendorId: vendorId || null,
        bookingId: bookingId || null,
        status: 'ACTIVE',
      },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        vendor: { select: { id: true, businessName: true } },
        booking: { select: { id: true, status: true } },
      },
    });
  }

  async listUserConversations(userId: string, userRole: string) {
    const where: any = {};
    if (userRole === 'VENDOR') {
      // Find vendor corresponding to userId
      const vendor = await this.prisma.vendor.findFirst({ where: { userId } });
      if (!vendor) return [];
      where.vendorId = vendor.id;
    } else if (userRole === 'ADMIN' || userRole === 'SUPPORT_AGENT') {
      // Admins can see all active conversations
    } else {
      // Default to customer
      where.customerId = userId;
    }

    return this.prisma.chatConversation.findMany({
      where,
      orderBy: { lastMessageAt: 'desc' },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        vendor: { select: { id: true, businessName: true } },
        booking: { select: { id: true, status: true } },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
    });
  }

  async getConversationMessages(conversationId: string, userId: string, userRole: string) {
    const conversation = await this.prisma.chatConversation.findUnique({
      where: { id: conversationId },
      include: { vendor: true },
    });

    if (!conversation) {
      throw new NotFoundException(`Conversation with ID ${conversationId} not found`);
    }

    // Access control check
    if (
      userRole !== 'ADMIN' &&
      userRole !== 'SUPPORT_AGENT' &&
      conversation.customerId !== userId &&
      conversation.vendor?.userId !== userId
    ) {
      throw new ForbiddenException('Not authorized to access this conversation');
    }

    return this.prisma.chatMessage.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'asc' },
    });
  }

  async sendMessage(
    conversationId: string,
    senderId: string,
    senderRole: string,
    content: string,
    attachmentUrl?: string,
  ) {
    if (!content || !content.trim()) {
      throw new BadRequestException('Message content cannot be empty');
    }

    const conversation = await this.prisma.chatConversation.findUnique({
      where: { id: conversationId },
      include: { vendor: true },
    });

    if (!conversation) {
      throw new NotFoundException(`Conversation with ID ${conversationId} not found`);
    }

    // Authorization
    if (
      senderRole !== 'ADMIN' &&
      senderRole !== 'SUPPORT_AGENT' &&
      conversation.customerId !== senderId &&
      conversation.vendor?.userId !== senderId
    ) {
      throw new ForbiddenException('Not authorized to send messages in this conversation');
    }

    const [message] = await this.prisma.$transaction([
      this.prisma.chatMessage.create({
        data: {
          conversationId,
          senderId,
          senderRole,
          content: content.trim(),
          attachmentUrl: attachmentUrl || null,
        },
      }),
      this.prisma.chatConversation.update({
        where: { id: conversationId },
        data: { lastMessageAt: new Date() },
      }),
    ]);

    return message;
  }

  async markMessagesAsRead(conversationId: string, userId: string) {
    return this.prisma.chatMessage.updateMany({
      where: {
        conversationId,
        senderId: { not: userId },
        isRead: false,
      },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });
  }
}
