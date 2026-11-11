import 'package:patilog/core/services/id_generator.dart';
import 'package:uuid/uuid.dart';

final class UuidGenerator implements IdGenerator {
  final Uuid _uuid = Uuid();

  @override
  String generate() => _uuid.v4();
}
