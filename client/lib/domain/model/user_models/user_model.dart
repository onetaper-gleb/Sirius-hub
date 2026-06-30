import 'package:client/domain/model/user_models/user_role.dart';

class UserModel {
  final String id; // Уникальный UID из Firebase Auth
  final String email; // Почта
  final UserRole role; // Наша роль (студент или студсовет)
  final String?
  name; // Имя (nullable, так как при регистрации его может не быть)

  const UserModel({
    required this.id,
    required this.email,
    this.role = UserRole.student,
    this.name,
  });

  factory UserModel.fromFirestore(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      email: data['email'] ?? '',
      role: UserRole.fromString(data['role'] ?? 'student'),
      name: data['name'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'email': email, 'role': role.name, if (name != null) 'name': name};
  }
}
