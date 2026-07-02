import 'package:cwc/utils/helpers/model_helpers.dart';

/// CWC platform account for receiving user payments (middle-man model).
class PlatformPaymentAccountModel {
  final String id;
  final String accountType;
  final String accountTitle;
  final String accountNumber;
  final String? bankName;
  final bool isActive;
  final bool isDefault;

  PlatformPaymentAccountModel({
    required this.id,
    required this.accountType,
    required this.accountTitle,
    required this.accountNumber,
    this.bankName,
    this.isActive = true,
    this.isDefault = false,
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

  factory PlatformPaymentAccountModel.fromMap(Map<String, dynamic> map) {
    return PlatformPaymentAccountModel(
      id: map['id'] ?? '',
      accountType: getStringFromMap(map, 'account_type', 'accountType') ?? 'bank',
      accountTitle: getStringFromMap(map, 'account_title', 'accountTitle') ?? '',
      accountNumber: getStringFromMap(map, 'account_number', 'accountNumber') ?? '',
      bankName: getStringFromMap(map, 'bank_name', 'bankName'),
      isActive: getValueFromMap(map, 'is_active', 'isActive', true) as bool,
      isDefault: getValueFromMap(map, 'is_default', 'isDefault', false) as bool,
    );
  }
}
