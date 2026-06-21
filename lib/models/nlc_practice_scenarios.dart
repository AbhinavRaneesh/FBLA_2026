/// Curated FBLA performance-event scenarios for NLC Ready Live Sim and AI Coach.
class NlcCuratedPractice {
  final String scenario;
  final List<String> indicators;
  final String category;

  const NlcCuratedPractice({
    required this.scenario,
    required this.indicators,
    required this.category,
  });

  bool get isRoleplay => category.toLowerCase().contains('roleplay');
}

const NlcCuratedPractice nlcGenericRoleplay = NlcCuratedPractice(
  category: 'Roleplay Events',
  scenario:
      'You are a business professional meeting with a client (the judge). You have 10 minutes to prepare, then present your recommendation and answer their questions. Greet them, identify the core problem, propose a clear solution, and justify it with business reasoning.',
  indicators: [
    'Greets the judge professionally and establishes rapport',
    'Clearly identifies the problem or objective',
    'Proposes a specific, realistic solution',
    'Justifies the solution with sound business concepts',
    'Communicates with confidence and clear organization',
    'Answers follow-up questions thoughtfully',
  ],
);

const NlcCuratedPractice nlcGenericPresentation = NlcCuratedPractice(
  category: 'Presentation Events',
  scenario:
      'Prepare a presentation on the current event topic. Deliver it to a panel of judges with visual aids, then answer their questions. Focus on a clear structure, strong evidence, and confident delivery.',
  indicators: [
    'Opens with a clear hook and purpose',
    'Content is well-organized and addresses the prompt',
    'Uses credible evidence and examples',
    'Visual aids are clean and support the message',
    'Delivery is confident with good eye contact and pacing',
    'Handles Q&A accurately and calmly',
  ],
);

/// Showcase events with full offline demo rubrics in [NlcDemoMode].
const Map<String, NlcCuratedPractice> nlcCuratedPractice = {
  'Marketing': NlcCuratedPractice(
    category: 'Roleplay Events',
    scenario:
        'A local coffee shop has seen sales drop 20% after a national chain opened nearby. The owner (judge) wants a marketing strategy to win customers back within three months on a small budget. Present your plan and justify your choices.',
    indicators: [
      'Identifies the target customer and the shop\'s competitive edge',
      'Proposes a clear marketing mix (product, price, place, promotion)',
      'Recommends realistic, low-cost promotion tactics',
      'Explains how success will be measured',
      'Communicates persuasively and professionally',
      'Defends the plan under judge questions',
    ],
  ),
  'Public Speaking': NlcCuratedPractice(
    category: 'Presentation Events',
    scenario:
        'Prepare and deliver a 4-minute speech on: "How can young people use business skills to strengthen their local community?" You will be judged on content, organization, and delivery.',
    indicators: [
      'Strong opening that grabs attention',
      'Clear thesis and logical structure',
      'Specific examples and evidence',
      'Confident delivery: eye contact, pace, and projection',
      'Memorable, purposeful conclusion',
      'Stays within the time limit',
    ],
  ),
  'Entrepreneurship': NlcCuratedPractice(
    category: 'Roleplay Events',
    scenario:
        'Your team is pitching a new small-business idea to investors (the judges). Present the concept, target market, revenue model, and why your team can execute it.',
    indicators: [
      'Clear, compelling business concept',
      'Well-defined target market and need',
      'Realistic revenue and cost model',
      'Evidence the team can execute',
      'Confident, organized team delivery',
      'Strong answers to investor questions',
    ],
  ),
  'Business Ethics': NlcCuratedPractice(
    category: 'Presentation Events',
    scenario:
        'Your chapter discovered a sponsor wants logo placement on materials in exchange for funding, but the sponsor\'s values conflict with FBLA\'s mission. Present your ethical recommendation to chapter officers.',
    indicators: [
      'Defines the ethical dilemma clearly',
      'Applies ethical frameworks and FBLA values',
      'Weighs stakeholder impacts fairly',
      'Recommends a principled, actionable path',
      'Anticipates objections and responds logically',
      'Communicates with professionalism and empathy',
    ],
  ),
  'Hospitality & Event Management': NlcCuratedPractice(
    category: 'Roleplay Events',
    scenario:
        'A corporate client wants your chapter to plan a 200-person leadership banquet in six weeks with a strict budget. The judge is the client — present your event plan and risk mitigation.',
    indicators: [
      'Clarifies client goals, budget, and constraints',
      'Proposes a realistic timeline and venue strategy',
      'Addresses catering, staffing, and guest experience',
      'Identifies risks with contingency plans',
      'Demonstrates hospitality professionalism',
      'Handles client questions confidently',
    ],
  ),
  'Customer Service': NlcCuratedPractice(
    category: 'Roleplay Events',
    scenario:
        'An upset customer (the judge) received the wrong order twice and demands a refund plus compensation. Resolve the situation while protecting the business.',
    indicators: [
      'Listens actively and de-escalates emotion',
      'Apologizes appropriately without admitting fault blindly',
      'Offers a fair, policy-aligned resolution',
      'Explains next steps clearly',
      'Maintains a calm, professional tone',
      'Turns the interaction toward customer loyalty',
    ],
  ),
  'Cybersecurity': NlcCuratedPractice(
    category: 'Objective Test Events',
    scenario:
        'As the chapter\'s technology officer, a member clicked a phishing link. Brief the adviser (judge) on immediate response steps and a prevention plan for the chapter.',
    indicators: [
      'Identifies immediate containment actions',
      'Explains impact on accounts and data',
      'Recommends verification and recovery steps',
      'Proposes chapter-wide security awareness training',
      'Uses accurate cybersecurity terminology',
      'Communicates clearly under pressure',
    ],
  ),
  'Mobile Application Development': NlcCuratedPractice(
    category: 'Presentation Events',
    scenario:
        'Present your chapter\'s mobile app concept for member engagement. Cover the user journey, key features, technical stack, and how it keeps members connected year-round.',
    indicators: [
      'Defines the member problem and target audience',
      'Demonstrates a clear user journey',
      'Explains design and technical implementation',
      'Highlights social and engagement integrations',
      'Addresses accessibility and usability',
      'Delivers a confident, organized presentation',
    ],
  ),
  'Impromptu Speaking': NlcCuratedPractice(
    category: 'Presentation Events',
    scenario:
        'You draw the topic: "Leadership is a choice, not a title." You have 3 minutes to prepare and 4 minutes to speak. Deliver your impromptu speech to the judges.',
    indicators: [
      'Interprets the topic with a clear angle',
      'Organizes ideas quickly with a logical flow',
      'Uses relevant examples or anecdotes',
      'Maintains composure with minimal filler words',
      'Concludes with impact within time',
      'Adapts if the judge asks a follow-up',
    ],
  ),
  'Sales Presentation': NlcCuratedPractice(
    category: 'Presentation Events',
    scenario:
        'You are selling a sustainable school-supply subscription to a district purchasing manager (judge). Convince them your offer saves money and supports green initiatives.',
    indicators: [
      'Opens with a customer-focused value proposition',
      'Tailors benefits to the buyer\'s priorities',
      'Handles price and objection questions',
      'Uses evidence and social proof',
      'Closes with a clear call to action',
      'Maintains persuasive but ethical tone',
    ],
  ),
};

NlcCuratedPractice nlcPracticeForEvent(String eventName, {String? category}) {
  final direct = nlcCuratedPractice[eventName];
  if (direct != null) return direct;

  final cat = (category ?? '').toLowerCase();
  if (cat.contains('roleplay')) return nlcGenericRoleplay;
  if (cat.contains('presentation')) return nlcGenericPresentation;
  return nlcGenericRoleplay;
}

String? nlcCategoryForEvent(String eventName) {
  return nlcCuratedPractice[eventName]?.category ?? nlcGenericRoleplay.category;
}

bool nlcSupportsLiveSim(String eventName, String category) {
  return category.toLowerCase().contains('roleplay');
}
