import 'package:flutter/material.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';

class UserProfile extends StatelessWidget {
  const UserProfile({super.key, required this.data});

  final MoodleProfileEntity data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(backgroundImage: NetworkImage(data.userpictureurl), radius: 24,),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.firstname,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.username.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
