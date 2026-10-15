import 'package:beacon_os/fire_tv/view/tv_shell_view.dart';
import 'package:flutter/material.dart';

class TvShellPage extends StatelessWidget {
  const TvShellPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const TvShellPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const TvShellView();
  }
}