import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('NotificationModel null safety tests', () {
    test('NotificationModel.fromJson handles null title, body, and type safely', () {
      final Map<String, dynamic> jsonWithNulls = {
        'id': 'notif-123',
        'userId': null,
        'title': null,
        'body': null,
        'type': null,
        'isRead': null,
        'createdAt': '2026-07-29T10:00:00.000Z',
      };

      final model = NotificationModel.fromJson(jsonWithNulls);

      expect(model.id, equals('notif-123'));
      expect(model.userId, equals(''));
      expect(model.title, equals('Notification'));
      expect(model.body, equals(''));
      expect(model.type, equals('SYSTEM'));
      expect(model.isRead, equals(false));
    });
  });
}
