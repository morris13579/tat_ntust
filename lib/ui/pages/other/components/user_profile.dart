import 'package:flutter/material.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:get/get.dart';

class UserProfile extends StatelessWidget {
  const UserProfile({super.key, required this.data});

  final MoodleProfileEntity data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(data.userpictureurl),
          radius: 24,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.firstname,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Get.theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              data.username.toUpperCase(),
              style: TextStyle(
                  fontSize: 16, color: Get.theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}
