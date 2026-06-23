import 'dart:convert';
import 'package:cwc/models/notification_model.dart';
import 'package:cwc/models/payment_model.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:cwc/services/supabase_service.dart';
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
      await _supabase.from('payments').update({
        'payment_method': AppConstants.paymentMethodManual,
        'status': 'pending',
        'receipt_status': keepReceipt
            ? existing.receiptStatus
            : AppConstants.receiptAwaitingUpload,
        'stripe_payment_intent_id': null,
        'stripe_client_secret': null,
        'expires_at': expiresAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existing.id);
      return (await getPaymentById(existing.id)) ?? existing;
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
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
    );

    final paymentData = payment.toPaymentMap()
      ..removeWhere((key, value) => value == null);

    await _supabase.from('payments').insert(paymentData);
    return payment;
  }

  /// User submits receipt after bank/easypaisa transfer.
  Future<void> submitManualReceipt({
    required String paymentId,
    required String ownerAccountId,
    required String receiptUrl,
    String? transferReference,
  }) async {
    await _supabase.from('payments').update({
      'payment_method': AppConstants.paymentMethodManual,
      'status': 'pending',
      'owner_account_id': ownerAccountId,
      'receipt_url': receiptUrl,
      'receipt_status': AppConstants.receiptAwaitingVerification,
      'transfer_reference': transferReference,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', paymentId);

    final payment = await getPaymentById(paymentId);
    if (payment == null) return;

    try {
      final bookingData = await _supabase
          .from('bookings')
          .select('workspace_id, workspace_name, user_id')
          .eq('id', payment.bookingId)
          .maybeSingle();

      if (bookingData == null) return;

      final ws = await _supabase
          .from('workspaces')
          .select('owner_id')
          .eq('id', bookingData['workspace_id'])
          .maybeSingle();

      if (ws == null) return;
      final ownerId = ws['owner_id'] as String;

      final userData = await _supabase
          .from('users')
          .select('name')
          .eq('id', payment.userId)
          .maybeSingle();

      final notificationService = NotificationService();
      await notificationService.createNotification(
        NotificationModel(
          id: _uuid.v4(),
          userId: ownerId,
          title: 'Payment receipt uploaded',
          message:
              '${userData?['name'] ?? 'A user'} sent a payment receipt for ${bookingData['workspace_name']}. Please verify.',
          type: 'payment_receipt',
          createdAt: DateTime.now(),
          metadata: {
            'booking_id': payment.bookingId,
            'payment_id': paymentId,
          },
        ),
      );
    } catch (_) {}
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

  Future<void> _confirmBookingAfterPayment(String bookingId) async {
    await _supabase.from('bookings').update({
      'status': 'confirmed',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);

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
      // Create Stripe Payment Intent
      final paymentIntent = await _createStripePaymentIntent(
        amount: (amount * 100).toInt(), // Convert to cents/paisa
        currency: currency.toLowerCase(),
      );

      // Create payment record in database
      final expiresAt = DateTime.now().add(const Duration(minutes: 30));

      // Reuse an existing (non-completed) payment row for this booking so we
      // never end up with duplicate rows when the user toggles methods.
      final existing = await getPaymentByBookingId(bookingId);
      if (existing != null && existing.status != 'completed') {
        await _supabase.from('payments').update({
          'payment_method': AppConstants.paymentMethodStripe,
          'status': 'pending',
          'stripe_payment_intent_id': paymentIntent['id'],
          'stripe_client_secret': paymentIntent['client_secret'],
          'receipt_status': null,
          'owner_account_id': null,
          'receipt_url': null,
          'expires_at': expiresAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existing.id);
        return (await getPaymentById(existing.id)) ??
            existing.copyPayment(
              paymentMethod: AppConstants.paymentMethodStripe,
              stripePaymentIntentId: paymentIntent['id'],
              stripeClientSecret: paymentIntent['client_secret'],
              expiresAt: expiresAt,
            );
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
        return json.decode(response.body);
      } else {
        throw Exception('Stripe API error: ${response.body}');
      }
    } catch (e) {
      // For demo/testing purposes, return a mock payment intent
      // In production, remove this and handle errors properly
      return {
        'id': 'pi_test_${_uuid.v4()}',
        'client_secret': 'pi_test_${_uuid.v4()}_secret_${_uuid.v4()}',
        'status': 'requires_payment_method',
      };
    }
  }

  /// Confirm payment (after Stripe payment is successful)
  Future<void> confirmPayment(
    String paymentId,
    String stripePaymentIntentId, {
    bool isDummyPayment = false,
    String? bookingId,
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
      try {
        await _supabase
            .from('payments')
            .update({
              'status': status,
              'updated_at': DateTime.now().toIso8601String(),
              if (failureReason != null) 'failure_reason': failureReason,
            })
            .eq('id', paymentId);
      } catch (_) {}

      // Update booking status if payment successful
      if (status == 'completed' && resolvedBookingId != null) {
        await _supabase
            .from('bookings')
            .update({
              'status': 'confirmed',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', resolvedBookingId);

        // Send booking confirmed notification to user and owner
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

            await notificationService.sendBookingConfirmedNotification(
              userId: userId,
              workspaceName: workspaceName,
              bookingId: resolvedBookingId,
            );

            // Also notify the workspace owner
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
      } else {
        throw Exception('Stripe API error: ${response.body}');
      }
    } catch (e) {
      // For demo/testing purposes, return mock data
      return {
        'id': paymentIntentId,
        'status': 'succeeded',
      };
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
