import 'dart:convert';

import 'package:supabase/supabase.dart';

Future<void> main() async {
  const url = 'https://njtpfiigzvxytwivipxs.supabase.co';
  const anonKey = 'sb_publishable_yJkW8eLqJ9Vod48IthOSQw_x_tSWc8c';

  final client = SupabaseClient(url, anonKey);

  try {
    final rows = await client
        .from('activities_with_participation_data')
        .select()
        .limit(1);

    if (rows is List && rows.isNotEmpty && rows.first is Map) {
      final first = rows.first as Map;
      print('OK: got ${rows.length} row(s). Keys:');
      for (final k in first.keys) {
        print(' - $k (${first[k]?.runtimeType})');
      }
      print('Sample row:');
      print(const JsonEncoder.withIndent('  ').convert(first));
      return;
    }

    print('OK: got response of type ${rows.runtimeType}');
    print(rows);
  } catch (e) {
    print('ERROR selecting activities_with_participation_data: $e');
  }
}

