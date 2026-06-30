// Перечисление доступных ролей
enum UserRole {
  student,
  council;

  // Метод-помощник: преобразует строку из базы данных в Enum
  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'council':
        return UserRole.council;
      case 'student':
      default:
        return UserRole.student; // Если что-то непонятное, делаем студентом
    }
  }
}
