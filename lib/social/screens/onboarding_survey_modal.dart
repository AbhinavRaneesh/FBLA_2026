import 'package:flutter/material.dart';

import '../../main.dart' show fblaGold, fblaNavy;
import '../models/social_models.dart';
import '../theme/bluewave_theme.dart';

/// First-visit survey — responses initialize ML ranking weights in [UserPreferences].
class OnboardingSurveyModal extends StatefulWidget {
  final void Function(UserPreferences preferences) onComplete;

  const OnboardingSurveyModal({super.key, required this.onComplete});

  static Future<void> show(
    BuildContext context, {
    required void Function(UserPreferences preferences) onComplete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OnboardingSurveyModal(onComplete: onComplete),
    );
  }

  @override
  State<OnboardingSurveyModal> createState() => _OnboardingSurveyModalState();
}

class _OnboardingSurveyModalState extends State<OnboardingSurveyModal> {
  final _interests = <ContentInterest>{ContentInterest.competitions};
  final _contentTypes = <ContentTypePreference>{ContentTypePreference.textPosts};
  final _platforms = <PlatformPreference>{PlatformPreference.blueWave};
  EventContentFrequency _eventFrequency = EventContentFrequency.sometimes;
  int _step = 0;

  void _toggle<T>(Set<T> set, T value) {
    setState(() {
      if (set.contains(value)) {
        if (set.length > 1) set.remove(value);
      } else {
        set.add(value);
      }
    });
  }

  void _finish() {
    widget.onComplete(
      UserPreferences(
        interests: _interests,
        contentTypes: _contentTypes,
        platforms: _platforms,
        eventFrequency: _eventFrequency,
        onboardingComplete: true,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        gradient: BlueWaveTheme.headerGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Personalize your Social feed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your answers power BlueWave recommendations and feed ranking.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildStep()),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      if (_step < 3) {
                        setState(() => _step++);
                      } else {
                        _finish();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fblaGold,
                      foregroundColor: fblaNavy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(_step < 3 ? 'Next' : 'Start Social'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _multiSelect<ContentInterest>(
          title: 'Which topics interest you most?',
          options: ContentInterest.values,
          selected: _interests,
          label: (e) => e.name[0].toUpperCase() + e.name.substring(1),
          onToggle: (v) => _toggle(_interests, v),
        );
      case 1:
        return _multiSelect<ContentTypePreference>(
          title: 'What content do you like most?',
          options: ContentTypePreference.values,
          selected: _contentTypes,
          label: (e) {
            switch (e) {
              case ContentTypePreference.shortVideo:
                return 'Short videos';
              case ContentTypePreference.photos:
                return 'Photos';
              case ContentTypePreference.textPosts:
                return 'Text posts';
              case ContentTypePreference.forums:
                return 'Forums';
              case ContentTypePreference.news:
                return 'News';
            }
          },
          onToggle: (v) => _toggle(_contentTypes, v),
        );
      case 2:
        return _multiSelect<PlatformPreference>(
          title: 'Which platforms do you use most?',
          options: PlatformPreference.values,
          selected: _platforms,
          label: (e) {
            switch (e) {
              case PlatformPreference.blueWave:
                return 'BlueWave (in-app)';
              case PlatformPreference.instagram:
                return 'Instagram';
              case PlatformPreference.youtube:
                return 'YouTube';
              case PlatformPreference.tiktok:
                return 'TikTok';
            }
          },
          onToggle: (v) => _toggle(_platforms, v),
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How often should we show event content?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            ...EventContentFrequency.values.map((freq) {
              final selected = _eventFrequency == freq;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ChoiceChip(
                  label: Text(freq.name[0].toUpperCase() + freq.name.substring(1)),
                  selected: selected,
                  onSelected: (_) => setState(() => _eventFrequency = freq),
                  selectedColor: BlueWaveTheme.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
              );
            }),
          ],
        );
    }
  }

  Widget _multiSelect<T>({
    required String title,
    required List<T> options,
    required Set<T> selected,
    required String Function(T) label,
    required void Function(T) onToggle,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = selected.contains(opt);
              return FilterChip(
                label: Text(label(opt)),
                selected: isSelected,
                onSelected: (_) => onToggle(opt),
                selectedColor: BlueWaveTheme.primary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
