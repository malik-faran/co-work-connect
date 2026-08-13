import 'dart:convert';
import 'package:cwc/models/notification_model.dart';
import 'package:cwc/models/payment_model.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/services/booking_service.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/services/wallet_service.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Payment Service
/// Handles payment processing with Stripe integration
class PaymentService {
  final _supabase = SupabaseService.client;
  final _uuid = const Uuid();
  
  // Stripe Configuration
  // NOTE: In production, these should be stored securely (e.g., environment variables)
  static const String stripePublishableKey = 'pk_test_51T3jkzGWYJoNa16xYiXyZ7XOrDQYCrNEgQgtjIQB0sDdpq97ZHeJvj5MbQkEm2rGw12edram8Jpy4gOj8NAVfFF900IMUpuwVY';
  static const String stripeSecretKey = 'sk_test_51T3jkzGWYJoNa16x2kUEiL1KRUCtTSXPPlDbpwZBMFRjuiws6pwd12X6jGcOJb1pPXZ1327UwXg959daMLr7dtTb00eytD3EBo';
  static const String stripeApiUrl = 'https://api.stripe.com/v1';

  /// Stripe test mode does not support PKR — charge in USD at this approximate rate.
  static const double _pkrPerUsd = 280.0;

  static int _pkrToUsdCents(double pkrAmount) {
    final usd = pkrAmount / _pkrPerUsd;
    return (usd * 100).round().clamp(50, 99999999);
  }

  Future<PaymentModel> _requireUpdatedPayment(
    String paymentId,
    Map<String, dynamic> patch,
  ) async {
    final rows = await _supabase
        .from('payments')
        .update(patch)
        .eq('id', paymentId)
        .select();

    if (rows.isEmpty) {
      throw Exception(
        'Could not update payment. Please sign in again or contact support.',
      );
    }
    return PaymentModel.fromPaymentMap(rows.first);
  }

  /// Create manual payment (bank / EasyPaisa) — no Stripe.
  ///
  /// If a payment row already exists for this booking (e.g. a Stripe one created
  /// when the user first opened the screen), it is converted to manual instead
  /// of inserting a duplicate. This avoids "failed to switch payment method"
  /// errors and guarantees the owner sees the receipt under a manual payment.
  Future<PaymentModel> createManualPayment({
    required String bookingId,
    required String userId,
    required double amount,
    String currency = 'PKR',
  }) async {
    final expiresAt = DateTime.now().add(const Duration(hours: 24));
    final existing = await getPaymentByBookingId(bookingId);

    if (existing != null && existing.status != 'completed') {
      // Keep an in-progress receipt status if one was already submitted.
      final keepReceipt =
          existing.receiptStatus == AppConstants.receiptAwaitingVerification ||
              existing.receiptStatus == AppConstants.receiptApproved;
      return _requireUpdatedPayment(existing.id, {
        'payment_method': AppConstants.paymentMethodManual,
        'status': 'pending',
        'receipt_status': keepReceipt
            ? existing.receiptStatus
            : AppConstants.receiptAwaitingUpload,
        'stripe_payment_intent_id': null,
        'stripe_client_secret': null,
        'failure_reason': null,
        if (!keepReceipt) 'owner_account_id': null,
        if (!keepReceipt) 'receipt_url': null,
        if (!keepReceipt) 'transfer_reference': null,
        'expires_at': expiresAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    final payment = PaymentModel(
      id: _uuid.v4(),
      bookingId: bookingId,
      userId: userId,
      amount: amount,
      currency: currency,
      status: 'pending',
      paymentMethod: AppConstants.paymentMethodManual,
      receiptStatus: AppConstants.receiptAwaitingUpload,
      payeeType: AppConstants.payeePlatform,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
    );

    final paymentData = payment.toPaymentMap()
      ..removeWhere((key, value) => value == null);

    await _supabase.from('payments').insert(paymentData);
    return payment;
  }

  /// User submits receipt after transfer to CWC platform account.
  Future<void> submitManualReceipt({
    required String paymentId,
    required String platformAccountId,
    required String receiptUrl,
    String? transferReference,
  }) async {
    final existing = await getPaymentById(paymentId);
    final payment = await _requireUpdatedPayment(paymentId, {
      if (existing?.isSplit != true)
        'payment_method': AppConstants.paymentMethodManual,
      'status': 'pending',
      'payee_type': AppConstants.payeePlatform,
      'platform_account_id': platformAccountId,
      'owner_account_id': null,
      'receipt_url': receiptUrl,
      'receipt_status': AppConstants.receiptAwaitingVerification,
      'transfer_reference': transferReference,
      'failure_reason': null,
      'updated_at': DateTime.now().toIso8601String(),
    });

    try {
      final bookingData = await _supabase
          .from('bookings')
          .select('workspace_name')
          .eq('id', payment.bookingId)
          .maybeSingle();

      // Notify user — CWC team will verify (moderator handles in admin panel)
      final notificationService = NotificationService();
      await notificationService.createNotification(
        NotificationModel(
          id: _uuid.v4(),
          userId: payment.userId,
          title: 'Receipt submitted',
          message:
              'Your payment receipt for ${bookingData?['workspace_name'] ?? 'booking'} is under review by CWC team.',
          type: 'payment_receipt_submitted',
          createdAt: DateTime.now(),
          metadata: {
            'booking_id': payment.bookingId,
            'payment_id': paymentId,
          },
        ),
      );
    } catch (_) {}
  }

  /// Pay booking using in-app wallet balance.
  Future<void> payWithWallet({
    required String bookingId,
    required String userId,
    required double amount,
  }) async {
    final walletService = WalletService();
    await walletService.payFromWallet(
      userId: userId,
      bookingId: bookingId,
      amount: amount,
    );

    final existing = await getPaymentByBookingId(bookingId);
    if (existing != null) {
      await _requireUpdatedPayment(existing.id, {
        'payment_method': AppConstants.paymentMethodWallet,
        'payee_type': AppConstants.payeePlatform,
        'status': 'completed',
        'receipt_status': AppConstants.receiptApproved,
        'amount': amount,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else {
      final payment = PaymentModel(
        id: _uuid.v4(),
        bookingId: bookingId,
        userId: userId,
        amount: amount,
        status: 'completed',
        paymentMethod: AppConstants.paymentMethodWallet,
        payeeType: AppConstants.payeePlatform,
        receiptStatus: AppConstants.receiptApproved,
        createdAt: DateTime.now(),
      );
      await _supabase.from('payments').insert(payment.toPaymentMap());
    }

    // Booking already confirmed by RPC
  }

  /// Start split payment: debit wallet portion, leave remainder for bank transfer.
  Future<PaymentModel> startSplitPayment({
    required String bookingId,
    required String userId,
    required double totalAmount,
    required double walletAmount,
  }) async {
    final paymentId = await WalletService().debitForSplitPayment(
      bookingId: bookingId,
      walletAmount: walletAmount,
      totalAmount: totalAmount,
    );
    final payment = await getPaymentById(paymentId);
    if (payment == null) {
      throw Exception('Split payment could not be initialized');
    }
    return payment;
  }

  /// Stripe checkout for the external (non-wallet) portion of a split payment.
  Future<PaymentModel> createSplitExternalCardPayment({
    required String paymentId,
    required double externalAmount,
  }) async {
    final paymentIntent = await _createStripePaymentIntent(
      amount: _pkrToUsdCents(externalAmount),
      currency: 'usd',
    );
    final expiresAt = DateTime.now().add(const Duration(minutes: 30));

    return _requireUpdatedPayment(paymentId, {
      'payment_method': AppConstants.paymentMethodSplit,
      'status': 'pending',
      'stripe_payment_intent_id': paymentIntent['id'],
      'stripe_client_secret': paymentIntent['client_secret'],
      'receipt_status': null,
      'platform_account_id': null,
      'owner_account_id': null,
      'receipt_url': null,
      'transfer_reference': null,
      'failure_reason': null,
      'expires_at': expiresAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Bank / EasyPaisa for the external portion of a split payment.
  Future<PaymentModel> prepareSplitExternalManual({required String paymentId}) async {
    final existing = await getPaymentById(paymentId);
    if (existing == null) throw Exception('Payment not found');

    final keepReceipt =
        existing.receiptStatus == AppConstants.receiptAwaitingVerification ||
            existing.receiptStatus == AppConstants.receiptApproved;
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    return _requireUpdatedPayment(paymentId, {
      'payment_method': AppConstants.paymentMethodSplit,
      'status': 'pending',
      'stripe_payment_intent_id': null,
      'stripe_client_secret': null,
      'failure_reason': null,
      'receipt_status': keepReceipt
          ? existing.receiptStatus
          : AppConstants.receiptAwaitingUpload,
      if (!keepReceipt) 'platform_account_id': null,
      if (!keepReceipt) 'owner_account_id': null,
      if (!keepReceipt) 'receipt_url': null,
      if (!keepReceipt) 'transfer_reference': null,
      'expires_at': expiresAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Refund wallet portion when split payment is cancelled or expires.
  Future<void> refundSplitWalletPortion(String paymentId) async {
    await _supabase.rpc('refund_split_wallet_portion', params: {
      'p_payment_id': paymentId,
    });
  }

  /// Owner approves manual payment receipt → booking confirmed.
  Future<void> approveManualPayment(String paymentId) async {
    final payment = await getPaymentById(paymentId);
    if (payment == null) throw Exception('Payment not found');

    await _supabase.from('payments').update({
      'status': 'completed',
      'receipt_status': AppConstants.receiptApproved,
      'owner_verified_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', paymentId);

    await _confirmBookingAfterPayment(payment.bookingId);

    final booking = await BookingService().getBookingById(payment.bookingId);
    final groupIds = BookingService().parseGroupBookingIds(
      booking?.notes,
      payment.bookingId,
    );
    for (final id in groupIds) {
      if (id != payment.bookingId) {
        await _confirmBookingAfterPayment(id, sendNotification: false);
      }
    }
  }

  /// Owner rejects receipt — user can re-upload.
  Future<void> rejectManualPayment(String paymentId, {String? reason}) async {
    await _supabase.from('payments').update({
      'receipt_status': AppConstants.receiptRejected,
      'failure_reason': reason ?? 'Receipt rejected by owner',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', paymentId);

    final payment = await getPaymentById(paymentId);
    if (payment == null) return;

    try {
      final notificationService = NotificationService();
      await notificationService.createNotification(
        NotificationModel(
          id: _uuid.v4(),
          userId: payment.userId,
          title: 'Payment receipt rejected',
          message: reason ??
              'Your payment receipt was rejected. Please upload a valid receipt or pay by card.',
          type: 'payment_rejected',
          createdAt: DateTime.now(),
          metadata: {'booking_id': payment.bookingId, 'payment_id': paymentId},
        ),
      );
    } catch (_) {}
  }

  /// Booking ids for all workspaces owned by [ownerId].
  Future<List<String>> _ownerBookingIds(String ownerId) async {
    final workspaceRows = await _supabase
        .from('workspaces')
        .select('id')
        .eq('owner_id', ownerId);

    final workspaceIds =
        workspaceRows.map((w) => w['id'] as String).toList();
    if (workspaceIds.isEmpty) return [];

    final bookings = await _supabase
        .from('bookings')
        .select('id')
        .inFilter('workspace_id', workspaceIds);

    return bookings.map((b) => b['id'] as String).toList();
  }

  /// Pending manual payments awaiting owner verification.
  Future<List<PaymentModel>> getPendingReceiptsForOwner(String ownerId) async {
    final bookingIds = await _ownerBookingIds(ownerId);
    if (bookingIds.isEmpty) return [];

    final rows = await _supabase
        .from('payments')
        .select()
        .inFilter('booking_id', bookingIds)
        .eq('receipt_status', AppConstants.receiptAwaitingVerification)
        .order('created_at', ascending: false);

    return rows.map((r) => PaymentModel.fromPaymentMap(r)).toList();
  }

  /// All payments received by an owner across their workspaces (history).
  Future<List<PaymentModel>> getOwnerReceivedPayments(String ownerId) async {
    final bookingIds = await _ownerBookingIds(ownerId);
    if (bookingIds.isEmpty) return [];

    final rows = await _supabase
        .from('payments')
        .select()
        .inFilter('booking_id', bookingIds)
        .order('created_at', ascending: false);

    return rows.map((r) => PaymentModel.fromPaymentMap(r)).toList();
  }

  Future<void> _confirmBookingAfterPayment(
    String bookingId, {
    bool sendNotification = true,
  }) async {
    await _supabase.from('bookings').update({
      'status': 'confirmed',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);

    if (!sendNotification) return;

    try {
      final bookingData = await _supabase
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .limit(1);

      if (bookingData.isEmpty) return;
      final b = bookingData.first;
      final notificationService = NotificationService();

      await notificationService.sendBookingConfirmedNotification(
        userId: b['user_id'] ?? '',
        workspaceName: b['workspace_name'] ?? '',
        bookingId: bookingId,
      );
    } catch (_) {}
  }

  /// Create a payment for a booking
  /// Returns payment with Stripe client secret for payment processing
  Future<PaymentModel> createPayment({
    required String bookingId,
    required String userId,
    required double amount,
    String currency = 'PKR',
  }) async {
    try {
      // Stripe test/live accounts do not support PKR — charge USD equivalent.
      final paymentIntent = await _createStripePaymentIntent(
        amount: _pkrToUsdCents(amount),
        currency: 'usd',
      );

      // Create payment record in database
      final expiresAt = DateTime.now().add(const Duration(minutes: 30));

      // Reuse an existing (non-completed) payment row for this booking so we
      // never end up with duplicate rows when the user toggles methods.
      final existing = await getPaymentByBookingId(bookingId);
      if (existing != null && existing.status != 'completed') {
        return _requireUpdatedPayment(existing.id, {
          'payment_method': AppConstants.paymentMethodStripe,
          'status': 'pending',
          'stripe_payment_intent_id': paymentIntent['id'],
          'stripe_client_secret': paymentIntent['client_secret'],
          'receipt_status': null,
          'owner_account_id': null,
          'receipt_url': null,
          'transfer_reference': null,
          'failure_reason': null,
          'expires_at': expiresAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      final payment = PaymentModel(
        id: _uuid.v4(),
        bookingId: bookingId,
        userId: userId,
        amount: amount,
        currency: currency,
        status: 'pending',
        paymentMethod: 'stripe',
        stripePaymentIntentId: paymentIntent['id'],
        stripeClientSecret: paymentIntent['client_secret'],
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
      );

      final paymentData = payment.toPaymentMap();
      paymentData.removeWhere((key, value) => value == null);

      await _supabase
          .from('payments')
          .insert(paymentData);

      return payment;
    } catch (e) {
      throw Exception('Failed to create payment: ${e.toString()}');
    }
  }

  /// Create a Stripe payment intent for wallet top-up (no booking needed).
  static Future<Map<String, dynamic>> createStripeTopUpIntent(int amountCents) async {
    try {
      final response = await http.post(
        Uri.parse('$stripeApiUrl/payment_intents'),
        headers: {
          'Authorization': 'Bearer $stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amountCents.toString(),
          'currency': 'usd',
          'payment_method_types[]': 'card',
          'metadata[source]': 'cwc_wallet_topup',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Stripe API error (${response.statusCode})');
    } catch (e) {
      if (e is Exception && e.toString().contains('Stripe')) rethrow;
      throw Exception('Card payment is unavailable right now. Please use bank transfer.');
    }
  }

  /// Create Stripe Payment Intent
  Future<Map<String, dynamic>> _createStripePaymentIntent({
    required int amount,
    required String currency,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$stripeApiUrl/payment_intents'),
        headers: {
          'Authorization': 'Bearer $stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amount.toString(),
          'currency': currency,
          'payment_method_types[]': 'card',
          'metadata[source]': 'cwc_app',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      final body = response.body;
      try {
        final err = json.decode(body) as Map<String, dynamic>;
        final msg = err['error']?['message'] ?? body;
        throw Exception('Stripe: $msg');
      } catch (_) {
        throw Exception('Stripe API error (${response.statusCode})');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Stripe')) rethrow;
      throw Exception(
        'Card payment is unavailable right now. Please use bank transfer.',
      );
    }
  }

  /// Confirm payment (after Stripe payment is successful)
  Future<void> confirmPayment(
    String paymentId,
    String stripePaymentIntentId, {
    bool isDummyPayment = false,
    String? bookingId,
    List<String> additionalBookingIds = const [],
  }) async {
    try {
      String status = 'completed';
      String? failureReason;

      if (isDummyPayment) {
        status = 'completed';
      } else {
        final paymentIntent = await _getStripePaymentIntent(stripePaymentIntentId);

        if (paymentIntent['status'] == 'succeeded') {
          status = 'completed';
        } else if (paymentIntent['status'] == 'requires_payment_method') {
          status = 'failed';
          failureReason = 'Payment method required';
        } else if (paymentIntent['status'] == 'canceled') {
          status = 'cancelled';
          failureReason = 'Payment cancelled';
        } else {
          status = 'failed';
          failureReason = paymentIntent['last_payment_error']?['message'] ?? 'Payment failed';
        }
      }

      final payment = await getPaymentById(paymentId);
      final resolvedBookingId = payment?.bookingId ?? bookingId;

      // Update payment record in database
      await _supabase
          .from('payments')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
            if (failureReason != null) 'failure_reason': failureReason,
          })
          .eq('id', paymentId);

      // Update booking status if payment successful
      if (status == 'completed' && resolvedBookingId != null) {
        await _confirmBookingAfterPayment(resolvedBookingId);
        for (final extraId in additionalBookingIds) {
          if (extraId != resolvedBookingId) {
            await _confirmBookingAfterPayment(extraId, sendNotification: false);
          }
        }

        // Notify workspace owner (user notification sent in _confirmBookingAfterPayment)
        try {
          final bookingData = await _supabase
              .from('bookings')
              .select()
              .eq('id', resolvedBookingId)
              .limit(1);

          if (bookingData.isNotEmpty) {
            final b = bookingData.first;
            final userId = b['user_id'] ?? '';
            final workspaceName = b['workspace_name'] ?? '';
            final workspaceId = b['workspace_id'] ?? '';
            final notificationService = NotificationService();

            final wsData = await _supabase
                .from('workspaces')
                .select('owner_id')
                .eq('id', workspaceId)
                .limit(1);

            if (wsData.isNotEmpty) {
              final ownerId = wsData.first['owner_id'] ?? '';
              if (ownerId.isNotEmpty && ownerId != userId) {
                final userData = await _supabase
                    .from('users')
                    .select('name')
                    .eq('id', userId)
                    .limit(1);
                final userName = userData.isNotEmpty ? (userData.first['name'] ?? 'A user') : 'A user';

                await notificationService.sendBookingCreatedNotification(
                  ownerUserId: ownerId,
                  userName: userName,
                  workspaceName: workspaceName,
                  bookingId: resolvedBookingId,
                );
              }
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      throw Exception('Failed to confirm payment: ${e.toString()}');
    }
  }

  /// Get Stripe Payment Intent
  Future<Map<String, dynamic>> _getStripePaymentIntent(String paymentIntentId) async {
    try {
      final response = await http.get(
        Uri.parse('$stripeApiUrl/payment_intents/$paymentIntentId'),
        headers: {
          'Authorization': 'Bearer $stripeSecretKey',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Stripe API error: ${response.body}');
    } catch (e) {
      throw Exception('Could not verify card payment with Stripe.');
    }
  }

  /// Get payment by ID
  Future<PaymentModel?> getPaymentById(String paymentId) async {
    try {
      final results = await _supabase
          .from('payments')
          .select()
          .eq('id', paymentId)
          .limit(1);

      if (results.isEmpty) return null;
      return PaymentModel.fromPaymentMap(results.first);
    } catch (e) {
      return null;
    }
  }

  /// Get payment by booking ID (returns latest payment for this booking)
  Future<PaymentModel?> getPaymentByBookingId(String bookingId) async {
    try {
      final results = await _supabase
          .from('payments')
          .select()
          .eq('booking_id', bookingId)
          .order('created_at', ascending: false)
          .limit(1);

      if (results.isEmpty) return null;
      return PaymentModel.fromPaymentMap(results.first);
    } catch (e) {
      return null;
    }
  }

  /// Cancel/Expire payment
  Future<void> cancelPayment(String paymentId, {String? reason}) async {
    try {
      await _supabase
          .from('payments')
          .update({
            'status': 'expired',
            'updated_at': DateTime.now().toIso8601String(),
            if (reason != null) 'failure_reason': reason,
          })
          .eq('id', paymentId);

      // Cancel booking if payment expired
      final payment = await getPaymentById(paymentId);
      if (payment != null) {
        if (payment.isSplit && payment.walletAmount > 0) {
          try {
            await refundSplitWalletPortion(paymentId);
          } catch (_) {}
        }
        await _supabase
            .from('bookings')
            .update({
              'status': 'cancelled',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', payment.bookingId);
      }
    } catch (e) {
      throw Exception('Failed to cancel payment: ${e.toString()}');
    }
  }

  /// Check and expire payments that have passed 30 minutes
  Future<void> checkAndExpirePayments() async {
    try {
      final now = DateTime.now();
      final expiredPayments = await _supabase
          .from('payments')
          .select()
          .eq('status', 'pending')
          .lt('expires_at', now.toIso8601String());

      for (var paymentData in expiredPayments) {
        final payment = PaymentModel.fromPaymentMap(paymentData);
        await cancelPayment(payment.id, reason: 'Payment expired - 30 minutes passed');
      }
    } catch (e) {
      // Ignore errors in background check
    }
  }

  /// Get user payments
  Future<List<PaymentModel>> getUserPayments(String userId) async {
    try {
      final rows = await _supabase
          .from('payments')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return rows.map((r) => PaymentModel.fromPaymentMap(r)).toList();
    } catch (e) {
      throw Exception('Failed to fetch payments: ${e.toString()}');
    }
  }
}
