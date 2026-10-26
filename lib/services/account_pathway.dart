enum AccountPathway {
  veteran('veteran', 'Veteran pathway', 'Veteran business owner'),
  user('user', 'User', 'All users');

  final String value;
  final String label;
  final String audience;
  const AccountPathway(this.value, this.label, this.audience);
  bool get canManageBusiness => this == veteran;
  bool get canViewCareers => this == veteran;

  static AccountPathway? fromValue(Object? value) {
    for (final pathway in values) {
      if (pathway.value == value) return pathway;
    }
    return null;
  }
}

bool isValidDodId(String value) =>
    RegExp(r'^[0-9]{10}$').hasMatch(value.trim());
