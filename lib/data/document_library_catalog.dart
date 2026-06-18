/// Official FBLA PDFs bundled under [AppAssets.officialDocumentsDir].
class DocumentLibraryItem {
  final String id;
  final String title;
  final String subtitle;
  final String assetPath;
  final DocumentLibraryCategory category;

  const DocumentLibraryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.category,
  });
}

enum DocumentLibraryCategory {
  all('All'),
  chapterLeadership('Chapter & Leadership'),
  competitiveEvents('Competitive Events'),
  awards('Awards & Recognition'),
  marketing('Marketing & Outreach'),
  templates('Templates & Forms');

  const DocumentLibraryCategory(this.label);
  final String label;
}

class DocumentLibraryCatalog {
  DocumentLibraryCatalog._();

  static const String _dir = 'assets/official_documents/';

  static const List<DocumentLibraryItem> _officialDocuments = [
    DocumentLibraryItem(
      id: 'champion_chapter_adviser',
      title: 'Champion Chapter Adviser Resource',
      subtitle: 'Adviser planning and chapter excellence guidance.',
      assetPath: '${_dir}Champion-Chapter-Adviser-Resource.pdf',
      category: DocumentLibraryCategory.chapterLeadership,
    ),
    DocumentLibraryItem(
      id: 'creating_smart_goals',
      title: 'Creating Your SMART Goals',
      subtitle: 'Goal-setting framework for chapter planning.',
      assetPath: '${_dir}Creating_Your_SMART_Goals.pdf.pdf',
      category: DocumentLibraryCategory.chapterLeadership,
    ),
    DocumentLibraryItem(
      id: 'cybersecurity_guidelines',
      title: 'Cybersecurity Guidelines',
      subtitle: 'Official competitive event guidelines.',
      assetPath: '${_dir}Cybersecurity.pdf',
      category: DocumentLibraryCategory.competitiveEvents,
    ),
    DocumentLibraryItem(
      id: 'eoy_report',
      title: 'End-of-Year Report',
      subtitle: 'Template for annual chapter reporting.',
      assetPath: '${_dir}EOY_Report.pdf',
      category: DocumentLibraryCategory.chapterLeadership,
    ),
    DocumentLibraryItem(
      id: 'collegiate_excellence_award',
      title: 'FBLA Collegiate Excellence Award',
      subtitle: 'Collegiate recognition program overview.',
      assetPath: '${_dir}FBLA_Collegiate_Excellence_Award.pdf',
      category: DocumentLibraryCategory.awards,
    ),
    DocumentLibraryItem(
      id: 'ms_business_achievement_awards',
      title: 'FBLA MS Business Achievement Awards',
      subtitle: 'Middle School BAA program details.',
      assetPath: '${_dir}FBLA_MS_Business_Achievement_Awards.pdf',
      category: DocumentLibraryCategory.awards,
    ),
    DocumentLibraryItem(
      id: 'marketing_plan_template',
      title: 'Marketing Plan Template',
      subtitle: 'Structured plan for chapter marketing efforts.',
      assetPath: '${_dir}Marketing_Plan_Template.pdf',
      category: DocumentLibraryCategory.marketing,
    ),
    DocumentLibraryItem(
      id: 'mobile_app_dev_guidelines',
      title: 'Mobile Application Development Guidelines',
      subtitle: 'Official competitive event guidelines.',
      assetPath: '${_dir}Mobile-Application-Development.pdf',
      category: DocumentLibraryCategory.competitiveEvents,
    ),
    DocumentLibraryItem(
      id: 'mythbusters_competitive_events',
      title: 'Mythbusters: Competitive Events Strategy Guide',
      subtitle: 'Strategy tips for competitive event success.',
      assetPath: '${_dir}Mythbusters_Competitive_Events_Strategy_Guide.pdf',
      category: DocumentLibraryCategory.competitiveEvents,
    ),
    DocumentLibraryItem(
      id: 'pow_template',
      title: 'Program of Work Template',
      subtitle: 'Plan your chapter program of work.',
      assetPath: '${_dir}POW_Template.pdf',
      category: DocumentLibraryCategory.marketing,
    ),
    DocumentLibraryItem(
      id: 'press_release_template',
      title: 'Press Release Template',
      subtitle: 'Share chapter news with local media.',
      assetPath: '${_dir}Press_Release_Template.pdf',
      category: DocumentLibraryCategory.marketing,
    ),
    DocumentLibraryItem(
      id: 'recruitment_strategies',
      title: 'Recruitment Strategies',
      subtitle: 'Ideas to grow chapter membership.',
      assetPath: '${_dir}Recruitment_Strategies.pdf',
      category: DocumentLibraryCategory.marketing,
    ),
    DocumentLibraryItem(
      id: 'sample_agenda',
      title: 'Sample Agenda',
      subtitle: 'Meeting agenda template for officers.',
      assetPath: '${_dir}Sample_Agenda.pdf',
      category: DocumentLibraryCategory.templates,
    ),
    DocumentLibraryItem(
      id: 'sample_bylaws',
      title: 'Sample Bylaws',
      subtitle: 'Chapter bylaws reference document.',
      assetPath: '${_dir}Sample_Bylaws.pdf',
      category: DocumentLibraryCategory.chapterLeadership,
    ),
    DocumentLibraryItem(
      id: 'sample_emblem_ceremony',
      title: 'Sample Emblem Ceremony Script',
      subtitle: 'Script for chapter emblem ceremonies.',
      assetPath: '${_dir}Sample_Emblem_Ceremony_Script.pdf',
      category: DocumentLibraryCategory.chapterLeadership,
    ),
    DocumentLibraryItem(
      id: 'sample_committee_report',
      title: 'Sample FBLA Committee Meeting Report',
      subtitle: 'Report format for committee meetings.',
      assetPath: '${_dir}Sample_FBLA_Committee_Meeting_Report.pdf',
      category: DocumentLibraryCategory.templates,
    ),
    DocumentLibraryItem(
      id: 'sample_officer_roles',
      title: 'Sample FBLA Officer Roles & Responsibilities',
      subtitle: 'Officer duty descriptions and expectations.',
      assetPath: '${_dir}Sample_FBLA_Officer_Roles_Responsibilites.pdf',
      category: DocumentLibraryCategory.chapterLeadership,
    ),
    DocumentLibraryItem(
      id: 'sample_fundraising_letter',
      title: 'Sample Fundraising Letter',
      subtitle: 'Letter template for chapter fundraising.',
      assetPath: '${_dir}Sample_Fundraising_Letter.pdf',
      category: DocumentLibraryCategory.templates,
    ),
    DocumentLibraryItem(
      id: 'sample_officer_application',
      title: 'Sample HS/MS Officer Application',
      subtitle: 'Application form for chapter officers.',
      assetPath: '${_dir}Sample_HS_MS_Officer_Application.pdf',
      category: DocumentLibraryCategory.templates,
    ),
    DocumentLibraryItem(
      id: 'sample_minutes',
      title: 'Sample Minutes',
      subtitle: 'Meeting minutes template.',
      assetPath: '${_dir}Sample_Minutes.pdf',
      category: DocumentLibraryCategory.templates,
    ),
    DocumentLibraryItem(
      id: 'sample_officer_elections',
      title: 'Sample Officer Elections Qualifications',
      subtitle: 'Election rules and qualification guidance.',
      assetPath: '${_dir}Sample_Officer_Elections_Qualifications.pdf',
      category: DocumentLibraryCategory.chapterLeadership,
    ),
    DocumentLibraryItem(
      id: 'sample_point_system',
      title: 'Sample Point System',
      subtitle: 'Chapter member participation point system.',
      assetPath: '${_dir}Sample_Point_System.pdf',
      category: DocumentLibraryCategory.chapterLeadership,
    ),
    DocumentLibraryItem(
      id: 'schedule_glance_2026_2027',
      title: 'Schedule at a Glance 2026–2027',
      subtitle: 'National program schedule overview.',
      assetPath: '${_dir}Schedule-at-a-Glance-2026-2027.pdf',
      category: DocumentLibraryCategory.competitiveEvents,
    ),
    DocumentLibraryItem(
      id: 'smart_goals',
      title: 'SMART Goals',
      subtitle: 'SMART goal-setting reference.',
      assetPath: '${_dir}SMART_Goals.pdf',
      category: DocumentLibraryCategory.chapterLeadership,
    ),
    DocumentLibraryItem(
      id: 'benefits_collegiate',
      title: 'Top 10 Benefits of Joining FBLA Collegiate',
      subtitle: 'Membership benefits for collegiate members.',
      assetPath: '${_dir}Top_10_Benefits_FBLA_Collegiate_v4.pdf',
      category: DocumentLibraryCategory.awards,
    ),
    DocumentLibraryItem(
      id: 'benefits_hs',
      title: 'Top 10 Benefits of Joining FBLA High School',
      subtitle: 'Membership benefits for high school members.',
      assetPath: '${_dir}Top_10_Benefits_FBLA_HS.pdf',
      category: DocumentLibraryCategory.awards,
    ),
    DocumentLibraryItem(
      id: 'benefits_ms',
      title: 'Top 10 Benefits of Joining FBLA Middle School',
      subtitle: 'Membership benefits for middle school members.',
      assetPath: '${_dir}Top_10_Benefits_FBLA_MS_v4.pdf',
      category: DocumentLibraryCategory.awards,
    ),
    DocumentLibraryItem(
      id: 'tips_strong_pow',
      title: 'Tips for a Strong Program of Work',
      subtitle: 'Best practices for your chapter POW.',
      assetPath: '${_dir}Tips_For_A_Strong_POW.pdf',
      category: DocumentLibraryCategory.marketing,
    ),
    DocumentLibraryItem(
      id: 'tips_press_release',
      title: 'Tips for Sharing a Press Release',
      subtitle: 'How to distribute chapter press releases.',
      assetPath: '${_dir}Tips_Sharing_Press_Release.pdf',
      category: DocumentLibraryCategory.marketing,
    ),
    DocumentLibraryItem(
      id: 'treasurers_report',
      title: "Treasurer's Report",
      subtitle: 'Financial reporting template for treasurers.',
      assetPath: '${_dir}Treasurers_Report.pdf',
      category: DocumentLibraryCategory.chapterLeadership,
    ),
  ];

  static const List<String> _placeholderEventNames = [
    'Accounting I',
    'Accounting II',
    'Advertising',
    'Agribusiness',
    'Banking & Financial Systems',
    'Business Communication',
    'Business Law',
    'Business Plan',
    'Career Portfolio',
    'Coding & Programming',
    'Computer Problem Solving',
    'Data Analysis',
    'Digital Video Production',
    'Economics',
    'Entrepreneurship',
    'Financial Statement Analysis',
    'Graphic Design',
    'Healthcare Administration',
    'Hospitality Management',
    'Human Resource Management',
    'Insurance & Risk Management',
    'Introduction to Business',
    'Journalism',
    'Management Decision Making',
    'Marketing',
    'Network Design',
    'Organizational Leadership',
    'Parliamentary Procedure',
    'Personal Finance',
    'Public Speaking',
    'Sales Presentation',
    'Securities & Investments',
    'Social Media Strategies',
    'Sports & Entertainment Management',
    'Spreadsheet Applications',
    'Supply Chain Management',
    'UX Design',
    'Website Design',
    'Word Processing',
    'Business Ethics',
  ];

  static const List<String> _placeholderSuffixes = [
    'Event Guidelines',
    'Competitive Rubric',
    'Study Guide',
    'Topic Brief',
    'Judge Orientation',
    'Presentation Standards',
    'Roleplay Prep Kit',
    'Objective Test Blueprint',
    'Performance Checklist',
    'National Conference Brief',
    'State Leadership Packet',
    'Chapter Planning Notes',
    'Officer Transition Guide',
    'Adviser Resource Sheet',
    'Member Orientation Handout',
    'Competition Day Checklist',
    'Dress Code Reference',
    'Scoring Criteria Summary',
    'Sample Case Study Pack',
    'Practice Round Workbook',
  ];

  static const List<String> _placeholderChapterTitles = [
    'Chapter Budget Worksheet',
    'Committee Charter Template',
    'Community Service Log',
    'Conference Registration Guide',
    'Dues Collection Tracker',
    'Election Ballot Template',
    'Guest Speaker Request Form',
    'Icebreaker Activity Pack',
    'Leadership Workshop Outline',
    'Local Business Partnership Guide',
  ];

  static List<DocumentLibraryItem> _buildPlaceholderDocuments() {
    const targetCount = 70;
    final placeholders = <DocumentLibraryItem>[];
    final categories = DocumentLibraryCategory.values
        .where((c) => c != DocumentLibraryCategory.all)
        .toList();
    final assetPaths =
        _officialDocuments.map((doc) => doc.assetPath).toList(growable: false);

    var index = 0;
    while (placeholders.length < targetCount) {
      final category = categories[index % categories.length];
      final assetPath = assetPaths[index % assetPaths.length];
      final String title;
      final String subtitle;

      if (index < _placeholderChapterTitles.length) {
        title = _placeholderChapterTitles[index];
        subtitle = 'Chapter operations and leadership reference.';
      } else {
        final event =
            _placeholderEventNames[index % _placeholderEventNames.length];
        final suffix =
            _placeholderSuffixes[index % _placeholderSuffixes.length];
        title = '$event $suffix';
        subtitle = 'Supplemental FBLA resource for members and advisers.';
      }

      placeholders.add(
        DocumentLibraryItem(
          id: 'placeholder_${index + 1}',
          title: title,
          subtitle: subtitle,
          assetPath: assetPath,
          category: category,
        ),
      );
      index++;
    }

    return placeholders;
  }

  static final List<DocumentLibraryItem> documents = [
    ..._officialDocuments,
    ..._buildPlaceholderDocuments(),
  ];

  static List<DocumentLibraryItem> sortedAlphabetically() {
    final list = List<DocumentLibraryItem>.from(documents)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }
}
