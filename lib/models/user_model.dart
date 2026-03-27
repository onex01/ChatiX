class UserModel {
  final String uid;
  final String email;
  final String nickname;
  final String? photoUrl;
  final String? bio;          // Новое поле

  UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    this.photoUrl,
    this.bio,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'nickname': nickname.toLowerCase().trim(), 
      'photoUrl': photoUrl,
      'bio': bio ?? '',
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      nickname: map['nickname'] ?? '',
      photoUrl: map['photoUrl'],
      bio: map['bio'],
    );
  }
}