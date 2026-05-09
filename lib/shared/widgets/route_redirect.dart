import 'package:flutter/material.dart';

class RouteRedirect extends StatefulWidget {
  const RouteRedirect({super.key, required this.routeName});

  final String routeName;

  @override
  State<RouteRedirect> createState() => _RouteRedirectState();
}

class _RouteRedirectState extends State<RouteRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.pushReplacementNamed(context, widget.routeName);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
