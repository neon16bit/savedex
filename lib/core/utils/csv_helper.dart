class CsvHelper {
  static List<List<String>> parseCsv(String input) {
    final List<List<String>> rows = [];
    if (input.trim().isEmpty) return rows;

    List<String> currentRow = [];
    final StringBuffer currentField = StringBuffer();
    bool inQuotes = false;
    int i = 0;

    while (i < input.length) {
      final char = input[i];

      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            currentField.write('"');
            i += 2;
            continue;
          } else {
            inQuotes = false;
            i++;
            continue;
          }
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      } else {
        if (char == '"') {
          inQuotes = true;
          i++;
          continue;
        } else if (char == ',') {
          currentRow.add(currentField.toString());
          currentField.clear();
          i++;
          continue;
        } else if (char == '\r') {
          if (i + 1 < input.length && input[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentField.toString());
          currentField.clear();
          rows.add(currentRow);
          currentRow = [];
          i++;
          continue;
        } else if (char == '\n') {
          currentRow.add(currentField.toString());
          currentField.clear();
          rows.add(currentRow);
          currentRow = [];
          i++;
          continue;
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      }
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString());
      rows.add(currentRow);
    }

    return rows;
  }

  static String encodeCsv(List<List<dynamic>> rows) {
    final buffer = StringBuffer();

    for (final row in rows) {
      final line = row
          .map((field) {
            final str = field?.toString() ?? '';
            if (str.contains(',') ||
                str.contains('"') ||
                str.contains('\n') ||
                str.contains('\r')) {
              final escaped = str.replaceAll('"', '""');
              return '"$escaped"';
            }
            return str;
          })
          .join(',');

      buffer.write('$line\r\n');
    }

    return buffer.toString();
  }
}
