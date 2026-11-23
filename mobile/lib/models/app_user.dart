enum UserRole { mentee, mentor }

extension UserRoleX on UserRole {
  String get label => this == UserRole.mentee ? '멘티' : '멘토';
}

/// 학교급 (멘티)
enum SchoolLevel { elementary, middle, high }

extension SchoolLevelX on SchoolLevel {
  String get label => switch (this) {
        SchoolLevel.elementary => '초등학교',
        SchoolLevel.middle => '중학교',
        SchoolLevel.high => '고등학교',
      };

  int get maxGrade => this == SchoolLevel.elementary ? 6 : 3;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.nickname = '',
    this.role,
    this.schoolLevel,
    this.schoolName,
    this.grade,
    this.department,
    this.studentId,
    this.subjects = const [],
    this.bio,
    this.points = 0,
  });

  final String id;
  final String email;
  final String nickname;
  final UserRole? role;

  // 멘티
  final SchoolLevel? schoolLevel;
  final String? schoolName;
  final int? grade;

  // 멘토
  final String? department;
  final String? studentId;
  final List<String> subjects;
  final String? bio;
  final int points;

  bool get isProfileComplete {
    if (role == null || nickname.trim().isEmpty) return false;
    if (role == UserRole.mentee) {
      return schoolLevel != null && schoolName != null && grade != null;
    }
    return department != null && studentId != null && subjects.isNotEmpty;
  }

  String get displayName => nickname.isEmpty ? email.split('@').first : nickname;

  AppUser copyWith({
    String? nickname,
    UserRole? role,
    SchoolLevel? schoolLevel,
    String? schoolName,
    int? grade,
    String? department,
    String? studentId,
    List<String>? subjects,
    String? bio,
    int? points,
  }) {
    return AppUser(
      id: id,
      email: email,
      nickname: nickname ?? this.nickname,
      role: role ?? this.role,
      schoolLevel: schoolLevel ?? this.schoolLevel,
      schoolName: schoolName ?? this.schoolName,
      grade: grade ?? this.grade,
      department: department ?? this.department,
      studentId: studentId ?? this.studentId,
      subjects: subjects ?? this.subjects,
      bio: bio ?? this.bio,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nickname': nickname,
        'role': role?.name,
        'schoolLevel': schoolLevel?.name,
        'schoolName': schoolName,
        'grade': grade,
        'department': department,
        'studentId': studentId,
        'subjects': subjects,
        'bio': bio,
        'points': points,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    T? byName<T extends Enum>(List<T> values, Object? name) {
      if (name is! String) return null;
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      nickname: (json['nickname'] as String?) ?? '',
      role: byName(UserRole.values, json['role']),
      schoolLevel: byName(SchoolLevel.values, json['schoolLevel']),
      schoolName: json['schoolName'] as String?,
      grade: json['grade'] as int?,
      department: json['department'] as String?,
      studentId: json['studentId'] as String?,
      subjects: ((json['subjects'] as List?) ?? const []).cast<String>(),
      bio: json['bio'] as String?,
      points: (json['points'] as int?) ?? 0,
    );
  }
}
