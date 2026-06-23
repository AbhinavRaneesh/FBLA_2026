import '../models/nlc_practice_scenarios.dart';
import '../models/nlc_rubric_result.dart';

/// Bundled rubric scores used when live AI judging is unavailable.
class NlcDemoMode {
  NlcDemoMode._();

  static NlcRubricResult bundledRubric(String eventName) {
    final practice = nlcCuratedPractice[eventName] ?? nlcGenericRoleplay;
    final preset = _presets[eventName];
    if (preset != null) return preset;

    return NlcRubricResult(
      overallScore: 3.8,
      topFix:
          'Add one concrete metric or example for each main point so judges hear evidence, not only ideas.',
      judgeQuestion:
          'If your budget were cut in half, which part of your plan would you keep first — and why?',
      dimensions: practice.indicators
          .map((indicator) => NlcRubricDimension(
                indicator: indicator,
                score: 4,
                evidence: 'Solid structure; deepen with a specific example.',
              ))
          .toList(),
    );
  }

  static const Map<String, NlcRubricResult> _presets = {
    'Marketing': NlcRubricResult(
      overallScore: 4.2,
      topFix:
          'Name one measurable KPI (e.g., weekly foot traffic or social engagement rate) to prove your plan works.',
      judgeQuestion:
          'How would you reposition the shop if the national chain runs a 50%-off promotion next month?',
      dimensions: [
        NlcRubricDimension(
          indicator: 'Identifies the target customer and competitive edge',
          score: 4,
          evidence: 'You referenced loyal locals but could define a persona.',
        ),
        NlcRubricDimension(
          indicator: 'Clear marketing mix',
          score: 5,
          evidence: 'Product, price, place, and promotion were all addressed.',
        ),
        NlcRubricDimension(
          indicator: 'Low-cost promotion tactics',
          score: 4,
          evidence: 'Social and community ideas were realistic for a small shop.',
        ),
        NlcRubricDimension(
          indicator: 'Success measurement',
          score: 3,
          evidence: 'Mentioned sales recovery but no timeline or metric yet.',
        ),
        NlcRubricDimension(
          indicator: 'Professional communication',
          score: 5,
          evidence: 'Confident tone and organized delivery.',
        ),
        NlcRubricDimension(
          indicator: 'Defends under questions',
          score: 4,
          evidence: 'Good reasoning; add a contingency if tactics underperform.',
        ),
      ],
    ),
    'Public Speaking': NlcRubricResult(
      overallScore: 4.0,
      topFix:
          'Open with a 10-second story or statistic before stating your thesis — judges remember hooks.',
      judgeQuestion:
          'Which business skill do you think is hardest for teens to practice in their community, and why?',
      dimensions: [
        NlcRubricDimension(
          indicator: 'Strong opening',
          score: 4,
          evidence: 'Clear start; a personal anecdote would elevate impact.',
        ),
        NlcRubricDimension(
          indicator: 'Thesis and structure',
          score: 5,
          evidence: 'Three main points flowed logically.',
        ),
        NlcRubricDimension(
          indicator: 'Examples and evidence',
          score: 4,
          evidence: 'Good community references; one local data point would help.',
        ),
        NlcRubricDimension(
          indicator: 'Delivery',
          score: 4,
          evidence: 'Steady pace; vary volume on key lines.',
        ),
        NlcRubricDimension(
          indicator: 'Conclusion',
          score: 4,
          evidence: 'Memorable call to action included.',
        ),
        NlcRubricDimension(
          indicator: 'Time management',
          score: 3,
          evidence: 'Slightly long on setup; trim intro by 15 seconds.',
        ),
      ],
    ),
    'Entrepreneurship': NlcRubricResult(
      overallScore: 3.9,
      topFix:
          'Quantify startup costs and first-year revenue assumptions so investors trust your model.',
      judgeQuestion:
          'What is your biggest risk if a larger competitor enters your market in year one?',
      dimensions: [
        NlcRubricDimension(
          indicator: 'Compelling business concept',
          score: 4,
          evidence: 'Problem and solution were clear.',
        ),
        NlcRubricDimension(
          indicator: 'Target market and need',
          score: 4,
          evidence: 'Defined audience; add market size estimate.',
        ),
        NlcRubricDimension(
          indicator: 'Revenue and cost model',
          score: 3,
          evidence: 'Mentioned pricing; needs explicit unit economics.',
        ),
        NlcRubricDimension(
          indicator: 'Team execution',
          score: 4,
          evidence: 'Roles and strengths were credible.',
        ),
        NlcRubricDimension(
          indicator: 'Organized delivery',
          score: 5,
          evidence: 'Pitch followed investor-friendly structure.',
        ),
        NlcRubricDimension(
          indicator: 'Q&A readiness',
          score: 4,
          evidence: 'Handled objections; prepare for scaling questions.',
        ),
      ],
    ),
    'Mobile Application Development': NlcRubricResult(
      overallScore: 4.1,
      topFix:
          'Walk through one complete user flow screen-by-screen so judges see the member journey, not only feature lists.',
      judgeQuestion:
          'How would you measure whether this app actually improves chapter engagement after launch?',
      dimensions: [
        NlcRubricDimension(
          indicator: 'Defines the member problem and target audience',
          score: 4,
          evidence: 'Member need was stated clearly; tighten who the primary user is.',
        ),
        NlcRubricDimension(
          indicator: 'Demonstrates a clear user journey',
          score: 4,
          evidence: 'Onboarding and core tabs were outlined; add one end-to-end path.',
        ),
        NlcRubricDimension(
          indicator: 'Explains design and technical implementation',
          score: 4,
          evidence: 'Stack and architecture mentioned; highlight one scalability choice.',
        ),
        NlcRubricDimension(
          indicator: 'Highlights social and engagement integrations',
          score: 5,
          evidence: 'Social, events, and resources tie-ins were compelling.',
        ),
        NlcRubricDimension(
          indicator: 'Addresses accessibility and usability',
          score: 3,
          evidence: 'UI discussed; name one accessibility or usability standard you follow.',
        ),
        NlcRubricDimension(
          indicator: 'Delivers a confident, organized presentation',
          score: 5,
          evidence: 'Professional structure and confident delivery throughout.',
        ),
      ],
    ),
  };
}
