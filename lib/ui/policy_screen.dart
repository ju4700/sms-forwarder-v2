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
              Text(
                'This app monitors incoming transaction SMS only with your permission.',
              ),
              SizedBox(height: 8),
              Text(
                'It forwards incoming bKash credit receipts to your configured HTTPS server using signed requests.',
              ),
              SizedBox(height: 8),
              Text(
                'Only bKash / 16247 receipt messages enter the encrypted queue. Credentials are protected with Android Keystore. No external portal is used.',
              ),
              SizedBox(height: 8),
              Text(
                'Matching receipt text is sent to your server. Completed history retains up to 100 receipts for seven days; unresolved receipts remain until delivery or explicit manual handling. Recent payment inbox recovery is explicit.',
              ),
              SizedBox(height: 8),
              Text(
                'SMS is evidence from your phone. Sender names are not cryptographic proof of a wallet transaction. Keep manual review and wallet reconciliation available.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
