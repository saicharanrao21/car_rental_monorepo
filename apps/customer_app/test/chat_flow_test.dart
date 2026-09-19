import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/features/chat/presentation/pages/chat_conversation_page.dart';

void main() {
  testWidgets('ChatConversationPage renders initial messages and sends new customer message', (tester) async {
    String? sentContent;

    final initialMessages = [
      ChatMessageModel(
        id: 'm1',
        senderId: 'host_42',
        senderRole: 'VENDOR',
        content: 'Your car is washed and ready at the terminal pickup zone!',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        isOutgoing: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ChatConversationPage(
            conversationId: 'conv_test_123',
            title: 'Host Chat - DL-01-AB-1234',
            initialMessages: initialMessages,
            onSendMessage: (msg) async {
              sentContent = msg;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header and initial message
    expect(find.text('Host Chat - DL-01-AB-1234'), findsOneWidget);
    expect(find.text('Host / Fleet Partner'), findsOneWidget);
    expect(find.text('Your car is washed and ready at the terminal pickup zone!'), findsOneWidget);

    // Type a message in input field
    final inputFinder = find.byKey(const Key('chat_input_field'));
    expect(inputFinder, findsOneWidget);

    await tester.enterText(inputFinder, 'Awesome! On my way to the pickup spot now.');
    await tester.pump();

    // Tap send button
    final sendButtonFinder = find.byKey(const Key('chat_send_button'));
    expect(sendButtonFinder, findsOneWidget);

    await tester.tap(sendButtonFinder);
    await tester.pumpAndSettle();

    // Verify outgoing message bubble was added to UI
    expect(find.text('Awesome! On my way to the pickup spot now.'), findsOneWidget);
    expect(sentContent, equals('Awesome! On my way to the pickup spot now.'));
  });
}
