String _twoDigits(int value) => value.toString().padLeft(2, '0');

String formatDate(DateTime date) =>
    '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';

String formatDateTime(DateTime date) =>
    '${formatDate(date)} ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
