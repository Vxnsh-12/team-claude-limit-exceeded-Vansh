/// Mock translation dictionary used across the VIT Quest super app.
///
/// Keeps things intentionally lightweight – no `intl` / `.arb` / codegen.
/// Consumers call `AppTranslations.t(langCode, key)` and get back either the
/// matching string or the English fallback.
class AppTranslations {
  static const supported = ['en', 'hi', 'te'];

  static const Map<String, Map<String, String>> _dict = {
    'en': {
      'app_title': 'VIT Quest',
      'navigate': 'Navigate',
      'squad': 'Squad',
      'hub': 'Campus Hub',
      'opportunities': 'Opportunities',
      'profile': 'Profile',
      'lang_english': 'English',
      'lang_hindi': 'हिन्दी',
      'lang_telugu': 'తెలుగు',
      'report_disruption': 'Report Disruption',
      'report_hint': 'Help others by reporting a blocked path, flood, or construction on campus.',
      'take_photo': 'Take Photo',
      'photo_captured': 'Photo captured',
      'submit': 'Submit',
      'cancel': 'Cancel',
      'placeholder_soon': 'Coming soon',
      'squad_desc': 'Meet up with friends, share your live pin, and squad-route to shared destinations.',
      'hub_desc': 'Campus events, class timetable, and official announcements — all in one place.',
      'opps_desc': 'Internships, hackathons, and campus offers curated for VIT students.',
      'profile_desc': 'Your quests, XP, badges, and streaks live here.',
      'report_success': 'Disruption reported — your route is being updated.',
      'waiting_location': 'Waiting for GPS to report location…',
    },
    'hi': {
      'app_title': 'VIT क्वेस्ट',
      'navigate': 'नेविगेट',
      'squad': 'दस्ता',
      'hub': 'कैंपस हब',
      'opportunities': 'अवसर',
      'profile': 'प्रोफ़ाइल',
      'lang_english': 'English',
      'lang_hindi': 'हिन्दी',
      'lang_telugu': 'తెలుగు',
      'report_disruption': 'बाधा रिपोर्ट करें',
      'report_hint': 'अवरुद्ध रास्ते, बाढ़ या निर्माण की रिपोर्ट कर दूसरों की मदद करें।',
      'take_photo': 'फ़ोटो लें',
      'photo_captured': 'फ़ोटो लिया गया',
      'submit': 'भेजें',
      'cancel': 'रद्द करें',
      'placeholder_soon': 'जल्द आ रहा है',
      'squad_desc': 'दोस्तों से मिलें, अपना लाइव लोकेशन शेयर करें, और साथ में रूट बनाएँ।',
      'hub_desc': 'कैंपस इवेंट्स, टाइमटेबल और सूचनाएँ — एक ही जगह।',
      'opps_desc': 'VIT छात्रों के लिए इंटर्नशिप, हैकाथॉन और कैंपस ऑफ़र।',
      'profile_desc': 'आपकी क्वेस्ट, XP, बैज और स्ट्रीक यहाँ।',
      'report_success': 'बाधा रिपोर्ट कर दी गई — रास्ता अपडेट हो रहा है।',
      'waiting_location': 'GPS से लोकेशन का इंतज़ार…',
    },
    'te': {
      'app_title': 'VIT క్వెస్ట్',
      'navigate': 'నావిగేట్',
      'squad': 'స్క్వాడ్',
      'hub': 'క్యాంపస్ హబ్',
      'opportunities': 'అవకాశాలు',
      'profile': 'ప్రొఫైల్',
      'lang_english': 'English',
      'lang_hindi': 'हिन्दी',
      'lang_telugu': 'తెలుగు',
      'report_disruption': 'అంతరాయాన్ని నివేదించండి',
      'report_hint': 'మూసిన మార్గాలు, వరదలు లేదా నిర్మాణాలను నివేదించడం ద్వారా ఇతరులకు సహాయపడండి.',
      'take_photo': 'ఫోటో తీయండి',
      'photo_captured': 'ఫోటో తీయబడింది',
      'submit': 'సమర్పించండి',
      'cancel': 'రద్దు చేయండి',
      'placeholder_soon': 'త్వరలో వస్తుంది',
      'squad_desc': 'స్నేహితులను కలవండి, లైవ్ లొకేషన్ షేర్ చేయండి, కలిసి రూట్ చేయండి.',
      'hub_desc': 'క్యాంపస్ ఈవెంట్లు, టైమ్‌టేబుల్ మరియు ప్రకటనలు — ఒకే చోట.',
      'opps_desc': 'VIT విద్యార్థుల కోసం ఇంటర్న్‌షిప్‌లు, హ్యాకథాన్‌లు, ఆఫర్‌లు.',
      'profile_desc': 'మీ క్వెస్ట్‌లు, XP, బ్యాడ్జ్‌లు, స్ట్రీక్‌లు ఇక్కడ ఉన్నాయి.',
      'report_success': 'అంతరాయం నివేదించబడింది — మార్గం అప్‌డేట్ అవుతోంది.',
      'waiting_location': 'GPS లొకేషన్ కోసం వేచి ఉంది…',
    },
  };

  static String t(String lang, String key) =>
      _dict[lang]?[key] ?? _dict['en']?[key] ?? key;

  static String label(String code) {
    switch (code) {
      case 'hi':
        return 'हिन्दी';
      case 'te':
        return 'తెలుగు';
      default:
        return 'English';
    }
  }
}
