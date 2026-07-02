import 'package:cwc/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

class WalletModel {
  final String userId;
  final double balance;
  final String currency;

  WalletModel({
    required this.userId,
    required this.balance,
    this.currency = 'PKR',
  });

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      userId: map['user_id'] ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] ?? 'PKR',
    );
  }
}

class WalletTransactionModel {
  final String id;
  final double amount;
  final String txnType;
  final String reason;
  final DateTime createdAt;

  WalletTransactionModel({
    required this.id,
    required this.amount,
    required this.txnType,
    required this.reason,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromMap(Map<String, dynamic> map) {
    return WalletTransactionModel(
      id: map['id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      txnType: map['txn_type'] ?? '',
      reason: map['reason'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}

class WalletService {
  final _supabase = SupabaseService.client;
  final _uuid = const Uuid();

  Future<WalletModel> getWallet(String userId) async {
    final row = await _supabase
        .from('user_wallets')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      return WalletModel(userId: userId, balance: 0);
    }
    return WalletModel.fromMap(row);
  }

  Future<List<WalletTransactionModel>> getTransactions(String userId) async {
    final rows = await _supabase
        .from('wallet_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return rows.map((r) => WalletTransactionModel.fromMap(r)).toList();
  }

  /// Request refund to wallet after paid booking cancellation.
  Future<void> requestRefund({
    required String userId,
    required String bookingId,
    required String paymentId,
    required double amount,
    String? reason,
  }) async {
    final existing = await _supabase
        .from('refund_requests')
        .select('id')
        .eq('booking_id', bookingId)
        .eq('status', 'pending')
        .maybeSingle();

    if (existing != null) {
      throw Exception('A refund request is already pending for this booking.');
    }

    await _supabase.from('refund_requests').insert({
      'id': _uuid.v4(),
      'user_id': userId,
      'booking_id': bookingId,
      'payment_id': paymentId,
      'amount': amount,
      'reason': reason ?? 'Booking cancellation',
      'status': 'pending',
    });
  }

  /// Pay booking from wallet balance via secure RPC.
  Future<void> payFromWallet({
    required String userId,
    required String bookingId,
    required double amount,
  }) async {
    await _supabase.rpc('pay_booking_from_wallet', params: {
      'p_booking_id': bookingId,
      'p_amount': amount,
    });
  }

  /// Debit partial wallet amount for split payment (bank/EasyPaisa covers remainder).
  Future<String> debitForSplitPayment({
    required String bookingId,
    required double walletAmount,
    required double totalAmount,
  }) async {
    final result = await _supabase.rpc('debit_wallet_for_split_payment', params: {
      'p_booking_id': bookingId,
      'p_wallet_amount': walletAmount,
      'p_total_amount': totalAmount,
    });
    return result as String;
  }

  Future<double> getPlatformFeePercent() async {
    final result = await _supabase.rpc('get_platform_fee_percent');
    return (result as num?)?.toDouble() ?? 10;
  }

  Future<void> requestOwnerPayout({
    required double amount,
    required String ownerAccountId,
  }) async {
    await _supabase.rpc('request_owner_payout', params: {
      'p_amount': amount,
      'p_owner_account_id': ownerAccountId,
    });
  }
}
