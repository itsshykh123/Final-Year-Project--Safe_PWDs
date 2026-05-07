import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_page.dart';

// ─── Color Tokens ─────────────────────────────────────────────────
class _C {
  static const pageBg = Color(0xFFF0F2F5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E5EC);
  static const divider = Color(0xFFF0F2F5);

  static const text = Color(0xFF1A1D23);
  static const text2 = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9EA5B5);

  static const greenBg = Color(0xFFEAF3DE);
  static const greenBorder = Color(0xFFC0DD97);
  static const green = Color(0xFF3B6D11);
  static const greenDark = Color(0xFF27500A);
  static const greenMid = Color(0xFF639922);

  static const blueBg = Color(0xFFEEF4FF);
  static const blueBorder = Color(0xFFBDD1F8);
  static const blue = Color(0xFF378ADD);

  static const redBg = Color(0xFFFFF5F5);
  static const redBorder = Color(0xFFFECACA);
  static const red = Color(0xFFE24B4A);
  static const redDark = Color(0xFFA32D2D);
}

// ─── ProfilePage ──────────────────────────────────────────────────
class ProfilePage extends StatefulWidget {
  final String userEmail;
  const ProfilePage({super.key, required this.userEmail});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _firestore = FirebaseFirestore.instance;

  String? sessionEmail;
  bool isEditingName = false;
  bool isEditingDisability = false;

  final _nameCtrl = TextEditingController();
  String disability = 'blind';
  late String docId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      sessionEmail = prefs.getString('userEmail') ?? widget.userEmail;
    });
    if (sessionEmail != null && sessionEmail!.isNotEmpty) {
      await _loadFirestore(sessionEmail!);
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadFirestore(String email) async {
    try {
      final q = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      if (q.docs.isNotEmpty) {
        final doc = q.docs.first;
        docId = doc.id;
        final d = doc.data();
        setState(() {
          _nameCtrl.text = d.containsKey('Name') ? doc.get('Name') : 'User';
          disability = d.containsKey('disability')
              ? doc.get('disability')
              : 'blind';
        });
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    await _firestore.collection('users').doc(docId).update({'Name': name});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    setState(() => isEditingName = false);
    _snack('Name updated');
  }

  Future<void> _updateDisability(String val) async {
    await _firestore.collection('users').doc(docId).update({'disability': val});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userMode', val);
    setState(() {
      disability = val;
      isEditingDisability = false;
    });
    _snack('Mode set to ${val.toUpperCase()}');
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: _C.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: _C.pageBg,
        body: Center(child: CircularProgressIndicator(color: _C.green)),
      );
    }
    return Scaffold(
      backgroundColor: _C.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                )
              ),
              const SizedBox(height: 16),

              // ── Hero card ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _C.border),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    children: [
                      // Green banner
                      Container(
                        width: double.infinity,
                        color: _C.greenBg,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 38),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACTIVE ACCOUNT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _C.green,
                                letterSpacing: 0.07,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'All systems accessible',
                              style: TextStyle(
                                fontSize: 12,
                                color: _C.greenMid,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Avatar bump + name
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Avatar overlapping the banner
                            Transform.translate(
                              offset: const Offset(0, -28),
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _C.surface,
                                  border: Border.all(
                                    color: _C.surface,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _C.greenBorder.withOpacity(0.6),
                                      blurRadius: 0,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const CircleAvatar(
                                  backgroundColor: _C.greenBg,
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 36,
                                    color: _C.green,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: isEditingName
                                    ? Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _nameCtrl,
                                              autofocus: true,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                                color: _C.text,
                                              ),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: const BorderSide(
                                                    color: _C.border,
                                                  ),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: _C.green,
                                                          ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: _updateName,
                                            child: Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: _C.greenBg,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _C.greenBorder,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.check_rounded,
                                                color: _C.green,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _nameCtrl.text,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                                color: _C.text,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => isEditingName = true,
                                            ),
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: _C.pageBg,
                                                borderRadius:
                                                    BorderRadius.circular(7),
                                                border: Border.all(
                                                  color: _C.border,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.edit_rounded,
                                                color: _C.text2,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Email row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.mail_outline_rounded,
                              size: 14,
                              color: _C.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sessionEmail ?? 'No email',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _C.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats strip
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: _C.divider)),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              _statCell(
                                disability.toUpperCase(),
                                'Access mode',
                              ),
                              Container(width: 1, color: _C.divider),
                              _statCell('Active', 'Status'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Preferences section ──────────────────────────────
              _sectionLabel('Preferences'),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MenuCard(
                  children: [
                    _MenuRow(
                      iconBg: _C.blueBg,
                      iconBorder: _C.blueBorder,
                      icon: Icons.accessibility_new_rounded,
                      iconColor: _C.blue,
                      label: 'Accessibility mode',
                      subtitle: 'Assistive output preference',
                      trailing: isEditingDisability
                          ? _DisabilityDropdown(
                              value: disability,
                              onChanged: _updateDisability,
                            )
                          : GestureDetector(
                              onTap: () =>
                                  setState(() => isEditingDisability = true),
                              child: _pill(
                                disability.toUpperCase(),
                                _C.greenBg,
                                _C.greenBorder,
                                _C.greenDark,
                              ),
                            ),
                    ),
                    _MenuRow(
                      iconBg: const Color(0xFFF5F6F8),
                      iconBorder: _C.border,
                      icon: Icons.notifications_none_rounded,
                      iconColor: _C.text2,
                      label: 'Notifications',
                      subtitle: 'Alerts & reminders',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _C.border,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Account section ──────────────────────────────────
              _sectionLabel('Account'),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MenuCard(
                  children: [
                    _MenuRow(
                      iconBg: const Color(0xFFF5F6F8),
                      iconBorder: _C.border,
                      icon: Icons.mail_outline_rounded,
                      iconColor: _C.text2,
                      label: 'Email address',
                      subtitle: sessionEmail ?? 'N/A',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _C.border,
                        size: 20,
                      ),
                    ),
                    _MenuRow(
                      iconBg: const Color(0xFFF5F6F8),
                      iconBorder: _C.border,
                      icon: Icons.info_outline_rounded,
                      iconColor: _C.text2,
                      label: 'App version',
                      subtitle: '1.0.0 · FYP Build',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _C.border,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Logout ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _LogoutButton(onTap: _logout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 20),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _C.textMuted,
        letterSpacing: 0.07,
      ),
    ),
  );

  Widget _statCell(String value, String label) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _C.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: _C.textMuted),
          ),
        ],
      ),
    ),
  );

  static Widget _pill(String text, Color bg, Color border, Color textColor) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      );
}

// ─── Menu Card ────────────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              if (i > 0) const Divider(height: 1, color: _C.divider),
              children[i],
            ],
          );
        }),
      ),
    );
  }
}

// ─── Menu Row ─────────────────────────────────────────────────────
class _MenuRow extends StatelessWidget {
  final Color iconBg, iconBorder, iconColor;
  final IconData icon;
  final String label, subtitle;
  final Widget trailing;

  const _MenuRow({
    required this.iconBg,
    required this.iconBorder,
    required this.iconColor,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iconBorder),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _C.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: _C.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

// ─── Disability Dropdown ──────────────────────────────────────────
class _DisabilityDropdown extends StatelessWidget {
  final String value;
  final Function(String) onChanged;
  const _DisabilityDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const opts = ['blind', 'deaf', 'both'];
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: opts.contains(value) ? value : opts.first,
        isDense: true,
        borderRadius: BorderRadius.circular(10),
        items: opts
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(
                  e.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

// ─── Logout Button ────────────────────────────────────────────────
class _LogoutButton extends StatefulWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFFFEE2E2) : _C.redBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.redBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFFECACA),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _C.red,
                  size: 14,
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _C.redDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
