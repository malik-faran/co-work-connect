import 'package:cwc/utils/helpers/model_helpers.dart';

/// Owner bank / EasyPaisa / JazzCash account for receiving payments.
class OwnerPaymentAccountModel {
  final String id;
  final String ownerId;
  final String? workspaceId;
  final String accountType;
  final String accountTitle;
  final String accountNumber;
  final String? bankName;
  final bool isActive;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;

  OwnerPaymentAccountModel({
    required this.id,
    required this.ownerId,
    this.workspaceId,
    required this.accountType,
    required this.accountTitle,
    required this.accountNumber,
    this.bankName,
    this.isActive = true,
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
  });

  String get displayLabel {
    switch (accountType) {
      case 'easypaisa':
        return 'EasyPaisa';
      case 'jazzcash':
        return 'JazzCash';
      default:
        return bankName != null && bankName!.isNotEmpty ? bankName! : 'Bank Account';
    }
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'owner_id': ownerId,
      'account_type': accountType,
      'account_title': accountTitle,
      'account_number': accountNumber,
      'is_active': isActive,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
    };
    if (workspaceId != null) map['workspace_id'] = workspaceId;
    if (bankName != null) map['bank_name'] = bankName;
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    return map;
  }

  factory OwnerPaymentAccountModel.fromMap(Map<String, dynamic> map) {
    return OwnerPaymentAccountModel(
      id: map['id'] ?? '',
      ownerId: getStringFromMap(map, 'owner_id', 'ownerId') ?? '',
      workspaceId: getStringFromMap(map, 'workspace_id', 'workspaceId'),
      accountType: getStringFromMap(map, 'account_type', 'accountType') ?? 'bank',
      accountTitle: getStringFromMap(map, 'account_title', 'accountTitle') ?? '',
      accountNumber: getStringFromMap(map, 'account_number', 'accountNumber') ?? '',
      bankName: getStringFromMap(map, 'bank_name', 'bankName'),
      isActive: getValueFromMap(map, 'is_active', 'isActive', true) as bool,
      isDefault: getValueFromMap(map, 'is_default', 'isDefault', false) as bool,
      createdAt: getStringFromMap(map, 'created_at', 'createdAt') != null
          ? DateTime.parse(getStringFromMap(map, 'created_at', 'createdAt')!)
          : DateTime.now(),
      updatedAt: getStringFromMap(map, 'updated_at', 'updatedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'updated_at', 'updatedAt')!)
          : null,
    );
  }
}
