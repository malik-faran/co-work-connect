import 'package:flutter/material.dart';
import 'package:cwc/models/user_model.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/views/screens/owner/owner_home_screen.dart';
import 'package:cwc/views/screens/owner/owner_pending_approval_screen.dart';

Widget ownerDestinationFor(UserModel user) {
  if (user.role != AppConstants.roleOwner) {
    throw ArgumentError('Expected owner role');
  }
  if (user.ownerApproved != true) {
    return OwnerPendingApprovalScreen(rejected: user.ownerApproved == false);
  }
  return const OwnerHomeScreen();
}
