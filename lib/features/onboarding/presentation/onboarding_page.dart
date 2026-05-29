import 'package:flutter/material.dart';

import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_theme.dart';
import '../application/onboarding_controller.dart';
import 'mock_components.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onboardingController,
  });

  final OnboardingController onboardingController;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      eyebrow: '01 · Quick marking',
      title: 'Swipe with one thumb.',
      description: 'Right for present, left for absent. The deck handles the rest.',
      art: OnboardingDeckArt(),
    ),
    _OnboardingSlide(
      eyebrow: '02 · Session history',
      title: 'Every Sunday, remembered.',
      description: 'Review past sessions and watch trends settle in.',
      art: OnboardingHistoryArt(),
    ),
    _OnboardingSlide(
      eyebrow: '03 · Members & families',
      title: 'Roll up by family.',
      description: 'Group members into families. Smart defaults speed up the rest.',
      art: OnboardingFamilyArt(),
    ),
    _OnboardingSlide(
      eyebrow: '04 · Yours, fully.',
      title: 'Local-first. Encrypted backup.',
      description:
          'Your data stays on your device. Sync to your own Google Drive — never ours.',
      art: OnboardingCloudArt(),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _complete() {
    widget.onboardingController.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top: progress pips + Skip / Get Started
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 12, 0),
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      _slides.length,
                      (index) => _buildPageIndicator(index),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _complete,
                    child: Text(isLast ? 'Get Started' : 'Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) => _slides[index],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    final c = context.conv;
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(right: 8),
      height: 4.0,
      width: isActive ? 28.0 : 14.0,
      decoration: BoxDecoration(
        color: isActive ? c.primary : c.bg3,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.art,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget art;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                clipBehavior: Clip.none,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 280),
                  child: Center(child: art),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 32, top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: AppTypography.eyebrow(color: c.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: AppTypography.fraunces(
                    fontSize: 36,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -1.08,
                    height: 1.1,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    description,
                    style: AppTypography.geist(
                      fontSize: 16,
                      height: 1.5,
                      color: c.ink2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
