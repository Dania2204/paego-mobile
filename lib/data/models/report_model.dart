import '../../core/l10n/app_strings.dart';

enum FoodCondition { good, fair, poor }

extension FoodConditionX on FoodCondition {
  String get label {
    switch (this) {
      case FoodCondition.good:
        return S.reportConditionGood;
      case FoodCondition.fair:
        return S.reportConditionFair;
      case FoodCondition.poor:
        return S.reportConditionPoor;
    }
  }

  static FoodCondition fromString(String v) => FoodCondition.values.firstWhere(
    (e) => e.name == v,
    orElse: () => FoodCondition.good,
  );
}

class DeliveryReport {
  DeliveryReport({
    this.id,
    required this.orderId,
    required this.schoolName,
    required this.submittedByUserId,
    required this.submittedByName,
    required this.condition,
    required this.notes,
    required this.photoPaths,
    this.createdAt,
    this.isSynced = false,
  });

  final int? id;
  final int orderId;
  final String schoolName;
  final int submittedByUserId;
  final String submittedByName;
  final FoodCondition condition;
  final String notes;
  final List<String> photoPaths;
  final DateTime? createdAt;
  final bool isSynced;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'order_id': orderId,
    'school_name': schoolName,
    'submitted_by_user_id': submittedByUserId,
    'submitted_by_name': submittedByName,
    'condition': condition.name,
    'notes': notes,
    'photo_paths': photoPaths.join('|'),
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    'is_synced': isSynced ? 1 : 0,
  };

  factory DeliveryReport.fromMap(Map<String, dynamic> m) => DeliveryReport(
    id: m['id'] as int?,
    orderId: m['order_id'] as int? ?? 0,
    schoolName: m['school_name'] as String? ?? '',
    submittedByUserId: m['submitted_by_user_id'] as int? ?? 0,
    submittedByName: m['submitted_by_name'] as String? ?? '',
    condition: FoodConditionX.fromString(m['condition'] as String? ?? 'good'),
    notes: m['notes'] as String? ?? '',
    photoPaths: (m['photo_paths'] as String? ?? '')
        .split('|')
        .where((p) => p.isNotEmpty)
        .toList(),
    createdAt: m['created_at'] != null
        ? DateTime.tryParse(m['created_at'] as String)
        : null,
    isSynced: (m['is_synced'] as int? ?? 0) == 1,
  );
}
