import 'package:intl/intl.dart';

class DateFormatter {
  static String timeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now().toUtc();
    final difference = now.difference(dateTime.toUtc());

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'mins'} ago';
    } else {
      return 'just now';
    }
  }

  static String fullDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime.toLocal());
  }

  static String shortDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('MMM d, yyyy').format(dateTime.toLocal());
  }

  static String compactNumber(int number) {
    if (number.abs() < 1000) {
      return number.toString();
    } else if (number.abs() < 1000000) {
      final k = number / 1000.0;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    } else {
      final m = number / 1000000.0;
      return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}M';
    }
  }
}
