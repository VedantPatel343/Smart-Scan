import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/bank_details.dart';

class BankDetailsCard extends StatelessWidget {
  final BankDetails details;
  const BankDetailsCard({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0F2040), Color(0xFF0A1628)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Stack(children: [
        Positioned(top: -30, right: -20,
          child: Container(width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accent.withOpacity(0.08)))),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(details.bankName ?? 'Bank Document',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, letterSpacing: 0.6),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              _chip(),
            ]),
            const SizedBox(height: 20),
            _label('Account Holder'),
            const SizedBox(height: 4),
            Text(details.accountHolderName ?? '— Not Detected —',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _label('Account Number'),
            const SizedBox(height: 4),
            Text(details.accountNumber != null ? details.maskedAccountNumber : '— Not Detected —',
                style: GoogleFonts.sourceCodePro(
                    color: details.accountNumber != null ? Colors.white : Colors.white38,
                    fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2)),
            const SizedBox(height: 16),
            _label('IFSC Code'),
            const SizedBox(height: 4),
            Text(details.ifscCode ?? '— Not Detected —',
                style: GoogleFonts.sourceCodePro(
                    color: details.ifscCode != null ? AppTheme.secondary : Colors.white38,
                    fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          ]),
        ),
      ]),
    );
  }

  Widget _label(String t) => Text(t.toUpperCase(),
      style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2));

  Widget _chip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.accent.withOpacity(0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.accent.withOpacity(0.4), width: 0.8),
    ),
    child: Text('PASSBOOK',
        style: GoogleFonts.inter(color: const Color(0xFF60A5FA), fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 1.0)),
  );
}
