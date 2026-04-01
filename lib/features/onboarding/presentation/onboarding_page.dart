import 'package:flutter/material.dart';
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

  final List<_OnboardingSlide> _slides = [
    const _OnboardingSlide(
      title: 'Quick Marking',
      description: 'Swipe left to mark as absent, right to mark as present. It\'s that easy!',
      mockUI: MockAttendanceSwipe(),
    ),
    const _OnboardingSlide(
      title: 'Session History',
      description: 'Review past attendance sessions and track trends over time.',
      mockUI: MockSessionHistory(),
    ),
    const _OnboardingSlide(
      title: 'Manage Members',
      description: 'Organize your group into families and manage individual members.',
      mockUI: MockManageMembers(),
    ),
    const _OnboardingSlide(
      title: 'Cloud Backup',
      description: 'Automatically sync your data to Google Drive for safe keeping.',
      mockUI: MockCloudBackup(),
    ),
    const _OnboardingSlide(
      title: 'Data & Export',
      description: 'Full control over your data with local backups and CSV exports.',
      mockUI: MockManageBackup(),
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Progress
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
              child: Row(
                children: [
                  // Progress Indicators
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      _slides.length,
                      (index) => _buildPageIndicator(index),
                    ),
                  ),
                  const Spacer(),
                  // Skip / Get Started Button
                  if (_currentPage < _slides.length - 1)
                    TextButton(
                      onPressed: _complete,
                      child: const Text('Skip'),
                    )
                  else
                    TextButton(
                      onPressed: _complete,
                      child: const Text('Get Started'),
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
                itemBuilder: (context, index) {
                  return _slides[index];
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 6.0,
      width: isActive ? 20.0 : 6.0,
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.title,
    required this.description,
    required this.mockUI,
  });

  final String title;
  final String description;
  final Widget mockUI;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  mockUI,
                  const SizedBox(height: 40),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
}
