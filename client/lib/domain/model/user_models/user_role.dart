enum UserRole {
  student,
  council,
  admin;

  bool get canManageContent => this == council || this == admin;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'council':
        return UserRole.council;
      case 'admin':
        return UserRole.admin;
      case 'student':
      default:
        return UserRole.student;
    }
  }
}
