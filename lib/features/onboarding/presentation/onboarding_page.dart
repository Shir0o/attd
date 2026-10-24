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

  @override
  void initState() {
    super.initState();
    widget.onboardingController.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant OnboardingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onboardingController != widget.onboardingController) {
      oldWidget.onboardingController.removeListener(_onControllerChanged);
      widget.onboardingController.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.onboardingController.removeListener(_onControllerChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _skip() {
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _complete() {
    if (!widget.onboardingController.coordinatorAgeAffirmed) return;
    widget.onboardingController.completeOnboarding();
  }

  List<_OnboardingSlide> _buildSlides(BuildContext context) {
    return [
      const _OnboardingSlide(
        eyebrow: '01 · Quick marking',
        title: 'Swipe with one thumb.',
        description: 'Right for present, left for absent. The deck handles the rest.',
        art: OnboardingDeckArt(),
      ),
      const _OnboardingSlide(
        eyebrow: '02 · Session history',
        title: 'Every Sunday, remembered.',
        description: 'Review past sessions and watch trends settle in.',
        art: OnboardingHistoryArt(),
      ),
      const _OnboardingSlide(
        eyebrow: '03 · Members & families',
        title: 'Roll up by family.',
        description: 'Group members into families. Smart defaults speed up the rest.',
        art: OnboardingFamilyArt(),
      ),
      _OnboardingSlide(
        eyebrow: '04 · Yours, fully.',
        title: 'Local-first. Always yours.',
        description:
            'Your data stays on your device. Sync to your own Google Drive — never ours.',
        art: const OnboardingCloudArt(),
        footer: _buildCoordinatorAgeAffirmation(context),
      ),
    ];
  }

  Widget _buildCoordinatorAgeAffirmation(BuildContext context) {
    final c = context.conv;
    final affirmed = widget.onboardingController.coordinatorAgeAffirmed;
    return Container(
      decoration: BoxDecoration(
        color: c.cardSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          widget.onboardingController.setCoordinatorAgeAffirmed(!affirmed);
        },
        child: Row(
          children: [
            Checkbox(
              key: const ValueKey('coordinator_age_affirmation_checkbox'),
              value: affirmed,
              activeColor: c.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (val) {
                widget.onboardingController.setCoordinatorAgeAffirmed(val ?? false);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'I confirm that I am at least 13 years old or an authorized adult coordinator.',
                style: AppTypography.geist(
                  fontSize: 13,
                  height: 1.35,
                  color: c.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = _buildSlides(context);
    final isLast = _currentPage == slides.length - 1;
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
                      slides.length,
                      (index) => _buildPageIndicator(index),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: isLast
                        ? (widget.onboardingController.coordinatorAgeAffirmed
                            ? _complete
                            : null)
                        : _skip,
                    child: Text(isLast ? 'Get Started' : 'Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) => slides[index],
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
    this.footer,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget art;
  final Widget? footer;

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
                if (footer != null) ...[
                  const SizedBox(height: 16),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
