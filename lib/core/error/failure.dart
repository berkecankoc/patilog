import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

final class LocalDatabaseFailure extends Failure {
  const LocalDatabaseFailure(super.message);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

final class ImageStorageFailure extends Failure {
  const ImageStorageFailure(super.message);
}

final class PreferencesStorageFailure extends Failure {
  const PreferencesStorageFailure(super.message);
}

final class NotificationFailure extends Failure {
  const NotificationFailure(super.message);
}
