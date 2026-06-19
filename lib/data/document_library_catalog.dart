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

  // Only real, correctly-linked documents are exposed. (Previously this list
  // was padded with generated placeholder entries whose PDF asset was recycled
  // from an unrelated real file, so a title like "Marketing Study Guide" could
  // open the Treasurer's Report — a content/label mismatch.)
  static final List<DocumentLibraryItem> documents = [
    ..._officialDocuments,
  ];

  static List<DocumentLibraryItem> sortedAlphabetically() {
    final list = List<DocumentLibraryItem>.from(documents)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }
}
