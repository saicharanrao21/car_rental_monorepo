class DocumentExpiryStatus {
  final bool isExpired;
  final bool isExpiringSoon;
  final int daysRemaining;
  final String badgeText;

  DocumentExpiryStatus({
    required this.isExpired,
    required this.isExpiringSoon,
    required this.daysRemaining,
    required this.badgeText,
  });
}

DocumentExpiryStatus? checkDocumentExpiry(DateTime? expiresAt) {
  if (expiresAt == null) return null;
  final today = DateTime.now();
  final expiryDate = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
  final currentDate = DateTime(today.year, today.month, today.day);
  final days = expiryDate.difference(currentDate).inDays;

  if (days < 0) {
    return DocumentExpiryStatus(
      isExpired: true,
      isExpiringSoon: false,
      daysRemaining: days,
      badgeText: 'Expired',
    );
  } else if (days <= 30) {
    return DocumentExpiryStatus(
      isExpired: false,
      isExpiringSoon: true,
      daysRemaining: days,
      badgeText: days == 0 ? 'Expires today' : 'Expires in $days ${days == 1 ? 'day' : 'days'}',
    );
  }
  return null;
}
