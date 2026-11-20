class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String fullName;
  final String role;
  final bool isActive;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    fullName: json['full_name'] as String? ?? 'Usuario',
    role: json['role'] as String? ?? 'worker',
    isActive: json['is_active'] as bool? ?? false,
  );
}
