import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:photo_view/photo_view.dart' as PhView;

class PhotoView extends StatelessWidget {
  const PhotoView({super.key, required this.imageData});

  final Uint8List imageData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: baseAppbar(),
        body: PhView.PhotoView(imageProvider: MemoryImage(imageData)));
  }
}
