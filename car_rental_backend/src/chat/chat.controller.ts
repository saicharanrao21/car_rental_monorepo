import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  UseGuards,
  Request,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ChatService } from './chat.service';

@Controller('chat')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Post('conversations')
  async getOrCreateConversation(
    @Request() req: any,
    @Body() body: { vendorId?: string; bookingId?: string },
  ) {
    const customerId = req.user.userId || req.user.id;
    return this.chatService.getOrCreateConversation(customerId, body.vendorId, body.bookingId);
  }

  @Get('conversations')
  async listConversations(@Request() req: any) {
    const userId = req.user.userId || req.user.id;
    const userRole = req.user.role;
    return this.chatService.listUserConversations(userId, userRole);
  }

  @Get('conversations/:id/messages')
  async getMessages(@Request() req: any, @Param('id') conversationId: string) {
    const userId = req.user.userId || req.user.id;
    const userRole = req.user.role;
    return this.chatService.getConversationMessages(conversationId, userId, userRole);
  }

  @Post('conversations/:id/messages')
  async sendMessage(
    @Request() req: any,
    @Param('id') conversationId: string,
    @Body() body: { content: string; attachmentUrl?: string },
  ) {
    const senderId = req.user.userId || req.user.id;
    const senderRole = req.user.role;
    return this.chatService.sendMessage(
      conversationId,
      senderId,
      senderRole,
      body.content,
      body.attachmentUrl,
    );
  }

  @Patch('conversations/:id/read')
  async markRead(@Request() req: any, @Param('id') conversationId: string) {
    const userId = req.user.userId || req.user.id;
    return this.chatService.markMessagesAsRead(conversationId, userId);
  }
}
