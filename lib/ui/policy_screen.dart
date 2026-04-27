import 'package:flutter/material.dart';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  static const Color _electricBlue = Color(0xFF009BFF);
  static const Color _cardBorder = Color(0xFFD8ECFF);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _cardBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Policy',
                style: TextStyle(
                  color: _electricBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12),
              Text('This app monitors incoming transaction SMS only with your permission.'),
              SizedBox(height: 8),
              Text('It forwards parsed bKash transaction details to the API endpoint you configure.'),
              SizedBox(height: 8),
              Text('Keep your endpoint private and review your backend logging policy before production use.'),
              SizedBox(height: 8),
              Text('Raw SMS content is sensitive and should be handled carefully on device and server.'),
            ],
          ),
        ),
      ],
    );
  }
}
