import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/shimmer/text_shimmer.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

class ProfileLoading extends StatelessWidget {
  const ProfileLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Get.theme.cardColor,
      period: const Duration(milliseconds: 2000),
      highlightColor: Colors.grey.withOpacity(0.6),
      child: const Row(
        children: [
          CircleAvatar(radius: 24,),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextShimmer(),
              SizedBox(height: 8),
              TextShimmer(width: 160,),
            ],
          ),
        ],
      )
    );
  }
}
