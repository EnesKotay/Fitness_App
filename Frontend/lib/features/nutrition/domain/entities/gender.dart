/// Cinsiyet (BMR formülü için).
enum Gender {
  male,
  female,
}

extension GenderX on Gender {
  String get label => this == Gender.male ? 'Erkek' : 'Kadın';
}
