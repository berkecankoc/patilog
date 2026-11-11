import 'package:patilog/core/error/exception.dart';
import 'package:patilog/features/notification/data/codecs/notification_preferences_codec.dart';
import 'package:patilog/features/notification/domain/entities/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class NotificationPreferencesLocalDataSource {
  Future<NotificationPreferences> getPreferences();
  Future<void> savePreferences(NotificationPreferences preferences);
}

final class NotificationPreferencesLocalDataSourceImpl
    implements NotificationPreferencesLocalDataSource {
  final SharedPreferencesAsync preferences;
  static const _key = 'notification.preferences';

  const NotificationPreferencesLocalDataSourceImpl(this.preferences);

  @override
  Future<NotificationPreferences> getPreferences() async {
    try {
      final values = await preferences.getAll(allowList: {_key});
      final stored = values[_key];
      if (stored == null) return NotificationPreferences();
      if (stored is! String) throw const FormatException();
      return NotificationPreferencesCodec.decode(stored);
    } on Exception {
      throw const PreferencesStorageException();
    }
  }

  @override
  Future<void> savePreferences(NotificationPreferences value) async {
    try {
      // One value prevents partial category/timing updates.
      await preferences.setString(
        _key,
        NotificationPreferencesCodec.encode(value),
      );
    } on Exception {
      throw const PreferencesStorageException();
    }
  }
}
