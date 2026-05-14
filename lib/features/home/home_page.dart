import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../card/domain/entities/card_details.dart';
import '../bank/domain/entities/bank_details.dart';
import '../card/presentation/pages/card_scanner_page.dart';
import '../bank/presentation/pages/bank_scanner_page.dart';
import '../../shared/widgets/result_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CardDetails? _lastCard;
  BankDetails? _lastBank;

  // ── Navigation ──────────────────────────────────────────────────────────────

  Future<void> _openCardScanner() async {
    final result = await Navigator.push<CardDetails>(
      context,
      MaterialPageRoute(builder: (_) => const CardScannerPage()),
    );
    if (result != null && mounted) setState(() => _lastCard = result);
  }

  Future<void> _openBankScanner({bool gallery = false}) async {
    final result = await Navigator.push<BankDetails>(
      context,
      MaterialPageRoute(
        builder: (_) => BankScannerPage(startWithGallery: gallery),
      ),
    );
    if (result != null && mounted) setState(() => _lastBank = result);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildSectionLabel('Choose Scanner'),
                  const SizedBox(height: 16),
                  _buildScannerCards(),
                  const SizedBox(height: 36),
                  if (_lastCard != null || _lastBank != null) ...[
                    _buildSectionLabel('Last Scanned'),
                    const SizedBox(height: 16),
                    if (_lastCard != null) _buildCardResult(),
                    if (_lastBank != null) _buildBankResult(),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Background ──────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    return Stack(
      children: [
        Container(decoration: const BoxDecoration(gradient: AppTheme.bgGradient)),
        Positioned(
          top: -80, right: -80,
          child: _blob(300, AppTheme.primary.withOpacity(0.10)),
        ),
        Positioned(
          bottom: -100, left: -80,
          child: _blob(350, AppTheme.secondary.withOpacity(0.07)),
        ),
      ],
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _gradientIcon(Icons.document_scanner_rounded, 28),
          const SizedBox(width: 12),
          Text('SmartScan',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
        ]),
        const SizedBox(height: 24),
        Text('Scan & Extract\nInstantly',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -1)),
        const SizedBox(height: 12),
        Text('Scan your card or bank passbook — OCR-powered,\nno data leaves your device.',
            style: GoogleFonts.inter(
                color: AppTheme.textSecondary, fontSize: 14, height: 1.6)),
      ],
    );
  }

  Widget _gradientIcon(IconData icon, double size) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }

  // ── Section label ───────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Text(text,
        style: GoogleFonts.inter(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4));
  }

  // ── Scanner choice cards ────────────────────────────────────────────────────

  Widget _buildScannerCards() {
    return Column(children: [
      _ScannerOptionCard(
        icon: Icons.credit_card_rounded,
        title: 'Credit / Debit Card',
        subtitle: 'Extract card number, expiry date\nand cardholder name',
        gradient: const LinearGradient(
          colors: [Color(0xFF4A2C8C), Color(0xFF6C63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentColor: AppTheme.primary,
        actions: [
          _ActionChip(
            icon: Icons.camera_alt_rounded,
            label: 'Scan Card',
            onTap: _openCardScanner,
          ),
        ],
      ),
      const SizedBox(height: 16),
      _ScannerOptionCard(
        icon: Icons.account_balance_rounded,
        title: 'Bank Passbook',
        subtitle: 'Extract account number, IFSC\nand account holder name',
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentColor: const Color(0xFF2563EB),
        actions: [
          _ActionChip(
            icon: Icons.camera_alt_rounded,
            label: 'Scan',
            onTap: () => _openBankScanner(gallery: false),
          ),
          _ActionChip(
            icon: Icons.photo_library_rounded,
            label: 'Upload',
            onTap: () => _openBankScanner(gallery: true),
          ),
        ],
      ),
    ]);
  }

  // ── Last scanned results ────────────────────────────────────────────────────

  Widget _buildCardResult() {
    final c = _lastCard!;
    return _ResultSection(
      icon: Icons.credit_card_rounded,
      accentColor: AppTheme.primary,
      title: 'Card',
      onRescan: _openCardScanner,
      tiles: [
        ResultTile(label: 'Card Number', value: c.maskedCardNumber, icon: Icons.credit_card),
        if (c.expiryDate != null)
          ResultTile(label: 'Expiry', value: c.expiryDate!, icon: Icons.date_range),
        if (c.cardHolderName != null)
          ResultTile(label: 'Holder', value: c.cardHolderName!, icon: Icons.person),
      ],
    );
  }

  Widget _buildBankResult() {
    final b = _lastBank!;
    return _ResultSection(
      icon: Icons.account_balance_rounded,
      accentColor: const Color(0xFF2563EB),
      title: 'Passbook',
      onRescan: () => _openBankScanner(),
      tiles: [
        if (b.accountHolderName != null)
          ResultTile(label: 'Holder', value: b.accountHolderName!, icon: Icons.person),
        if (b.accountNumber != null)
          ResultTile(label: 'Account No.', value: b.maskedAccountNumber, icon: Icons.account_balance_wallet),
        if (b.ifscCode != null)
          ResultTile(label: 'IFSC', value: b.ifscCode!, icon: Icons.code),
        if (b.bankName != null)
          ResultTile(label: 'Bank', value: b.bankName!, icon: Icons.account_balance),
      ],
    );
  }
}

// ── Scanner Option Card ─────────────────────────────────────────────────────

class _ScannerOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final Color accentColor;
  final List<_ActionChip> actions;

  const _ScannerOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.accentColor,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(children: [
        Positioned(
          top: -30, right: -20,
          child: Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      color: Colors.white70, fontSize: 13, height: 1.5)),
              const SizedBox(height: 18),
              Row(
                children: actions
                    .map((a) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: a,
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Action Chip ─────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Result Section ──────────────────────────────────────────────────────────

class _ResultSection extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final VoidCallback onRescan;
  final List<ResultTile> tiles;

  const _ResultSection({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.onRescan,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(icon, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ]),
              GestureDetector(
                onTap: onRescan,
                child: Text('Rescan',
                    style: GoogleFonts.inter(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...tiles,
        ],
      ),
    );
  }
}
