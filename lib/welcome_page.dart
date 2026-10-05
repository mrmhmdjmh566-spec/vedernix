import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _heroController;
  late final AnimationController _floatController;

  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: Curves.easeOutCubic,
      ),
    );

    _heroController.forward();
    _floatController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _heroController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _openUserLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(
          userType: 'user',
        ),
      ),
    );
  }

  void _openAdvertiserLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(
          userType: 'advertiser',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                if (width < 700) {
                  return _buildMobileLayout();
                }

                return _buildDesktopLayout();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 720,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 20,
          ),
          child: Column(
            children: [
              _buildDesktopHeader(),
              const SizedBox(height: 50),
              _buildHero(),
              const SizedBox(height: 55),
              _buildStats(),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        child: Column(
          children: [
            _buildMobileHeader(),
            const SizedBox(height: 55),
            _buildHero(),
            const SizedBox(height: 50),
            _buildStats(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        const _VedernixLogo(),
        const SizedBox(width: 12),
        const Text(
          'Vedernix',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        _NavItem(
          title: 'Benefits',
          onTap: () {},
        ),
        _NavItem(
          title: 'How It Works',
          onTap: () {},
        ),
        _NavItem(
          title: 'FAQs',
          onTap: () {},
        ),
        _NavItem(
          title: 'About',
          onTap: () {},
        ),
        const SizedBox(width: 16),
        _HeaderButton(
          title: 'Start',
          onTap: _openUserLogin,
        ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Row(
      children: [
        const _VedernixLogo(),
        const SizedBox(width: 10),
        const Text(
          'Vedernix',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _HeaderButton(
          title: 'Start',
          onTap: _openUserLogin,
          compact: true,
        ),
        const SizedBox(width: 8),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          child: const Icon(
            Icons.menu_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            _buildBadge(),
            const SizedBox(height: 28),
            const Text(
              'Complete tasks.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 64,
                height: 0.98,
                fontWeight: FontWeight.w800,
                letterSpacing: -3.0,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Earn more. Work smarter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFF7A18),
                fontSize: 64,
                height: 1.0,
                fontWeight: FontWeight.w800,
                letterSpacing: -3.0,
              ),
            ),
            const SizedBox(height: 26),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 690,
              ),
              child: Text(
                'Vedernix connects you with simple operational tasks, '
                'clear instructions, and trusted platforms — all in one place.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.60),
                  fontSize: 17,
                  height: 1.65,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 34),
            _buildHeroButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A18).withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF7A18),
            ),
          ),
          const SizedBox(width: 9),
          const Text(
            'Operational Task Infrastructure',
            style: TextStyle(
              color: Color(0xFFD8D8D8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroButtons() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        _PrimaryButton(
          title: 'Start as User',
          icon: Icons.arrow_forward_rounded,
          onTap: _openUserLogin,
        ),
        _SecondaryButton(
          title: 'Start as Advertiser',
          icon: Icons.business_center_outlined,
          onTap: _openAdvertiserLogin,
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 900,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 24,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return const Column(
              children: [
                _StatItem(
                  value: '01',
                  label: 'Thousands of tasks completed',
                ),
                SizedBox(height: 22),
                _StatDivider(
                  vertical: false,
                ),
                SizedBox(height: 22),
                _StatItem(
                  value: '02',
                  label: 'Simple, guided execution',
                ),
                SizedBox(height: 22),
                _StatDivider(
                  vertical: false,
                ),
                SizedBox(height: 22),
                _StatItem(
                  value: '03',
                  label: 'Built for operational teams',
                ),
              ],
            );
          }

          return const Row(
            children: [
              Expanded(
                child: _StatItem(
                  value: '01',
                  label: 'Thousands of tasks completed',
                ),
              ),
              _StatDivider(
                vertical: true,
              ),
              Expanded(
                child: _StatItem(
                  value: '02',
                  label: 'Simple, guided execution',
                ),
              ),
              _StatDivider(
                vertical: true,
              ),
              Expanded(
                child: _StatItem(
                  value: '03',
                  label: 'Built for operational teams',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -180,
            left: -120,
            child: _GlowCircle(
              size: 420,
              color: const Color(0xFFFF7A18).withOpacity(0.10),
            ),
          ),
          Positioned(
            top: 180,
            right: -220,
            child: _GlowCircle(
              size: 500,
              color: const Color(0xFFFF3D00).withOpacity(0.06),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.15,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.75),
                  ],
                  stops: const [
                    0.0,
                    0.60,
                    1.0,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: 80,
        sigmaY: 80,
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class _VedernixLogo extends StatelessWidget {
  const _VedernixLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.55,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: const Color(0xFFFF7A18),
                  width: 3,
                ),
              ),
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String title;
  final VoidCallback onTap;

  const _NavItem({
    required this.title,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(
            horizontal: 4,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color:
                _hovered ? Colors.white.withOpacity(0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              color: _hovered ? Colors.white : Colors.white.withOpacity(0.62),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatefulWidget {
  final String title;
  final VoidCallback onTap;
  final bool compact;

  const _HeaderButton({
    required this.title,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 17 : 20,
            vertical: widget.compact ? 11 : 12,
          ),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFFF8A32) : const Color(0xFFFF7A18),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7A18).withOpacity(
                  _hovered ? 0.30 : 0.16,
                ),
                blurRadius: 20,
              ),
            ],
          ),
          child: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFFF8A32) : const Color(0xFFFF7A18),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7A18).withOpacity(
                  _hovered ? 0.32 : 0.16,
                ),
                blurRadius: _hovered ? 28 : 20,
                spreadRadius: _hovered ? 1 : 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 9),
              Icon(
                widget.icon,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.035),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withOpacity(
                _hovered ? 0.20 : 0.10,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: Colors.white.withOpacity(0.80),
                size: 18,
              ),
              const SizedBox(width: 9),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 6,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFF7A18),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.58),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final bool vertical;

  const _StatDivider({
    required this.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: vertical ? 1 : double.infinity,
      height: vertical ? 42 : 1,
      margin: vertical
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(
              horizontal: 35,
            ),
      color: Colors.white.withOpacity(0.08),
    );
  }
}
