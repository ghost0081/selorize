class UserModel {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String gender;
  final String aadharCard;
  final String aadharCardImage;
  final String profileImage;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    this.gender = '',
    this.aadharCard = '',
    this.aadharCardImage = '',
    this.profileImage = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      aadharCard: json['aadharCard']?.toString() ?? '',
      aadharCardImage: json['aadharCardImage']?.toString() ?? '',
      profileImage: json['profileImage']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'mobile': mobile,
    'gender': gender,
    'aadharCard': aadharCard,
    'aadharCardImage': aadharCardImage,
    'profileImage': profileImage,
  };
}
