/// Hedef: kilo ver / koru / al.
enum Goal {
  lose,
  maintain,
  gain,
}

extension GoalX on Goal {
  String get label {
    switch (this) {
      case Goal.lose:
        return 'Kilo ver';
      case Goal.maintain:
        return 'Kilo koru';
      case Goal.gain:
        return 'Kilo al';
    }
  }
}
