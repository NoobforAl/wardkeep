import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../l10n/errors.dart';
import '../l10n/l10n.dart';

/// Why a file cannot be imported.
enum ImportFileProblem { empty, tooLarge, notText }

class ImportFileException implements Exception {
  const ImportFileException(this.problem);

  final ImportFileProblem problem;

  @override
  String toString() => 'ImportFileException(${problem.name})';
}

/// The most a config file may hold, in bytes. The core refuses more as well (importer.MaxTextSize).
const importMaxBytes = 8 << 20;

/// The text of a config file. UTF-8 (with or without a byte order mark) and UTF-16 with one (what Windows
/// Notepad calls "Unicode") are read; anything else is not text as far as an import is concerned.
String decodeImportFile(List<int> bytes) {
  if (bytes.isEmpty) throw const ImportFileException(ImportFileProblem.empty);
  if (bytes.length > importMaxBytes) throw const ImportFileException(ImportFileProblem.tooLarge);
  String text;
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    text = _utf16(bytes, Endian.little);
  } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    text = _utf16(bytes, Endian.big);
  } else {
    // A zero byte in the first few kilobytes is a binary file (an image, an archive), not a config.
    if (bytes.take(4096).contains(0)) throw const ImportFileException(ImportFileProblem.notText);
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const ImportFileException(ImportFileProblem.notText);
    }
  }
  if (text.startsWith('﻿')) text = text.substring(1);
  if (text.trim().isEmpty) throw const ImportFileException(ImportFileProblem.empty);
  return text;
}

String _utf16(List<int> bytes, Endian endian) {
  final data = ByteData.sublistView(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
  final units = <int>[for (var i = 2; i + 1 < bytes.length; i += 2) data.getUint16(i, endian)];
  return String.fromCharCodes(units);
}

/// Reads a file the user picked: refuses one that is too large before reading it, then decodes it.
Future<String> readImportFile(PlatformFile file) async {
  if (await file.xFile.length() > importMaxBytes) throw const ImportFileException(ImportFileProblem.tooLarge);
  return decodeImportFile(await file.xFile.readAsBytes());
}

/// Why a file could not be read, in the user's language.
String describeFileProblem(AppLocalizations l, Object e) {
  if (e is ImportFileException) {
    return switch (e.problem) {
      ImportFileProblem.empty => l.importFileEmpty,
      ImportFileProblem.tooLarge => l.importTooLarge(importMaxBytes >> 20),
      ImportFileProblem.notText => l.importFileNotText,
    };
  }
  if (e is PathNotFoundException) return l.importFileMissing;
  if (e is PathAccessException) return l.importFileNoPermission;
  if (e is FileSystemException) {
    // The numbers are POSIX errno values and the Windows ones that mean the same.
    switch (e.osError?.errorCode) {
      case 1 || 13 || 5:
        return l.importFileNoPermission;
      case 2 || 3:
        return l.importFileMissing;
    }
  }
  return l.couldNotReadFile(describeError(l, e));
}
