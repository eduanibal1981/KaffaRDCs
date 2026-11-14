import 'dart:convert';
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<Map<String, dynamic>> persistEvidence(
    SupabaseClient client, XFile file, String entityPath,
    {Future<Directory> Function()? supportDirectory}) async {
  final user = client.auth.currentUser?.id;
  final sample = Uri.parse(client.rest.url).host == 'preview.kafaa.invalid';
  if (user == null && !sample) throw StateError('KAFAA_ACCESS_DENIED');
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.length > 26214400) {
    throw StateError('KAFAA_PROOF_FORMAT');
  }
  final hash = sha256.convert(bytes).toString();
  if (kIsWeb || sample) {
    return {
      'file_bytes': base64Encode(bytes),
      'size_bytes': bytes.length,
      'content_sha256': hash
    };
  }
  final support = await (supportDirectory ?? getApplicationSupportDirectory)();
  final path = p.join(support.path, 'kafaa_evidence',
      Uri.parse(client.rest.url).host, user!, 'center-self', entityPath);
  await Directory(p.dirname(path)).create(recursive: true);
  final out = File(path);
  await out.writeAsBytes(bytes, flush: true);
  return {
    'local_path': path,
    'size_bytes': bytes.length,
    'content_sha256': hash
  };
}

Future<Uint8List> readPersistedEvidence(Map<String, dynamic> row) async {
  final encoded = row['file_bytes'] as String?;
  if (encoded != null) {
    final bytes = base64Decode(encoded);
    if (row['content_sha256'] != null &&
        sha256.convert(bytes).toString() != row['content_sha256']) {
      throw StateError('KAFAA_PROOF_LOCAL_MISSING');
    }
    return bytes;
  }
  final file = File(row['local_path'] as String);
  if (!await file.exists()) throw StateError('KAFAA_PROOF_LOCAL_MISSING');
  final bytes = await file.readAsBytes();
  if (row['content_sha256'] != null &&
      sha256.convert(bytes).toString() != row['content_sha256']) {
    throw StateError('KAFAA_PROOF_LOCAL_MISSING');
  }
  return bytes;
}
