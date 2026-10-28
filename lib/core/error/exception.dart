sealed class AppException implements Exception {
  const AppException();
}

final class LocalDataSourceException extends AppException {
  const LocalDataSourceException();
}

final class LocalDataNotFoundException extends AppException {
  const LocalDataNotFoundException();
}

final class ImageStorageException extends AppException {
  const ImageStorageException();
}

final class PreferencesStorageException extends AppException {
  const PreferencesStorageException();
}

final class NotificationPlatformException extends AppException {
  const NotificationPlatformException();
}
