import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:maps/util/app_colors.dart';

class NoInternetWidget extends StatelessWidget {
  const NoInternetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 100, color: Colors.grey),
           SizedBox(height: 16.h),
           Text(
            "Internet not connected",
            style: TextStyle(fontSize: 18.sp, color: AppColors.primaryGrey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
  }
}
