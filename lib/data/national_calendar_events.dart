/// FBLA national program calendar (August 2026 – June 2027).
class NationalCalendarEventSeed {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String location;
  final String description;

  const NationalCalendarEventSeed({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.location = 'FBLA National',
    this.description = 'Official FBLA national program date.',
  });
}

DateTime _day(int year, int month, int day, [int hour = 9, int minute = 0]) =>
    DateTime(year, month, day, hour, minute);

DateTime _endOfDay(int year, int month, int day) =>
    DateTime(year, month, day, 23, 59);

DateTime _lastDayOfMonth(int year, int month) =>
    DateTime(year, month + 1, 0, 23, 59);

final nationalCalendarEventSeeds = <NationalCalendarEventSeed>[
  // JUNE–JULY 2026 — NLC 2026 (San Antonio)
  NationalCalendarEventSeed(
    id: 'national_2026_nlc_day1',
    title: 'NLC 2026 - Day 1',
    start: _day(2026, 6, 29, 8),
    end: _day(2026, 6, 29, 17),
    location: 'San Antonio, TX',
    description:
        'FBLA National Leadership Conference opens in San Antonio. Competitions, workshops, and chapter activities begin.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_nlc_day2',
    title: 'NLC 2026 - Day 2',
    start: _day(2026, 6, 30, 8),
    end: _day(2026, 6, 30, 17),
    location: 'San Antonio, TX',
    description:
        'NLC Day 2 in San Antonio. Competitive events, exhibits, and leadership sessions continue.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_nlc_day3',
    title: 'NLC 2026 - Day 3',
    start: _day(2026, 7, 1, 8),
    end: _day(2026, 7, 1, 17),
    location: 'San Antonio, TX',
    description:
        'NLC Day 3 in San Antonio. Finals, workshops, and national programming.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_nlc_day4',
    title: 'NLC 2026 - Day 4',
    start: _day(2026, 7, 2, 8),
    end: _day(2026, 7, 2, 17),
    location: 'San Antonio, TX',
    description:
        'NLC Day 4 in San Antonio. Closing sessions, awards, and conference wrap-up.',
  ),

  // AUGUST 2026
  NationalCalendarEventSeed(
    id: 'national_2026_membership_year_begins',
    title: 'Membership Year Begins',
    start: _day(2026, 8, 1),
    end: _endOfDay(2026, 8, 1),
    description: 'The new FBLA membership year begins.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_baa_excellence_award_opens',
    title: 'Business Achievement Awards & Excellence Award Opens',
    start: _day(2026, 8, 1),
    end: _endOfDay(2026, 8, 1),
    description: 'Submission period opens for BAA and Excellence Award programs.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_mlc_applications_open',
    title: 'Member Leadership Council Applications Open',
    start: _day(2026, 8, 1),
    end: _endOfDay(2026, 8, 1),
    description: 'Applications open for the FBLA Member Leadership Council.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_state_leadership_summit',
    title: 'State Leadership Summit',
    start: _day(2026, 8, 1, 8),
    end: _day(2026, 8, 3, 17),
    description: 'State Leadership Summit for state officers and advisers.',
  ),

  // SEPTEMBER 2026
  NationalCalendarEventSeed(
    id: 'national_2026_competitive_guidelines_release',
    title: 'Competitive Event Guidelines & Resources Release',
    start: _day(2026, 9, 1),
    end: _endOfDay(2026, 9, 1),
    description: 'Official competitive event guidelines and resources are released.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_mlc_applications_close',
    title: 'Member Leadership Council Applications Close',
    start: _day(2026, 9, 9),
    end: _endOfDay(2026, 9, 9),
    description: 'Final day to submit Member Leadership Council applications.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_industry_connect_sep',
    title: 'Industry Connect Webinar',
    start: _day(2026, 9, 16, 18),
    end: _day(2026, 9, 16, 19, 30),
    location: 'Virtual',
    description: 'FBLA Industry Connect webinar for members and advisers.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_champion_chapter_summer_starter',
    title: 'Champion Chapter Summer Starter Deadline',
    start: _day(2026, 9, 24),
    end: _endOfDay(2026, 9, 24),
    description: 'Deadline for Champion Chapter Summer Starter submissions.',
  ),

  // OCTOBER 2026
  NationalCalendarEventSeed(
    id: 'national_2026_acte_business_student_award',
    title: 'ACTE Outstanding Business Student Award Application Deadline',
    start: _day(2026, 10, 1),
    end: _endOfDay(2026, 10, 1),
    description: 'Application deadline for the ACTE Outstanding Business Student Award.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_lead4change_opens',
    title: 'Lead4Change Grant Cycle Opens',
    start: _day(2026, 10, 1),
    end: _day(2027, 6, 1, 17),
    description: 'Lead4Change grant cycle runs October 1, 2026 – June 1, 2027.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_fall_stock_market_begins',
    title: 'Fall Stock Market Game Begins',
    start: _day(2026, 10, 5),
    end: _day(2026, 12, 13, 17),
    description: 'Fall Stock Market Game program runs October 5 – December 13, 2026.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_nflc_registration_deadline',
    title: 'NFLC Registration & Housing Deadline',
    start: _day(2026, 10, 5),
    end: _endOfDay(2026, 10, 5),
    description: 'Registration and housing deadline for the National Fall Leadership Conference.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_fall_lifesmarts_begins',
    title: 'Fall LifeSmarts Challenge Begins',
    start: _day(2026, 10, 12),
    end: _day(2026, 11, 6, 17),
    description: 'Fall LifeSmarts Challenge runs October 12 – November 6, 2026.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_fall_vbc_begins',
    title: 'Fall Virtual Business Challenge Opens',
    start: _day(2026, 10, 13),
    end: _day(2026, 11, 6, 17),
    description: 'Fall Virtual Business Challenge runs October 13 – November 6, 2026.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_industry_connect_oct',
    title: 'Industry Connect Webinar',
    start: _day(2026, 10, 20, 18),
    end: _day(2026, 10, 20, 19, 30),
    location: 'Virtual',
    description: 'FBLA Industry Connect webinar for members and advisers.',
  ),

  // NOVEMBER 2026
  NationalCalendarEventSeed(
    id: 'national_2026_entrepreneurship_month',
    title: 'National Entrepreneurship Month',
    start: _day(2026, 11, 1),
    end: _lastDayOfMonth(2026, 11),
    description: 'November is National Entrepreneurship Month.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_nflc',
    title: 'National Fall Leadership Conference',
    start: _day(2026, 11, 5, 8),
    end: _day(2026, 11, 7, 17),
    location: 'Washington, D.C.',
    description: 'National Fall Leadership Conference in Washington, D.C.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_fall_lifesmarts_ends',
    title: 'Fall LifeSmarts Challenge Ends',
    start: _day(2026, 11, 6),
    end: _endOfDay(2026, 11, 6),
    description: 'Final day of the Fall LifeSmarts Challenge (Oct 12 – Nov 6, 2026).',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_fall_vbc_ends',
    title: 'Fall Virtual Business Challenge Ends',
    start: _day(2026, 11, 6),
    end: _endOfDay(2026, 11, 6),
    description: 'Final day of the Fall Virtual Business Challenge (Oct 13 – Nov 6, 2026).',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_dressed_to_impress_scholarship',
    title: 'Dressed to Impress Scholarship Application Deadline',
    start: _day(2026, 11, 15),
    end: _endOfDay(2026, 11, 15),
    description: 'Application deadline for the Dressed to Impress Scholarship.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_education_week',
    title: 'National Education Week',
    start: _day(2026, 11, 16),
    end: _day(2026, 11, 20, 17),
    description: 'National Education Week, November 16–20, 2026.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_entrepreneurship_day',
    title: 'National Entrepreneurship Day',
    start: _day(2026, 11, 17),
    end: _endOfDay(2026, 11, 17),
    description: 'National Entrepreneurship Day.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_industry_connect_nov',
    title: 'Industry Connect Webinar',
    start: _day(2026, 11, 18, 18),
    end: _day(2026, 11, 18, 19, 30),
    location: 'Virtual',
    description: 'FBLA Industry Connect webinar for members and advisers.',
  ),

  // DECEMBER 2026
  NationalCalendarEventSeed(
    id: 'national_2026_giving_tuesday',
    title: 'Giving Tuesday',
    start: _day(2026, 12, 1),
    end: _endOfDay(2026, 12, 1),
    description: 'Giving Tuesday national day of generosity.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_fall_stock_market_ends',
    title: 'Fall Stock Market Game Ends',
    start: _day(2026, 12, 13),
    end: _endOfDay(2026, 12, 13),
    description: 'Final day of the Fall Stock Market Game (Oct 5 – Dec 13, 2026).',
  ),
  NationalCalendarEventSeed(
    id: 'national_2026_winter_break',
    title: 'National Center Closed for Winter Break',
    start: _day(2026, 12, 24),
    end: _day(2027, 1, 1, 17),
    location: 'FBLA National Center',
    description: 'FBLA National Center closed December 24, 2026 – January 1, 2027.',
  ),

  // JANUARY 2027
  NationalCalendarEventSeed(
    id: 'national_2027_champion_chapter_service_deadline',
    title: 'Champion Chapter Service Season Submission Deadline',
    start: _day(2027, 1, 7),
    end: _endOfDay(2027, 1, 7),
    description: 'Deadline for Champion Chapter service season submissions.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_industry_connect_jan',
    title: 'Industry Connect Webinar',
    start: _day(2027, 1, 20, 18),
    end: _day(2027, 1, 20, 19, 30),
    location: 'Virtual',
    description: 'FBLA Industry Connect webinar for members and advisers.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_spring_lifesmarts_begins',
    title: 'Spring LifeSmarts Challenge Begins',
    start: _day(2027, 1, 25),
    end: _day(2027, 2, 19, 17),
    description: 'Spring LifeSmarts Challenge runs January 25 – February 19, 2027.',
  ),

  // FEBRUARY 2027
  NationalCalendarEventSeed(
    id: 'national_2027_cte_month',
    title: 'National Career & Technical Education Month',
    start: _day(2027, 2, 1),
    end: _lastDayOfMonth(2027, 2),
    description: 'February is National Career & Technical Education Month.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_spring_vbc_begins',
    title: 'Spring Virtual Business Challenge Begins',
    start: _day(2027, 2, 1),
    end: _day(2027, 2, 26, 17),
    description: 'Spring Virtual Business Challenge runs February 1 – February 26, 2027.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_spring_stock_market_begins',
    title: 'Spring Stock Market Game Begins',
    start: _day(2027, 2, 1),
    end: _day(2027, 4, 9, 17),
    description: 'Spring Stock Market Game runs February 1 – April 9, 2027.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_fbla_week',
    title: 'FBLA Week',
    start: _day(2027, 2, 7),
    end: _day(2027, 2, 13, 17),
    description: 'Celebrate FBLA Week, February 7–13, 2027.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_industry_connect_feb',
    title: 'Industry Connect Webinar',
    start: _day(2027, 2, 17, 18),
    end: _day(2027, 2, 17, 19, 30),
    location: 'Virtual',
    description: 'FBLA Industry Connect webinar for members and advisers.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_spring_lifesmarts_ends',
    title: 'Spring LifeSmarts Challenge Ends',
    start: _day(2027, 2, 19),
    end: _endOfDay(2027, 2, 19),
    description: 'Final day of the Spring LifeSmarts Challenge (Jan 25 – Feb 19, 2027).',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_spring_vbc_ends',
    title: 'Spring Virtual Business Challenge Ends',
    start: _day(2027, 2, 26),
    end: _endOfDay(2027, 2, 26),
    description: 'Final day of the Spring Virtual Business Challenge (Feb 1 – Feb 26, 2027).',
  ),

  // MARCH 2027
  NationalCalendarEventSeed(
    id: 'national_2027_nlc_dues_deadline',
    title: 'Membership Dues Payment Deadline for NLC Competitors',
    start: _day(2027, 3, 1),
    end: _endOfDay(2027, 3, 1),
    description: 'Membership dues must be paid for students competing at NLC.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_nlc_workshop_cfp_close',
    title: 'NLC Workshop Call for Presenters Closes',
    start: _day(2027, 3, 1),
    end: _endOfDay(2027, 3, 1),
    description: 'Deadline for NLC workshop presenter proposals.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_champion_chapter_cte_deadline',
    title: 'Champion Chapter CTE Celebration Submission Deadline',
    start: _day(2027, 3, 4),
    end: _endOfDay(2027, 3, 4),
    description: 'Deadline for Champion Chapter CTE Celebration submissions.',
  ),

  // APRIL 2027
  NationalCalendarEventSeed(
    id: 'national_2027_financial_literacy_month',
    title: 'National Financial Literacy Month',
    start: _day(2027, 4, 1),
    end: _lastDayOfMonth(2027, 4),
    description: 'April is National Financial Literacy Month.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_bylaws_amendment_deadline',
    title: 'National Bylaws Amendment Proposal Submission Deadline',
    start: _day(2027, 4, 1),
    end: _endOfDay(2027, 4, 1),
    description: 'Deadline to submit national bylaws amendment proposals.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_spring_stock_market_ends',
    title: 'Spring Stock Market Game Ends',
    start: _day(2027, 4, 9),
    end: _endOfDay(2027, 4, 9),
    description: 'Final day of the Spring Stock Market Game (Feb 1 – Apr 9, 2027).',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_nlc_scholarship_deadline',
    title: 'NLC Scholarship Deadline',
    start: _day(2027, 4, 15),
    end: _endOfDay(2027, 4, 15),
    description: 'Application deadline for NLC scholarships.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_nths_scholarship_deadline',
    title: 'NTHS Scholarship Deadline',
    start: _day(2027, 4, 15),
    end: _endOfDay(2027, 4, 15),
    description: 'Application deadline for NTHS scholarships.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_distinguished_leader_scholarship',
    title: 'Distinguished Business Leader Scholarship Deadline',
    start: _day(2027, 4, 15),
    end: _endOfDay(2027, 4, 15),
    description: 'Application deadline for the Distinguished Business Leader Scholarship.',
  ),

  // MAY 2027
  NationalCalendarEventSeed(
    id: 'national_2027_champion_chapter_may_deadline',
    title: 'Champion Chapter Submission Deadline',
    start: _day(2027, 5, 1),
    end: _endOfDay(2027, 5, 1),
    description: 'Champion Chapter submission deadline.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_baa_excellence_nlc_deadline',
    title: 'BAA & Excellence Award Submission Deadline for NLC Recognition',
    start: _day(2027, 5, 1),
    end: _endOfDay(2027, 5, 1),
    description: 'Deadline for BAA and Excellence Award submissions for NLC recognition.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_nlc_registration_deadline',
    title: 'NLC Registration & Housing Deadline',
    start: _day(2027, 5, 4),
    end: _endOfDay(2027, 5, 4),
    description: 'Registration and housing deadline for the National Leadership Conference.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_nlc_events_verification',
    title: 'NLC Competitive Events Verification for State Leaders',
    start: _day(2027, 5, 7),
    end: _endOfDay(2027, 5, 7),
    description: 'State leaders verify NLC competitive event entries.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_adviser_wall_of_fame',
    title: 'Adviser Wall of Fame Nomination Deadline',
    start: _day(2027, 5, 7),
    end: _endOfDay(2027, 5, 7),
    description: 'Nomination deadline for the Adviser Wall of Fame.',
  ),

  // JUNE 2027
  NationalCalendarEventSeed(
    id: 'national_2027_champion_chapter_june_deadline',
    title: 'Champion Chapter Submission Deadline',
    start: _day(2027, 6, 1),
    end: _endOfDay(2027, 6, 1),
    description: 'Final Champion Chapter submission deadline.',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_lead4change_closes',
    title: 'Lead4Change Grant Cycle Closes',
    start: _day(2027, 6, 1),
    end: _endOfDay(2027, 6, 1),
    description: 'Lead4Change grant cycle closes (Oct 1, 2026 – June 1, 2027).',
  ),
  NationalCalendarEventSeed(
    id: 'national_2027_nlc',
    title: 'National Leadership Conference',
    start: _day(2027, 6, 23, 8),
    end: _day(2027, 6, 26, 17),
    location: 'Columbus, OH',
    description:
        'FBLA National Leadership Conference in Columbus, Ohio. Compete, attend workshops, and network nationwide.',
  ),
];
