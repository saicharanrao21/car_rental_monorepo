import 'package:intl/intl.dart';

class IndianCurrencyFormatter {
  static final NumberFormat _formatterWithDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _formatterNoDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Formats a number into Indian Rupees with lakh/crore grouping.
  static String format(num amount, {bool showDecimals = true}) {
    if (showDecimals) {
      return _formatterWithDecimals.format(amount);
    } else {
      return _formatterNoDecimals.format(amount);
    }
  }
}

class DateTimeUtils {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  /// Formats a DateTime as DD/MM/YYYY
  static String formatDate(DateTime dateTime) {
    return _dateFormat.format(dateTime);
  }

  /// Formats a DateTime as DD/MM/YYYY HH:mm
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }
}

extension IndianCurrencyExtension on num {
  /// Converts a number to Indian Rupees format (e.g., ₹1,50,000.00)
  String toIndianRupee({bool showDecimals = true}) {
    return IndianCurrencyFormatter.format(this, showDecimals: showDecimals);
  }
}

extension DateTimeExtension on DateTime {
  /// Converts a DateTime to DD/MM/YYYY string format
  String toDDMMYYYY() {
    return DateTimeUtils.formatDate(this);
  }

  /// Converts a DateTime to DD/MM/YYYY HH:mm string format
  String toDDMMYYYYHHMM() {
    return DateTimeUtils.formatDateTime(this);
  }
}
