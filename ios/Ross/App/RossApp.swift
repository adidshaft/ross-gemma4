import AuthenticationServices
import Foundation
import LocalAuthentication
import Security
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
final class RossAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        AlphaBackgroundModelDownloadCenter.shared.setBackgroundCompletionHandler(
            completionHandler,
            for: identifier
        )
    }
}
#endif

// MARK: - Language Preference

private let rossLanguageSelectedKey = "ross.language.selected"
private let rossSelectedLanguageCodeKey = "ross.language.code"
private let rossQuickUnlockEnabledKey = "ross.quick_unlock.enabled"
private let rossBackendBaseURLOverrideKey = "ross.backend.base_url.override"

func rossHasSelectedLanguage() -> Bool {
    UserDefaults.standard.bool(forKey: rossLanguageSelectedKey)
}

func rossSaveLanguageSelection(code: String) {
    UserDefaults.standard.set(true, forKey: rossLanguageSelectedKey)
    UserDefaults.standard.set(code, forKey: rossSelectedLanguageCodeKey)
}

func rossSelectedLanguageCode() -> String {
    UserDefaults.standard.string(forKey: rossSelectedLanguageCodeKey) ?? "en"
}

func rossLanguageDisplayName(code: String) -> String {
    switch code {
    case "en": "English"
    case "hi": "Hindi"
    case "ta": "Tamil"
    case "te": "Telugu"
    case "kn": "Kannada"
    case "ml": "Malayalam"
    case "mr": "Marathi"
    case "bn": "Bengali"
    default: code.uppercased()
    }
}

struct RossLanguageOption: Identifiable, Hashable {
    let id: String  // language code
    let nativeName: String
    let englishName: String
}

let rossLanguageOptions: [RossLanguageOption] = [
    RossLanguageOption(id: "en", nativeName: "English", englishName: "English"),
    RossLanguageOption(id: "hi", nativeName: "हिन्दी", englishName: "Hindi"),
    RossLanguageOption(id: "bn", nativeName: "বাংলা", englishName: "Bengali"),
    RossLanguageOption(id: "ta", nativeName: "தமிழ்", englishName: "Tamil"),
    RossLanguageOption(id: "te", nativeName: "తెలుగు", englishName: "Telugu")
]

func rossSupportedLanguageCodes() -> [String] {
    rossLanguageOptions.map(\.id)
}

func rossLocalized(_ key: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    let normalizedCode = languageCode.split(separator: "-").first.map(String.init) ?? languageCode
    let table: [String: [String: String]] = [
        "choose_language_title": [
            "en": "Choose your preferred language",
            "hi": "अपनी पसंदीदा भाषा चुनें",
            "bn": "আপনার পছন্দের ভাষা বেছে নিন",
            "ta": "உங்கள் விருப்ப மொழியைத் தேர்வுசெய்யவும்",
            "te": "మీకు ఇష్టమైన భాషను ఎంచుకోండి"
        ],
        "choose_language_detail": [
            "en": "Ross can answer in this language where supported.",
            "hi": "जहाँ समर्थित हो, Ross इसी भाषा में उत्तर दे सकता है।",
            "bn": "যেখানে সমর্থিত, Ross এই ভাষায় উত্তর দিতে পারে।",
            "ta": "ஆதரவு உள்ள இடங்களில் Ross இந்த மொழியில் பதிலளிக்கும்.",
            "te": "మద్దతు ఉన్న చోట Ross ఈ భాషలో సమాధానం ఇస్తుంది."
        ],
        "continue": [
            "en": "Continue",
            "hi": "जारी रखें",
            "bn": "চালিয়ে যান",
            "ta": "தொடரவும்",
            "te": "కొనసాగించండి"
        ],
        "private_legal_work": [
            "en": "Private legal work.\nOn this phone.",
            "hi": "निजी कानूनी काम।\nइसी फ़ोन पर।",
            "bn": "ব্যক্তিগত আইনি কাজ।\nএই ফোনেই।",
            "ta": "தனிப்பட்ட சட்ட வேலை.\nஇந்த தொலைபேசியில்.",
            "te": "వ్యక్తిగత న్యాయ పని.\nఈ ఫోన్‌లో."
        ],
        "matters_private": [
            "en": "Your matters stay private on this device.",
            "hi": "आपके मामले इसी डिवाइस पर निजी रहते हैं।",
            "bn": "আপনার মামলাগুলি এই ডিভাইসেই ব্যক্তিগত থাকে।",
            "ta": "உங்கள் வழக்குகள் இந்த சாதனத்தில் தனிப்பட்டதாக இருக்கும்.",
            "te": "మీ కేసులు ఈ పరికరంలోనే ప్రైవేట్‌గా ఉంటాయి."
        ],
        "private_legal_work_splash": [
            "en": "Private legal work, on this phone.",
            "hi": "निजी कानूनी काम, इसी फ़ोन पर।",
            "bn": "ব্যক্তিগত আইনি কাজ, এই ফোনেই।",
            "ta": "தனிப்பட்ட சட்ட வேலை, இந்த தொலைபேசியில்.",
            "te": "వ్యక్తిగత న్యాయ పని, ఈ ఫోన్‌లో."
        ],
        "get_started": [
            "en": "Get Started",
            "hi": "शुरू करें",
            "bn": "শুরু করুন",
            "ta": "தொடங்கவும்",
            "te": "ప్రారంభించండి"
        ],
        "choose_workspace": [
            "en": "Choose a private workspace.",
            "hi": "निजी कार्यस्थान चुनें।",
            "bn": "একটি ব্যক্তিগত কর্মক্ষেত্র বেছে নিন।",
            "ta": "ஒரு தனிப்பட்ட பணியிடத்தைத் தேர்வுசெய்யவும்.",
            "te": "ప్రైవేట్ వర్క్‌స్పేస్ ఎంచుకోండి."
        ],
        "tap_to_sign_in": [
            "en": "Tap to sign in.",
            "hi": "साइन इन करने के लिए टैप करें।",
            "bn": "সাইন ইন করতে ট্যাপ করুন।",
            "ta": "உள்நுழைய தட்டவும்.",
            "te": "సైన్ ఇన్ చేయడానికి నొక్కండి."
        ],
        "continue_email": [
            "en": "Continue with email",
            "hi": "ईमेल से जारी रखें",
            "bn": "ইমেল দিয়ে চালিয়ে যান",
            "ta": "மின்னஞ்சலுடன் தொடரவும்",
            "te": "ఇమెయిల్‌తో కొనసాగండి"
        ],
        "email_subtitle": [
            "en": "Sample matter or empty workspace",
            "hi": "नमूना मामला या खाली कार्यस्थान",
            "bn": "নমুনা মামলা বা খালি কর্মক্ষেত্র",
            "ta": "மாதிரி வழக்கு அல்லது காலியான பணியிடம்",
            "te": "నమూనా కేసు లేదా ఖాళీ వర్క్‌స్పేస్"
        ],
        "email_access": [
            "en": "Email access",
            "hi": "Email access",
            "bn": "Email access",
            "ta": "Email access",
            "te": "Email access"
        ],
        "connecting_to_google": [
            "en": "Connecting to Google",
            "hi": "Google से connect हो रहा है",
            "bn": "Google-এর সঙ্গে connect হচ্ছে",
            "ta": "Google உடன் connect ஆகிறது",
            "te": "Google కు connect అవుతోంది"
        ],
        "continue_with_google": [
            "en": "Continue with Google",
            "hi": "Google से जारी रखें",
            "bn": "Google দিয়ে চালিয়ে যান",
            "ta": "Google உடன் தொடரவும்",
            "te": "Google తో కొనసాగండి"
        ],
        "connecting_to_apple": [
            "en": "Connecting to Apple",
            "hi": "Apple से connect हो रहा है",
            "bn": "Apple-এর সঙ্গে connect হচ্ছে",
            "ta": "Apple உடன் connect ஆகிறது",
            "te": "Apple కు connect అవుతోంది"
        ],
        "continue_with_apple": [
            "en": "Continue with Apple",
            "hi": "Apple से जारी रखें",
            "bn": "Apple দিয়ে চালিয়ে যান",
            "ta": "Apple உடன் தொடரவும்",
            "te": "Apple తో కొనసాగండి"
        ],
        "demo_data_sample_only": [
            "en": "Demo data is sample only.",
            "hi": "Demo data सिर्फ sample है।",
            "bn": "Demo data শুধু sample.",
            "ta": "Demo data sample மட்டும்.",
            "te": "Demo data sample మాత్రమే."
        ],
        "unlocking_ross": [
            "en": "Unlocking Ross",
            "hi": "Ross unlock हो रहा है",
            "bn": "Ross unlock হচ্ছে",
            "ta": "Ross unlock ஆகிறது",
            "te": "Ross unlock అవుతోంది"
        ],
        "workspace_locked": [
            "en": "Workspace locked",
            "hi": "Workspace locked है",
            "bn": "Workspace locked",
            "ta": "Workspace locked",
            "te": "Workspace locked"
        ],
        "ross_is_locked": [
            "en": "Ross is locked",
            "hi": "Ross locked है",
            "bn": "Ross locked",
            "ta": "Ross locked",
            "te": "Ross locked"
        ],
        "use_unlock_to_continue": [
            "en": "Use %@ to continue.",
            "hi": "जारी रखने के लिए %@ इस्तेमाल करें।",
            "bn": "চালিয়ে যেতে %@ ব্যবহার করুন।",
            "ta": "தொடர %@ பயன்படுத்தவும்.",
            "te": "కొనసాగడానికి %@ ఉపయోగించండి."
        ],
        "sign_out": [
            "en": "Sign out",
            "hi": "Sign out",
            "bn": "Sign out",
            "ta": "Sign out",
            "te": "Sign out"
        ],
        "account": [
            "en": "Account",
            "hi": "Account",
            "bn": "Account",
            "ta": "Account",
            "te": "Account"
        ],
        "signed_in_as": [
            "en": "Signed in as",
            "hi": "Signed in as",
            "bn": "Signed in as",
            "ta": "Signed in as",
            "te": "Signed in as"
        ],
        "language": [
            "en": "Language",
            "hi": "भाषा",
            "bn": "ভাষা",
            "ta": "மொழி",
            "te": "భాష"
        ],
        "use_device_unlock": [
            "en": "Use device unlock",
            "hi": "device unlock use करें",
            "bn": "device unlock use করুন",
            "ta": "device unlock use செய்யவும்",
            "te": "device unlock use చేయండి"
        ],
        "device_unlock_enabled_detail": [
            "en": "Ross asks for device unlock when you come back.",
            "hi": "आप वापस आते हैं तो Ross device unlock मांगता है।",
            "bn": "আপনি ফিরে এলে Ross device unlock চায়।",
            "ta": "நீங்கள் திரும்பி வரும்போது Ross device unlock கேட்கும்.",
            "te": "మీరు తిరిగి వచ్చినప్పుడు Ross device unlock అడుగుతుంది."
        ],
        "device_unlock_disabled_detail": [
            "en": "Turn this on to reopen Ross with Face ID, Touch ID, or device passcode.",
            "hi": "Face ID, Touch ID, या device passcode से Ross reopen करने के लिए इसे on करें।",
            "bn": "Face ID, Touch ID, বা device passcode দিয়ে Ross reopen করতে এটি on করুন।",
            "ta": "Face ID, Touch ID அல்லது device passcode மூலம் Ross reopen செய்ய இதை on செய்யவும்.",
            "te": "Face ID, Touch ID, లేదా device passcode తో Ross reopen చేయడానికి దీన్ని on చేయండి."
        ],
        "unlock": [
            "en": "Unlock",
            "hi": "Unlock",
            "bn": "Unlock",
            "ta": "Unlock",
            "te": "Unlock"
        ],
        "quick_unlock_unavailable_detail": [
            "en": "Quick unlock is not available on this device.",
            "hi": "Quick unlock इस device पर available नहीं है।",
            "bn": "Quick unlock এই device-এ available নয়।",
            "ta": "Quick unlock இந்த device-இல் available இல்லை.",
            "te": "Quick unlock ఈ device లో available కాదు."
        ],
        "reset_demo_data": [
            "en": "Reset demo data",
            "hi": "demo data reset करें",
            "bn": "demo data reset করুন",
            "ta": "demo data reset செய்யவும்",
            "te": "demo data reset చేయండి"
        ],
        "reset_demo_data_detail": [
            "en": "Restore the sample matter, tasks, files, and review items.",
            "hi": "sample matter, tasks, files, और review items restore करें।",
            "bn": "sample matter, tasks, files, এবং review items restore করুন।",
            "ta": "sample matter, tasks, files மற்றும் review items restore செய்யவும்.",
            "te": "sample matter, tasks, files, మరియు review items restore చేయండి."
        ],
        "demo_matter_sample_data_only": [
            "en": "Demo matter uses sample data only.",
            "hi": "Demo matter सिर्फ sample data use करता है।",
            "bn": "Demo matter শুধু sample data ব্যবহার করে।",
            "ta": "Demo matter sample data மட்டும் பயன்படுத்தும்.",
            "te": "Demo matter sample data మాత్రమే ఉపయోగిస్తుంది."
        ],
        "sign_out_of_ross_question": [
            "en": "Sign out of Ross?",
            "hi": "Ross से sign out करें?",
            "bn": "Ross থেকে sign out করবেন?",
            "ta": "Ross-இலிருந்து sign out செய்யவா?",
            "te": "Ross నుండి sign out చేయాలా?"
        ],
        "sign_out_destructive": [
            "en": "Sign Out",
            "hi": "Sign Out",
            "bn": "Sign Out",
            "ta": "Sign Out",
            "te": "Sign Out"
        ],
        "sign_out_local_detail": [
            "en": "This removes the local sign-in from this device until you sign in again.",
            "hi": "दोबारा sign in करने तक यह इस device से local sign-in हटाता है।",
            "bn": "আবার sign in না করা পর্যন্ত এটি এই device থেকে local sign-in সরিয়ে দেয়।",
            "ta": "நீங்கள் மீண்டும் sign in செய்யும் வரை இது இந்த device-இலிருந்து local sign-in-ஐ நீக்கும்.",
            "te": "మళ్లీ sign in చేసే వరకు ఇది ఈ device నుండి local sign-in ను తొలగిస్తుంది."
        ],
        "setup_assistant": [
            "en": "Set up assistant",
            "hi": "सहायक सेट करें",
            "bn": "সহকারী সেট আপ করুন",
            "ta": "உதவியாளரை அமைக்கவும்",
            "te": "సహాయకుడిని సెటప్ చేయండి"
        ],
        "download_setup_ross": [
            "en": "Download & set up Ross",
            "hi": "Ross डाउनलोड और सेट करें",
            "bn": "Ross ডাউনলোড করে সেট আপ করুন",
            "ta": "Ross-ஐ பதிவிறக்கி அமைக்கவும்",
            "te": "Ross డౌన్‌లోడ్ చేసి సెటప్ చేయండి"
        ],
        "private_legal_workbench": [
            "en": "Your private legal workbench.",
            "hi": "आपका निजी कानूनी कार्यक्षेत्र।",
            "bn": "আপনার ব্যক্তিগত আইনি কর্মক্ষেত্র।",
            "ta": "உங்கள் தனிப்பட்ட சட்ட பணிமனை.",
            "te": "మీ ప్రైవేట్ న్యాయ వర్క్‌బెంచ్."
        ],
        "choose_private_assistant": [
            "en": "Choose private assistant",
            "hi": "निजी सहायक चुनें",
            "bn": "ব্যক্তিগত সহকারী বেছে নিন",
            "ta": "தனிப்பட்ட உதவியாளரைத் தேர்வுசெய்க",
            "te": "ప్రైవేట్ సహాయకుడిని ఎంచుకోండి"
        ],
        "choose_your_private_assistant": [
            "en": "Choose your private assistant",
            "hi": "अपना निजी सहायक चुनें",
            "bn": "আপনার ব্যক্তিগত সহকারী বেছে নিন",
            "ta": "உங்கள் தனிப்பட்ட உதவியாளரைத் தேர்வுசெய்க",
            "te": "మీ ప్రైవేట్ సహాయకుడిని ఎంచుకోండి"
        ],
        "assistant_picker_detail": [
            "en": "Every option runs fully on this device. Larger assistants take longer to download and can handle deeper work.",
            "hi": "हर विकल्प पूरी तरह इसी डिवाइस पर चलता है। बड़े सहायक डाउनलोड में अधिक समय लेते हैं और गहरे काम संभाल सकते हैं।",
            "bn": "প্রতিটি বিকল্প সম্পূর্ণভাবে এই ডিভাইসে চলে। বড় সহকারী ডাউনলোড হতে বেশি সময় নেয় এবং গভীর কাজ সামলাতে পারে।",
            "ta": "ஒவ்வொரு விருப்பமும் இந்த சாதனத்திலேயே முழுமையாக இயங்கும். பெரிய உதவியாளர்கள் பதிவிறக்க அதிக நேரம் எடுத்து ஆழமான பணிகளை கையாளலாம்.",
            "te": "ప్రతి ఎంపిక పూర్తిగా ఈ పరికరంలోనే నడుస్తుంది. పెద్ద సహాయకులు డౌన్‌లోడ్‌కు ఎక్కువ సమయం తీసుకుని లోతైన పనిని నిర్వహించగలరు."
        ],
        "assistant_picker_later": [
            "en": "You can change this later in Settings, then My assistant.",
            "hi": "बाद में Settings में, फिर My assistant में इसे बदल सकते हैं।",
            "bn": "পরে Settings-এ, তারপর My assistant-এ এটি বদলাতে পারবেন।",
            "ta": "பின்னர் Settings-இல், அதன் பின் My assistant-இல் இதை மாற்றலாம்.",
            "te": "తర్వాత Settings లో, ఆపై My assistant లో దీన్ని మార్చవచ్చు."
        ],
        "skip_for_now": [
            "en": "Skip for now",
            "hi": "अभी छोड़ें",
            "bn": "এখন এড়িয়ে যান",
            "ta": "இப்போது தவிர்க்கவும்",
            "te": "ఇప్పటికి దాటవేయండి"
        ],
        "recommended": [
            "en": "Recommended",
            "hi": "सुझाया गया",
            "bn": "প্রস্তাবিত",
            "ta": "பரிந்துரைக்கப்பட்டது",
            "te": "సిఫార్సు"
        ],
        "recommended_for_device": [
            "en": "Recommended for your device",
            "hi": "आपके डिवाइस के लिए सुझाया गया",
            "bn": "আপনার ডিভাইসের জন্য প্রস্তাবিত",
            "ta": "உங்கள் சாதனத்துக்கு பரிந்துரைக்கப்பட்டது",
            "te": "మీ పరికరానికి సిఫార్సు"
        ],
        "download_size": [
            "en": "Download size",
            "hi": "डाउनलोड आकार",
            "bn": "ডাউনলোড আকার",
            "ta": "பதிவிறக்க அளவு",
            "te": "డౌన్‌లోడ్ పరిమాణం"
        ],
        "on_fast_wifi": [
            "en": "On fast Wi-Fi",
            "hi": "तेज Wi-Fi पर",
            "bn": "দ্রুত Wi-Fi-এ",
            "ta": "வேகமான Wi-Fi-இல்",
            "te": "వేగమైన Wi-Fi పై"
        ],
        "wifi_setup_advisory": [
            "en": "Connect to Wi-Fi for the fastest setup. The download resumes automatically if interrupted.",
            "hi": "सबसे तेज़ सेटअप के लिए Wi-Fi से जुड़ें। बीच में रुकने पर डाउनलोड अपने-आप फिर शुरू होगा।",
            "bn": "সবচেয়ে দ্রুত সেটআপের জন্য Wi-Fi-এ যুক্ত থাকুন। বাধা পড়লে ডাউনলোড নিজে থেকেই আবার শুরু হবে।",
            "ta": "வேகமான அமைப்புக்கு Wi-Fi-இல் இணையுங்கள். இடைநிறுத்தப்பட்டால் பதிவிறக்கம் தானாகத் தொடரும்.",
            "te": "వేగమైన సెటప్ కోసం Wi-Fi కు కనెక్ట్ అవ్వండి. మధ్యలో ఆగితే డౌన్‌లోడ్ స్వయంగా కొనసాగుతుంది."
        ],
        "setup_note_local_title": [
            "en": "Works locally on this device",
            "hi": "इसी डिवाइस पर स्थानीय रूप से काम करता है",
            "bn": "এই ডিভাইসেই স্থানীয়ভাবে কাজ করে",
            "ta": "இந்த சாதனத்திலேயே உள்ளூராக வேலை செய்கிறது",
            "te": "ఈ పరికరంలోనే స్థానికంగా పనిచేస్తుంది"
        ],
        "setup_note_local_detail": [
            "en": "Matter files and assistant work stay on this phone.",
            "hi": "मामले की फ़ाइलें और सहायक का काम इसी फ़ोन पर रहते हैं।",
            "bn": "মামলার ফাইল এবং সহকারীর কাজ এই ফোনেই থাকে।",
            "ta": "வழக்கு கோப்புகளும் உதவியாளர் பணியும் இந்த தொலைபேசியிலேயே இருக்கும்.",
            "te": "కేసు ఫైళ్లు మరియు సహాయకుడి పని ఈ ఫోన్‌లోనే ఉంటాయి."
        ],
        "setup_note_wifi_title": [
            "en": "Use Wi-Fi for assistant setup",
            "hi": "सहायक सेटअप के लिए Wi-Fi उपयोग करें",
            "bn": "সহকারী সেটআপে Wi-Fi ব্যবহার করুন",
            "ta": "உதவியாளர் அமைப்புக்கு Wi-Fi பயன்படுத்தவும்",
            "te": "సహాయకుడి సెటప్‌కు Wi-Fi ఉపయోగించండి"
        ],
        "setup_note_wifi_detail": [
            "en": "Large downloads can pause and resume if interrupted.",
            "hi": "बड़े डाउनलोड रुक सकते हैं और बाधा के बाद फिर शुरू हो सकते हैं।",
            "bn": "বড় ডাউনলোড থামতে পারে এবং বাধা পড়লে আবার শুরু হতে পারে।",
            "ta": "பெரிய பதிவிறக்கங்கள் இடைநிறுத்தப்பட்டால் மீண்டும் தொடரலாம்.",
            "te": "పెద్ద డౌన్‌లోడ్‌లు ఆగి, అంతరాయం కలిగితే మళ్లీ కొనసాగవచ్చు."
        ],
        "tier_flash_summary": [
            "en": "Fastest setup for quick questions and simple checklists.",
            "hi": "त्वरित प्रश्नों और सरल चेकलिस्ट के लिए सबसे तेज़ सेटअप।",
            "bn": "দ্রুত প্রশ্ন এবং সহজ চেকলিস্টের জন্য দ্রুততম সেটআপ।",
            "ta": "விரைவான கேள்விகளுக்கும் எளிய சரிபார்ப்பு பட்டியல்களுக்கும் வேகமான அமைப்பு.",
            "te": "త్వరిత ప్రశ్నలు మరియు సరళ చెక్‌లిస్ట్‌ల కోసం వేగమైన సెటప్."
        ],
        "tier_quick_start_summary": [
            "en": "Short orders, notices, and lighter document review.",
            "hi": "छोटे आदेश, नोटिस और हल्की दस्तावेज़ समीक्षा।",
            "bn": "ছোট আদেশ, নোটিস এবং হালকা নথি পর্যালোচনা।",
            "ta": "குறுகிய உத்தரவுகள், நோட்டீஸ்கள், எளிய ஆவண மதிப்பாய்வு.",
            "te": "చిన్న ఆదేశాలు, నోటీసులు మరియు తేలికపాటి పత్ర సమీక్ష."
        ],
        "tier_case_associate_summary": [
            "en": "Everyday matters, summaries, dates, and source-backed Ask.",
            "hi": "रोज़मर्रा के मामले, सारांश, तारीखें और स्रोत-आधारित Ask।",
            "bn": "দৈনন্দিন মামলা, সারাংশ, তারিখ এবং উৎস-সমর্থিত Ask।",
            "ta": "தினசரி வழக்குகள், சுருக்கங்கள், தேதிகள், மூல ஆதாரமுள்ள Ask.",
            "te": "రోజువారీ కేసులు, సారాంశాలు, తేదీలు మరియు మూల ఆధారిత Ask."
        ],
        "tier_senior_drafting_summary": [
            "en": "Long bundles, deeper review, hearing prep, and drafting.",
            "hi": "लंबे बंडल, गहरी समीक्षा, सुनवाई तैयारी और ड्राफ्टिंग।",
            "bn": "দীর্ঘ বান্ডিল, গভীর পর্যালোচনা, শুনানির প্রস্তুতি এবং খসড়া।",
            "ta": "நீண்ட தொகுப்புகள், ஆழமான மதிப்பாய்வு, விசாரணை தயாரிப்பு, வரைவு.",
            "te": "పెద్ద బండిళ్లు, లోతైన సమీక్ష, విచారణ సిద్ధత మరియు డ్రాఫ్టింగ్."
        ],
        "setup_warning_wifi": [
            "en": "Download about %@ before you begin. Wi-Fi is still the safest option.",
            "hi": "शुरू करने से पहले लगभग %@ डाउनलोड करें। Wi-Fi अब भी सबसे सुरक्षित विकल्प है।",
            "bn": "শুরু করার আগে প্রায় %@ ডাউনলোড করুন। Wi-Fi এখনও সবচেয়ে নিরাপদ বিকল্প।",
            "ta": "தொடங்குவதற்கு முன் சுமார் %@ பதிவிறக்கவும். Wi-Fi இன்னும் பாதுகாப்பான தேர்வு.",
            "te": "ప్రారంభించే ముందు సుమారు %@ డౌన్‌లోడ్ చేయండి. Wi-Fi ఇంకా సురక్షితమైన ఎంపిక."
        ],
        "setup_warning_storage": [
            "en": "Download about %@ before you begin. Keep this phone on Wi-Fi and make sure there is enough free space.",
            "hi": "शुरू करने से पहले लगभग %@ डाउनलोड करें। इस फ़ोन को Wi-Fi पर रखें और पर्याप्त खाली जगह सुनिश्चित करें।",
            "bn": "শুরু করার আগে প্রায় %@ ডাউনলোড করুন। এই ফোনটি Wi-Fi-এ রাখুন এবং পর্যাপ্ত খালি জায়গা আছে নিশ্চিত করুন।",
            "ta": "தொடங்குவதற்கு முன் சுமார் %@ பதிவிறக்கவும். இந்த தொலைபேசியை Wi-Fi-இல் வைத்திருந்து போதுமான காலி இடம் இருப்பதை உறுதிசெய்க.",
            "te": "ప్రారంభించే ముందు సుమారు %@ డౌన్‌లోడ్ చేయండి. ఈ ఫోన్‌ను Wi-Fi పై ఉంచి సరిపడా ఖాళీ స్థలం ఉందో చూసుకోండి."
        ],
        "setup_warning_large": [
            "en": "Download about %@ before you begin. Use strong Wi-Fi and check that this phone has plenty of free space.",
            "hi": "शुरू करने से पहले लगभग %@ डाउनलोड करें। मज़बूत Wi-Fi उपयोग करें और इस फ़ोन में पर्याप्त खाली जगह जांचें।",
            "bn": "শুরু করার আগে প্রায় %@ ডাউনলোড করুন। শক্তিশালী Wi-Fi ব্যবহার করুন এবং এই ফোনে পর্যাপ্ত খালি জায়গা আছে কিনা দেখুন।",
            "ta": "தொடங்குவதற்கு முன் சுமார் %@ பதிவிறக்கவும். வலுவான Wi-Fi பயன்படுத்தி இந்த தொலைபேசியில் போதுமான காலி இடம் உள்ளதா பார்க்கவும்.",
            "te": "ప్రారంభించే ముందు సుమారు %@ డౌన్‌లోడ్ చేయండి. బలమైన Wi-Fi ఉపయోగించి ఈ ఫోన్‌లో చాలినంత ఖాళీ స్థలం ఉందో చూడండి."
        ],
        "assistant": [
            "en": "Assistant",
            "hi": "सहायक",
            "bn": "সহকারী",
            "ta": "உதவியாளர்",
            "te": "సహాయకుడు"
        ],
        "cancel": [
            "en": "Cancel",
            "hi": "रद्द करें",
            "bn": "বাতিল",
            "ta": "ரத்து செய்",
            "te": "రద్దు"
        ],
        "canceled": [
            "en": "Canceled",
            "hi": "Canceled",
            "bn": "Canceled",
            "ta": "Canceled",
            "te": "Canceled"
        ],
        "legal_search_canceled_title": [
            "en": "Legal Search canceled",
            "hi": "Legal Search canceled",
            "bn": "Legal Search canceled",
            "ta": "Legal Search canceled",
            "te": "Legal Search canceled"
        ],
        "legal_search_canceled_detail": [
            "en": "No Legal Search was run. Ask again when you want Ross to use Legal Search.",
            "hi": "Legal Search नहीं चला। जब Ross से Legal Search use कराना हो, फिर पूछें।",
            "bn": "Legal Search চালানো হয়নি। Ross-কে Legal Search ব্যবহার করতে চাইলে আবার জিজ্ঞাসা করুন।",
            "ta": "Legal Search இயங்கவில்லை. Ross Legal Search பயன்படுத்த வேண்டும் என்றால் மீண்டும் கேளுங்கள்.",
            "te": "Legal Search నడవలేదు. Ross Legal Search ఉపయోగించాలని ఉన్నప్పుడు మళ్లీ అడగండి."
        ],
        "assistant_setup_phase_download": [
            "en": "Download",
            "hi": "डाउनलोड",
            "bn": "ডাউনলোড",
            "ta": "பதிவிறக்கம்",
            "te": "డౌన్‌లోడ్"
        ],
        "assistant_setup_phase_check": [
            "en": "Check",
            "hi": "जांच",
            "bn": "পরীক্ষা",
            "ta": "சரிபார்ப்பு",
            "te": "తనిఖీ"
        ],
        "assistant_setup_phase_ready": [
            "en": "Ready",
            "hi": "तैयार",
            "bn": "প্রস্তুত",
            "ta": "தயார்",
            "te": "సిద్ధం"
        ],
        "assistant_setup_paused_wifi": [
            "en": "Assistant setup paused at %@. Waiting for Wi-Fi.",
            "hi": "सहायक सेटअप %@ पर रुका है। Wi-Fi की प्रतीक्षा है।",
            "bn": "সহকারী সেটআপ %@ ধাপে থেমে আছে। Wi-Fi-এর জন্য অপেক্ষা করছে।",
            "ta": "உதவியாளர் அமைப்பு %@ நிலையில் இடைநிறுத்தப்பட்டுள்ளது. Wi-Fi காத்திருக்கிறது.",
            "te": "సహాయకుడి సెటప్ %@ వద్ద నిలిచింది. Wi-Fi కోసం వేచి ఉంది."
        ],
        "assistant_setup_paused_storage": [
            "en": "Assistant setup paused at %@. More device storage is needed.",
            "hi": "सहायक सेटअप %@ पर रुका है। और डिवाइस स्टोरेज चाहिए।",
            "bn": "সহকারী সেটআপ %@ ধাপে থেমে আছে। আরও ডিভাইস স্টোরেজ দরকার।",
            "ta": "உதவியாளர் அமைப்பு %@ நிலையில் இடைநிறுத்தப்பட்டுள்ளது. கூடுதல் சாதன சேமிப்பு தேவை.",
            "te": "సహాయకుడి సెటప్ %@ వద్ద నిలిచింది. మరింత పరికర నిల్వ అవసరం."
        ],
        "assistant_setup_paused": [
            "en": "Assistant setup paused at %@.",
            "hi": "सहायक सेटअप %@ पर रुका है।",
            "bn": "সহকারী সেটআপ %@ ধাপে থেমে আছে।",
            "ta": "உதவியாளர் அமைப்பு %@ நிலையில் இடைநிறுத்தப்பட்டுள்ளது.",
            "te": "సహాయకుడి సెటప్ %@ వద్ద నిలిచింది."
        ],
        "assistant_setup_retry": [
            "en": "Assistant setup needs retry at %@.",
            "hi": "सहायक सेटअप को %@ पर फिर से कोशिश चाहिए।",
            "bn": "সহকারী সেটআপ %@ ধাপে আবার চেষ্টা করতে হবে।",
            "ta": "உதவியாளர் அமைப்பை %@ நிலையில் மீண்டும் முயற்சிக்க வேண்டும்.",
            "te": "సహాయకుడి సెటప్‌ను %@ వద్ద మళ్లీ ప్రయత్నించాలి."
        ],
        "assistant_setup_complete": [
            "en": "Assistant setup complete. Ready.",
            "hi": "सहायक सेटअप पूरा। तैयार।",
            "bn": "সহকারী সেটআপ সম্পূর্ণ। প্রস্তুত।",
            "ta": "உதவியாளர் அமைப்பு முடிந்தது. தயார்.",
            "te": "సహాయకుడి సెటప్ పూర్తయింది. సిద్ధం."
        ],
        "assistant_setup_step": [
            "en": "Assistant setup step %@ of %@.",
            "hi": "सहायक सेटअप चरण %@, %@ में से।",
            "bn": "সহকারী সেটআপ ধাপ %@, %@ এর মধ্যে।",
            "ta": "உதவியாளர் அமைப்பு நிலை %@, %@ இல்.",
            "te": "సహాయకుడి సెటప్ దశ %@, %@ లో."
        ],
        "assistant_download_waiting_estimate": [
            "en": "Ross will update the estimate once the download starts moving.",
            "hi": "डाउनलोड आगे बढ़ते ही Ross अनुमान अपडेट करेगा।",
            "bn": "ডাউনলোড এগোতে শুরু করলে Ross অনুমান আপডেট করবে।",
            "ta": "பதிவிறக்கம் நகரத் தொடங்கியவுடன் Ross மதிப்பீட்டை புதுப்பிக்கும்.",
            "te": "డౌన్‌లోడ్ కదలడం ప్రారంభమైన వెంటనే Ross అంచనాను నవీకరిస్తుంది."
        ],
        "assistant_download_minutes_left": [
            "en": "Setting up. About %d min left on good Wi-Fi.",
            "hi": "सेटअप हो रहा है। अच्छे Wi-Fi पर लगभग %d मिनट बाकी।",
            "bn": "সেটআপ চলছে। ভালো Wi-Fi-এ প্রায় %d মিনিট বাকি।",
            "ta": "அமைப்பு நடக்கிறது. நல்ல Wi-Fi-இல் சுமார் %d நிமிடம் மீதம்.",
            "te": "సెటప్ జరుగుతోంది. మంచి Wi-Fi పై సుమారు %d నిమిషాలు మిగిలాయి."
        ],
        "assistant_download_final_check": [
            "en": "Final check usually takes less than a minute.",
            "hi": "अंतिम जांच में आमतौर पर एक मिनट से कम लगता है।",
            "bn": "শেষ পরীক্ষা সাধারণত এক মিনিটের কম সময় নেয়।",
            "ta": "இறுதி சரிபார்ப்பு பொதுவாக ஒரு நிமிடத்திற்குக் குறைவாகும்.",
            "te": "చివరి తనిఖీ సాధారణంగా ఒక నిమిషం కన్నా తక్కువ సమయం పడుతుంది."
        ],
        "assistant_download_wifi_advisory": [
            "en": "Stay on Wi-Fi — the download resumes automatically if interrupted.",
            "hi": "Wi-Fi पर रहें — रुकावट होने पर डाउनलोड अपने-आप फिर शुरू होगा।",
            "bn": "Wi-Fi-এ থাকুন — বাধা পড়লে ডাউনলোড নিজে থেকেই আবার শুরু হবে।",
            "ta": "Wi-Fi-இல் தொடருங்கள் — இடைநிறுத்தப்பட்டால் பதிவிறக்கம் தானாகத் தொடரும்.",
            "te": "Wi-Fi పై ఉండండి — అంతరాయం కలిగితే డౌన్‌లోడ్ స్వయంగా కొనసాగుతుంది."
        ],
        "assistant_download_error_invalid_url": [
            "en": "The selected private assistant download link is invalid.",
            "hi": "चुना गया private assistant download link सही नहीं है।",
            "bn": "নির্বাচিত private assistant download link ঠিক নয়।",
            "ta": "தேர்ந்தெடுத்த private assistant download link சரியாக இல்லை.",
            "te": "ఎంచుకున్న private assistant download link సరైనది కాదు."
        ],
        "assistant_download_error_http_status": [
            "en": "The assistant download service returned status %d. Try again on Wi-Fi.",
            "hi": "Assistant download service ने status %d लौटाया। Wi-Fi पर फिर कोशिश करें।",
            "bn": "Assistant download service status %d ফিরিয়েছে। Wi-Fi-এ আবার চেষ্টা করুন।",
            "ta": "Assistant download service status %d கொடுத்தது. Wi-Fi-இல் மீண்டும் முயற்சிக்கவும்.",
            "te": "Assistant download service status %d ఇచ్చింది. Wi-Fi పై మళ్లీ ప్రయత్నించండి."
        ],
        "assistant_download_error_missing_size": [
            "en": "Ross could not confirm the assistant setup size before downloading.",
            "hi": "डाउनलोड से पहले Ross assistant setup size confirm नहीं कर पाया।",
            "bn": "ডাউনলোডের আগে Ross assistant setup size নিশ্চিত করতে পারেনি।",
            "ta": "பதிவிறக்கும் முன் Ross assistant setup size உறுதிசெய்ய முடியவில்லை.",
            "te": "డౌన్‌లోడ్‌కు ముందు Ross assistant setup size నిర్ధారించలేకపోయింది."
        ],
        "assistant_download_error_size_changed": [
            "en": "The assistant download listing changed from %@ to %@. Ross stopped setup before downloading.",
            "hi": "Assistant download listing %@ से %@ हो गई। Ross ने डाउनलोड से पहले setup रोक दिया।",
            "bn": "Assistant download listing %@ থেকে %@ হয়েছে। Ross ডাউনলোডের আগে setup থামিয়েছে।",
            "ta": "Assistant download listing %@ இலிருந்து %@ ஆக மாறியது. பதிவிறக்கும் முன் Ross setup-ஐ நிறுத்தியது.",
            "te": "Assistant download listing %@ నుండి %@ కు మారింది. డౌన్‌లోడ్‌కు ముందు Ross setup ఆపింది."
        ],
        "assistant_download_error_not_resumable": [
            "en": "The assistant download cannot be safely resumed right now. Retry later on Wi-Fi.",
            "hi": "Assistant download अभी सुरक्षित रूप से resume नहीं हो सकता। बाद में Wi-Fi पर retry करें।",
            "bn": "Assistant download এখন নিরাপদে resume করা যাচ্ছে না। পরে Wi-Fi-এ retry করুন।",
            "ta": "Assistant download இப்போது பாதுகாப்பாக resume செய்ய முடியாது. பிறகு Wi-Fi-இல் retry செய்யவும்.",
            "te": "Assistant download ఇప్పుడు సురక్షితంగా resume కాలేదు. తర్వాత Wi-Fi పై retry చేయండి."
        ],
        "assistant_download_error_listing_changed": [
            "en": "The assistant download listing changed before setup could start. Ross stopped setup before downloading.",
            "hi": "Setup शुरू होने से पहले assistant download listing बदल गई। Ross ने डाउनलोड से पहले setup रोक दिया।",
            "bn": "Setup শুরু হওয়ার আগে assistant download listing বদলে গেছে। Ross ডাউনলোডের আগে setup থামিয়েছে।",
            "ta": "Setup தொடங்குவதற்கு முன் assistant download listing மாறியது. பதிவிறக்கும் முன் Ross setup-ஐ நிறுத்தியது.",
            "te": "Setup ప్రారంభానికి ముందు assistant download listing మారింది. డౌన్‌లోడ్‌కు ముందు Ross setup ఆపింది."
        ],
        "assistant_download_error_resume_service": [
            "en": "The assistant download service could not safely continue from the saved progress. Retry setup on Wi-Fi.",
            "hi": "Assistant download service saved progress से सुरक्षित रूप से continue नहीं कर पाई। Wi-Fi पर setup retry करें।",
            "bn": "Assistant download service saved progress থেকে নিরাপদে continue করতে পারেনি। Wi-Fi-এ setup retry করুন।",
            "ta": "Assistant download service saved progress-இலிருந்து பாதுகாப்பாக continue செய்ய முடியவில்லை. Wi-Fi-இல் setup retry செய்யவும்.",
            "te": "Assistant download service saved progress నుండి సురక్షితంగా continue కాలేదు. Wi-Fi పై setup retry చేయండి."
        ],
        "assistant_download_error_resume_progress": [
            "en": "Ross could not safely confirm the saved assistant download progress. Retry setup on Wi-Fi.",
            "hi": "Ross saved assistant download progress सुरक्षित रूप से confirm नहीं कर पाया। Wi-Fi पर setup retry करें।",
            "bn": "Ross saved assistant download progress নিরাপদে confirm করতে পারেনি। Wi-Fi-এ setup retry করুন।",
            "ta": "Saved assistant download progress-ஐ Ross பாதுகாப்பாக confirm செய்ய முடியவில்லை. Wi-Fi-இல் setup retry செய்யவும்.",
            "te": "Saved assistant download progress ను Ross సురక్షితంగా confirm చేయలేకపోయింది. Wi-Fi పై setup retry చేయండి."
        ],
        "assistant_download_error_resume_continue": [
            "en": "Ross could not safely continue the saved assistant download. Retry setup on Wi-Fi.",
            "hi": "Ross saved assistant download सुरक्षित रूप से continue नहीं कर पाया। Wi-Fi पर setup retry करें।",
            "bn": "Ross saved assistant download নিরাপদে continue করতে পারেনি। Wi-Fi-এ setup retry করুন।",
            "ta": "Saved assistant download-ஐ Ross பாதுகாப்பாக continue செய்ய முடியவில்லை. Wi-Fi-இல் setup retry செய்யவும்.",
            "te": "Saved assistant download ను Ross సురక్షితంగా continue చేయలేకపోయింది. Wi-Fi పై setup retry చేయండి."
        ],
        "assistant_download_error_storage": [
            "en": "Assistant setup needs about %d GB free. This iPhone currently reports %d GB free.",
            "hi": "Assistant setup के लिए लगभग %d GB खाली जगह चाहिए। यह iPhone अभी %d GB खाली दिखा रहा है।",
            "bn": "Assistant setup-এর জন্য প্রায় %d GB খালি জায়গা দরকার। এই iPhone এখন %d GB খালি দেখাচ্ছে।",
            "ta": "Assistant setup-க்கு சுமார் %d GB காலி இடம் தேவை. இந்த iPhone இப்போது %d GB காலி இடம் காட்டுகிறது.",
            "te": "Assistant setup కు సుమారు %d GB ఖాళీ స్థలం కావాలి. ఈ iPhone ప్రస్తుతం %d GB ఖాళీగా ఉందని చూపుతోంది."
        ],
        "assistant_download_error_missing_file": [
            "en": "Assistant setup is missing or incomplete. Open My assistant and use Repair setup.",
            "hi": "Assistant setup missing या incomplete है। My assistant खोलकर Repair setup चलाएँ।",
            "bn": "Assistant setup missing বা incomplete। My assistant খুলে Repair setup ব্যবহার করুন।",
            "ta": "Assistant setup missing அல்லது incomplete. My assistant திறந்து Repair setup பயன்படுத்தவும்.",
            "te": "Assistant setup missing లేదా incomplete. My assistant తెరిచి Repair setup ఉపయోగించండి."
        ],
        "assistant_download_error_paused": [
            "en": "Assistant setup is paused.",
            "hi": "Assistant setup paused है।",
            "bn": "Assistant setup paused আছে।",
            "ta": "Assistant setup paused நிலையில் உள்ளது.",
            "te": "Assistant setup paused అయ్యింది."
        ],
        "assistant_download_error_unknown_network": [
            "en": "The assistant download service interrupted setup before iOS could classify the error. Retry on Wi-Fi; Ross will use a foreground fallback if the background download fails again.",
            "hi": "iOS error classify करे उससे पहले assistant download service ने setup रोक दिया। Wi-Fi पर retry करें; background download फिर fail हुआ तो Ross foreground fallback use करेगा।",
            "bn": "iOS error classify করার আগে assistant download service setup থামিয়েছে। Wi-Fi-এ retry করুন; background download আবার fail হলে Ross foreground fallback ব্যবহার করবে।",
            "ta": "iOS error-ஐ classify செய்வதற்கு முன் assistant download service setup-ஐ நிறுத்தியது. Wi-Fi-இல் retry செய்யவும்; background download மீண்டும் fail ஆனால் Ross foreground fallback பயன்படுத்தும்.",
            "te": "iOS error classify చేసే ముందు assistant download service setup ఆపింది. Wi-Fi పై retry చేయండి; background download మళ్లీ fail అయితే Ross foreground fallback ఉపయోగిస్తుంది."
        ],
        "assistant_download_error_offline": [
            "en": "Ross could not reach the assistant download service. Check the connection and retry on Wi-Fi.",
            "hi": "Ross assistant download service तक नहीं पहुँच पाया। connection जांचें और Wi-Fi पर retry करें।",
            "bn": "Ross assistant download service-এ পৌঁছাতে পারেনি। connection দেখে Wi-Fi-এ retry করুন।",
            "ta": "Ross assistant download service-ஐ அடைய முடியவில்லை. connection சரிபார்த்து Wi-Fi-இல் retry செய்யவும்.",
            "te": "Ross assistant download service ను చేరలేకపోయింది. connection చూసి Wi-Fi పై retry చేయండి."
        ],
        "assistant_download_error_cancelled": [
            "en": "The assistant download was interrupted before it could start. Retry setup; Ross will resume if resume data is available.",
            "hi": "Assistant download शुरू होने से पहले interrupted हुआ। setup retry करें; resume data उपलब्ध हुआ तो Ross resume करेगा।",
            "bn": "Assistant download শুরু হওয়ার আগে interrupted হয়েছে। setup retry করুন; resume data থাকলে Ross resume করবে।",
            "ta": "Assistant download தொடங்குவதற்கு முன் interrupted ஆனது. setup retry செய்யவும்; resume data இருந்தால் Ross resume செய்யும்.",
            "te": "Assistant download ప్రారంభానికి ముందు interrupted అయ్యింది. setup retry చేయండి; resume data ఉంటే Ross resume చేస్తుంది."
        ],
        "assistant_download_error_connection_lost": [
            "en": "The assistant download connection was interrupted. Retry setup; Ross will resume if the server provided resume data.",
            "hi": "Assistant download connection interrupted हुआ। setup retry करें; server ने resume data दिया हो तो Ross resume करेगा।",
            "bn": "Assistant download connection interrupted হয়েছে। setup retry করুন; server resume data দিলে Ross resume করবে।",
            "ta": "Assistant download connection interrupted ஆனது. setup retry செய்யவும்; server resume data கொடுத்திருந்தால் Ross resume செய்யும்.",
            "te": "Assistant download connection interrupted అయ్యింది. setup retry చేయండి; server resume data ఇచ్చినట్లయితే Ross resume చేస్తుంది."
        ],
        "assistant_download_error_verification_failed": [
            "en": "The assistant download could not finish verification. Retry on Wi-Fi, or open My assistant and start setup again.",
            "hi": "Assistant download verification पूरी नहीं कर पाया। Wi-Fi पर retry करें या My assistant खोलकर setup फिर शुरू करें।",
            "bn": "Assistant download verification শেষ করতে পারেনি। Wi-Fi-এ retry করুন বা My assistant খুলে setup আবার শুরু করুন।",
            "ta": "Assistant download verification முடிக்க முடியவில்லை. Wi-Fi-இல் retry செய்யவும் அல்லது My assistant திறந்து setup மீண்டும் தொடங்கவும்.",
            "te": "Assistant download verification పూర్తి కాలేదు. Wi-Fi పై retry చేయండి లేదా My assistant తెరిచి setup మళ్లీ ప్రారంభించండి."
        ],
        "assistant_setup_retry_hint": [
            "en": "Retry keeps your matters and files, then starts assistant setup again.",
            "hi": "Retry आपके मामले और फ़ाइलें सुरक्षित रखता है, फिर सहायक सेटअप फिर शुरू करता है।",
            "bn": "Retry আপনার মামলা ও ফাইল রেখে সহকারী সেটআপ আবার শুরু করে।",
            "ta": "Retry உங்கள் வழக்குகள் மற்றும் கோப்புகளை வைத்தே உதவியாளர் அமைப்பை மீண்டும் தொடங்கும்.",
            "te": "Retry మీ కేసులు, ఫైళ్లను అలాగే ఉంచి సహాయకుడి సెటప్‌ను మళ్లీ ప్రారంభిస్తుంది."
        ],
        "assistant_setup_storage_hint": [
            "en": "Free storage on this iPhone, then resume setup from here.",
            "hi": "इस iPhone पर स्टोरेज खाली करें, फिर यहीं से सेटअप फिर शुरू करें।",
            "bn": "এই iPhone-এ স্টোরেজ খালি করুন, তারপর এখান থেকেই সেটআপ চালু করুন।",
            "ta": "இந்த iPhone-இல் சேமிப்பிடத்தை காலி செய்து, இங்கிருந்து அமைப்பைத் தொடருங்கள்.",
            "te": "ఈ iPhone లో నిల్వను ఖాళీ చేసి, ఇక్కడి నుంచే సెటప్‌ను కొనసాగించండి."
        ],
        "assistant_setup_resume_hint": [
            "en": "Resume setup when you are ready; your existing progress stays on this iPhone.",
            "hi": "तैयार होने पर सेटअप फिर शुरू करें; आपकी मौजूदा प्रगति इसी iPhone पर रहती है।",
            "bn": "প্রস্তুত হলে সেটআপ আবার শুরু করুন; আপনার অগ্রগতি এই iPhone-এ থাকে।",
            "ta": "தயாரானபோது அமைப்பைத் தொடருங்கள்; இதுவரையிலான முன்னேற்றம் இந்த iPhone-இல் இருக்கும்.",
            "te": "మీరు సిద్ధమైనప్పుడు సెటప్‌ను కొనసాగించండి; ఉన్న పురోగతి ఈ iPhone లోనే ఉంటుంది."
        ],
        "assistant_setup_wifi_hint": [
            "en": "Reconnect to Wi-Fi, then resume setup from here.",
            "hi": "Wi-Fi से फिर जुड़ें, फिर यहीं से सेटअप फिर शुरू करें।",
            "bn": "Wi-Fi-এ আবার যুক্ত হয়ে এখান থেকেই সেটআপ চালু করুন।",
            "ta": "Wi-Fi-இல் மீண்டும் இணைந்து, இங்கிருந்து அமைப்பைத் தொடருங்கள்.",
            "te": "Wi-Fi కు మళ్లీ కనెక్ట్ అయి, ఇక్కడి నుంచే సెటప్‌ను కొనసాగించండి."
        ],
        "assistant_state_preparing": [
            "en": "Preparing",
            "hi": "तैयार हो रहा है",
            "bn": "প্রস্তুত হচ্ছে",
            "ta": "தயாராகிறது",
            "te": "సిద్ధమవుతోంది"
        ],
        "assistant_state_checking": [
            "en": "Checking",
            "hi": "जांच हो रही है",
            "bn": "পরীক্ষা চলছে",
            "ta": "சரிபார்க்கிறது",
            "te": "తనిఖీ జరుగుతోంది"
        ],
        "assistant_state_waiting_wifi": [
            "en": "Waiting for Wi-Fi",
            "hi": "Wi-Fi की प्रतीक्षा",
            "bn": "Wi-Fi-এর অপেক্ষা",
            "ta": "Wi-Fi காத்திருக்கிறது",
            "te": "Wi-Fi కోసం వేచి ఉంది"
        ],
        "assistant_state_paused": [
            "en": "Paused",
            "hi": "रुका हुआ",
            "bn": "থেমে আছে",
            "ta": "இடைநிறுத்தப்பட்டது",
            "te": "నిలిపివేయబడింది"
        ],
        "assistant_state_needs_space": [
            "en": "Needs space",
            "hi": "जगह चाहिए",
            "bn": "জায়গা দরকার",
            "ta": "இடம் தேவை",
            "te": "స్థలం కావాలి"
        ],
        "assistant_state_needs_retry": [
            "en": "Needs retry",
            "hi": "फिर कोशिश चाहिए",
            "bn": "আবার চেষ্টা দরকার",
            "ta": "மீண்டும் முயற்சி தேவை",
            "te": "మళ్లీ ప్రయత్నించాలి"
        ],
        "assistant_state_ready": [
            "en": "Ready",
            "hi": "तैयार",
            "bn": "প্রস্তুত",
            "ta": "தயார்",
            "te": "సిద్ధం"
        ],
        "assistant_state_cancelled": [
            "en": "Cancelled",
            "hi": "रद्द हुआ",
            "bn": "বাতিল হয়েছে",
            "ta": "ரத்து செய்யப்பட்டது",
            "te": "రద్దయింది"
        ],
        "assistant_state_not_started": [
            "en": "Not started",
            "hi": "शुरू नहीं हुआ",
            "bn": "শুরু হয়নি",
            "ta": "தொடங்கவில்லை",
            "te": "ప్రారంభం కాలేదు"
        ],
        "assistant_activity_preparing": [
            "en": "Ross is preparing the private assistant. You can keep using the app.",
            "hi": "Ross निजी सहायक तैयार कर रहा है। आप ऐप का उपयोग जारी रख सकते हैं।",
            "bn": "Ross ব্যক্তিগত সহকারী প্রস্তুত করছে। আপনি অ্যাপ ব্যবহার চালিয়ে যেতে পারেন।",
            "ta": "Ross தனிப்பட்ட உதவியாளரை தயாராக்குகிறது. நீங்கள் பயன்பாட்டை தொடர்ந்து பயன்படுத்தலாம்.",
            "te": "Ross ప్రైవేట్ సహాయకుడిని సిద్ధం చేస్తోంది. మీరు యాప్‌ను కొనసాగించవచ్చు."
        ],
        "assistant_activity_checking": [
            "en": "Ross is checking that the on-device assistant is ready before turning it on.",
            "hi": "चालू करने से पहले Ross जांच रहा है कि ऑन-डिवाइस सहायक तैयार है।",
            "bn": "চালু করার আগে Ross দেখছে ডিভাইসের সহকারী প্রস্তুত কি না।",
            "ta": "இயக்குவதற்கு முன் சாதனத்திலுள்ள உதவியாளர் தயாரா என்பதை Ross சரிபார்க்கிறது.",
            "te": "ఆన్ చేయడానికి ముందు పరికరంలోని సహాయకుడు సిద్ధంగా ఉన్నాడో Ross తనిఖీ చేస్తోంది."
        ],
        "assistant_activity_waiting_wifi": [
            "en": "Ross is waiting for Wi-Fi before continuing the assistant setup.",
            "hi": "सहायक सेटअप जारी रखने से पहले Ross Wi-Fi की प्रतीक्षा कर रहा है।",
            "bn": "সহকারী সেটআপ চালিয়ে যাওয়ার আগে Ross Wi-Fi-এর অপেক্ষা করছে।",
            "ta": "உதவியாளர் அமைப்பைத் தொடர்வதற்கு முன் Ross Wi-Fi காத்திருக்கிறது.",
            "te": "సహాయకుడి సెటప్ కొనసాగించే ముందు Ross Wi-Fi కోసం వేచి ఉంది."
        ],
        "assistant_activity_paused": [
            "en": "The assistant setup is paused. Open My assistant to resume it from this iPhone.",
            "hi": "सहायक सेटअप रुका है। इस iPhone से फिर शुरू करने के लिए My assistant खोलें।",
            "bn": "সহকারী সেটআপ থেমে আছে। এই iPhone থেকে চালু করতে My assistant খুলুন।",
            "ta": "உதவியாளர் அமைப்பு இடைநிறுத்தப்பட்டுள்ளது. இந்த iPhone-இல் இருந்து தொடர My assistant திறக்கவும்.",
            "te": "సహాయకుడి సెటప్ నిలిచింది. ఈ iPhone నుండి కొనసాగించడానికి My assistant తెరవండి."
        ],
        "assistant_activity_storage": [
            "en": "Ross needs more free space before the assistant can finish setting up.",
            "hi": "सहायक सेटअप पूरा करने से पहले Ross को और खाली जगह चाहिए।",
            "bn": "সহকারী সেটআপ শেষ করার আগে Ross-এর আরও খালি জায়গা দরকার।",
            "ta": "உதவியாளர் அமைப்பு முடிவதற்கு முன் Ross-க்கு கூடுதல் காலி இடம் தேவை.",
            "te": "సహాయకుడి సెటప్ పూర్తయ్యే ముందు Ross కు మరింత ఖాళీ స్థలం అవసరం."
        ],
        "assistant_activity_retry": [
            "en": "Assistant setup could not finish. Open My assistant to retry or repair setup; your matters and files stay on this iPhone.",
            "hi": "सहायक सेटअप पूरा नहीं हो सका। Retry या Repair setup के लिए My assistant खोलें; आपके मामले और फ़ाइलें इसी iPhone पर रहती हैं।",
            "bn": "সহকারী সেটআপ শেষ হয়নি। Retry বা Repair setup করতে My assistant খুলুন; আপনার মামলা ও ফাইল এই iPhone-এ থাকে।",
            "ta": "உதவியாளர் அமைப்பு முடிக்க முடியவில்லை. மீண்டும் முயற்சிக்க அல்லது Repair setup செய்ய My assistant திறக்கவும்; உங்கள் வழக்குகள் மற்றும் கோப்புகள் இந்த iPhone-இல் இருக்கும்.",
            "te": "సహాయకుడి సెటప్ పూర్తికాలేదు. Retry లేదా Repair setup కోసం My assistant తెరవండి; మీ కేసులు, ఫైళ్లు ఈ iPhone లోనే ఉంటాయి."
        ],
        "assistant_activity_idle": [
            "en": "No setup is running right now.",
            "hi": "अभी कोई सेटअप नहीं चल रहा है।",
            "bn": "এখন কোনো সেটআপ চলছে না।",
            "ta": "இப்போது எந்த அமைப்பும் இயங்கவில்லை.",
            "te": "ప్రస్తుతం ఎలాంటి సెటప్ నడవడం లేదు."
        ],
        "assistant_activity_title_preparing": [
            "en": "%@ is preparing",
            "hi": "%@ तैयार हो रहा है",
            "bn": "%@ প্রস্তুত হচ্ছে",
            "ta": "%@ தயாராகிறது",
            "te": "%@ సిద్ధమవుతోంది"
        ],
        "assistant_activity_title_paused": [
            "en": "%@ setup is paused",
            "hi": "%@ setup paused है",
            "bn": "%@ setup paused আছে",
            "ta": "%@ setup paused உள்ளது",
            "te": "%@ setup paused అయింది"
        ],
        "assistant_activity_title_retry": [
            "en": "Private assistant needs a retry",
            "hi": "Private assistant को retry चाहिए",
            "bn": "Private assistant retry চায়",
            "ta": "Private assistant-க்கு retry தேவை",
            "te": "Private assistant కు retry కావాలి"
        ],
        "assistant_badge_active": [
            "en": "Active",
            "hi": "सक्रिय",
            "bn": "সক্রিয়",
            "ta": "செயலில்",
            "te": "సక్రియం"
        ],
        "assistant_badge_needs_attention": [
            "en": "Needs attention",
            "hi": "ध्यान चाहिए",
            "bn": "নজর দরকার",
            "ta": "கவனம் தேவை",
            "te": "శ్రద్ధ అవసరం"
        ],
        "assistant_badge_setting_up": [
            "en": "Setting up",
            "hi": "सेटअप हो रहा है",
            "bn": "সেটআপ চলছে",
            "ta": "அமைக்கப்படுகிறது",
            "te": "సెటప్ జరుగుతోంది"
        ],
        "assistant_action_using": [
            "en": "Using this option",
            "hi": "यह विकल्प उपयोग हो रहा है",
            "bn": "এই বিকল্প ব্যবহার হচ্ছে",
            "ta": "இந்த விருப்பம் பயன்படுத்தப்படுகிறது",
            "te": "ఈ ఎంపిక ఉపయోగంలో ఉంది"
        ],
        "assistant_action_repair": [
            "en": "Repair setup",
            "hi": "सेटअप सुधारें",
            "bn": "সেটআপ মেরামত করুন",
            "ta": "அமைப்பைச் சரிசெய்க",
            "te": "సెటప్‌ను సరిచేయండి"
        ],
        "assistant_action_use": [
            "en": "Use this option",
            "hi": "यह विकल्प उपयोग करें",
            "bn": "এই বিকল্প ব্যবহার করুন",
            "ta": "இந்த விருப்பத்தைப் பயன்படுத்தவும்",
            "te": "ఈ ఎంపికను ఉపయోగించండి"
        ],
        "assistant_action_resume_setup": [
            "en": "Resume setup",
            "hi": "सेटअप फिर शुरू करें",
            "bn": "সেটআপ আবার চালু করুন",
            "ta": "அமைப்பைத் தொடருங்கள்",
            "te": "సెటప్‌ను కొనసాగించండి"
        ],
        "assistant_action_set_up_option": [
            "en": "Set up this option",
            "hi": "यह विकल्प सेट करें",
            "bn": "এই বিকল্প সেট আপ করুন",
            "ta": "இந்த விருப்பத்தை அமைக்கவும்",
            "te": "ఈ ఎంపికను సెటప్ చేయండి"
        ],
        "assistant_action_pause": [
            "en": "Pause",
            "hi": "रोकें",
            "bn": "বিরতি",
            "ta": "இடைநிறுத்து",
            "te": "నిలిపివేయి"
        ],
        "assistant_action_retry": [
            "en": "Retry",
            "hi": "फिर कोशिश करें",
            "bn": "আবার চেষ্টা করুন",
            "ta": "மீண்டும் முயற்சி",
            "te": "మళ్లీ ప్రయత్నించండి"
        ],
        "assistant_action_resume": [
            "en": "Resume",
            "hi": "फिर शुरू करें",
            "bn": "চালু করুন",
            "ta": "தொடரவும்",
            "te": "కొనసాగించండి"
        ],
        "my_assistant": [
            "en": "My assistant",
            "hi": "My assistant",
            "bn": "My assistant",
            "ta": "My assistant",
            "te": "My assistant"
        ],
        "private_assistant": [
            "en": "Private assistant",
            "hi": "Private assistant",
            "bn": "Private assistant",
            "ta": "Private assistant",
            "te": "Private assistant"
        ],
        "ask_assistant_setup_title": [
            "en": "Private assistant setup",
            "hi": "Private assistant setup",
            "bn": "Private assistant setup",
            "ta": "Private assistant setup",
            "te": "Private assistant setup"
        ],
        "ask_assistant_setup_before_detail": [
            "en": "Before setup, Ross can still organize matters, tasks, dates, and files on this device.",
            "hi": "setup से पहले भी Ross इस device पर matters, tasks, dates, और files organize कर सकता है।",
            "bn": "setup-এর আগেও Ross এই device-এ matters, tasks, dates, এবং files organize করতে পারে।",
            "ta": "setup முன்பும் Ross இந்த device-ல் matters, tasks, dates, மற்றும் files organize செய்ய முடியும்.",
            "te": "setup కు ముందు కూడా Ross ఈ device లో matters, tasks, dates, మరియు files organize చేయగలదు."
        ],
        "ask_assistant_setup_after_detail": [
            "en": "After setup, the private assistant adds stronger document review, summaries, chronologies, and answers from your files.",
            "hi": "setup के बाद private assistant आपके files से stronger document review, summaries, chronologies, और answers जोड़ता है।",
            "bn": "setup-এর পরে private assistant আপনার files থেকে stronger document review, summaries, chronologies, এবং answers যোগ করে।",
            "ta": "setup பிறகு private assistant உங்கள் files-இல் இருந்து stronger document review, summaries, chronologies, மற்றும் answers சேர்க்கும்.",
            "te": "setup తర్వాత private assistant మీ files నుండి stronger document review, summaries, chronologies, మరియు answers ఇస్తుంది."
        ],
        "ask_assistant_setup_open_settings_detail": [
            "en": "Open Settings, then My assistant, to choose Basic, Standard, or Advanced.",
            "hi": "Basic, Standard, या Advanced चुनने के लिए Settings, फिर My assistant खोलें।",
            "bn": "Basic, Standard, বা Advanced বেছে নিতে Settings, তারপর My assistant খুলুন।",
            "ta": "Basic, Standard, அல்லது Advanced தேர்வுசெய்ய Settings, பிறகு My assistant திறக்கவும்.",
            "te": "Basic, Standard, లేదా Advanced ఎంచుకోవడానికి Settings, తర్వాత My assistant తెరవండి."
        ],
        "ask_private_assistant_not_ready": [
            "en": "Private assistant not ready",
            "hi": "निजी सहायक तैयार नहीं है",
            "bn": "প্রাইভেট সহায়ক এখনও প্রস্তুত নয়",
            "ta": "தனிப்பட்ட உதவியாளர் இன்னும் தயாராக இல்லை",
            "te": "ప్రైవేట్ సహాయకుడు ఇంకా సిద్ధంగా లేదు"
        ],
        "ask_private_assistant_setup_required": [
            "en": "Private assistant setup required",
            "hi": "निजी सहायक सेटअप ज़रूरी है",
            "bn": "প্রাইভেট সহায়ক সেটআপ প্রয়োজন",
            "ta": "தனிப்பட்ட உதவியாளர் அமைப்பு தேவை",
            "te": "ప్రైవేట్ సహాయకుడి సెటప్ అవసరం"
        ],
        "ask_private_assistant_setup_safety_note": [
            "en": "Ross did not generate a legal answer because the private assistant is not ready.",
            "hi": "Ross ने कानूनी उत्तर नहीं बनाया क्योंकि निजी सहायक अभी तैयार नहीं है.",
            "bn": "প্রাইভেট সহায়ক প্রস্তুত না থাকায় Ross কোনও আইনি উত্তর তৈরি করেনি.",
            "ta": "தனிப்பட்ட உதவியாளர் தயாராக இல்லாததால் Ross சட்டப் பதிலை உருவாக்கவில்லை.",
            "te": "ప్రైవేట్ సహాయకుడు సిద్ధంగా లేకపోవడంతో Ross న్యాయ సమాధానం ఇవ్వలేదు."
        ],
        "ask_private_assistant_installed_but_blocked": [
            "en": "Ross found assistant setup, but the private assistant is not opening yet. Run Repair setup from My assistant.",
            "hi": "Ross को सेटअप मिला, पर निजी सहायक अभी खुल नहीं रहा है. My assistant में Repair setup चलाएँ.",
            "bn": "Ross সেটআপ খুঁজে পেয়েছে, কিন্তু প্রাইভেট সহায়ক এখন খুলছে না. My assistant থেকে Repair setup চালান.",
            "ta": "Ross அமைப்பைக் கண்டது, ஆனால் தனிப்பட்ட உதவியாளர் இப்போது திறக்கவில்லை. My assistant-ல் Repair setup இயக்கவும்.",
            "te": "Ross సెటప్‌ను కనుగొంది, కానీ ప్రైవేట్ సహాయకుడు ఇప్పుడు తెరుచుకోవడం లేదు. My assistant‌లో Repair setup నడపండి."
        ],
        "assistant_existing_setup_repair_detail": [
            "en": "Ross found an assistant setup file, but could not open it. Ross removed the bad file. Open My assistant and use Repair setup to start fresh.",
            "hi": "Ross को assistant setup file मिली, लेकिन वह खुली नहीं। Ross ने खराब file हटा दी। Fresh start के लिए My assistant खोलकर Repair setup चलाएँ.",
            "bn": "Ross assistant setup file খুঁজে পেয়েছে, কিন্তু খুলতে পারেনি। Ross খারাপ file সরিয়েছে। Fresh start করতে My assistant খুলে Repair setup ব্যবহার করুন.",
            "ta": "Ross assistant setup file-ஐ கண்டது, ஆனால் திறக்க முடியவில்லை. Ross கெட்ட file-ஐ நீக்கியது. Fresh start செய்ய My assistant திறந்து Repair setup பயன்படுத்தவும்.",
            "te": "Ross assistant setup file కనుగొంది, కానీ తెరవలేకపోయింది. Ross పాడైన file ను తొలగించింది. Fresh start కోసం My assistant తెరిచి Repair setup ఉపయోగించండి."
        ],
        "assistant_download_resume_missing_restart": [
            "en": "Saved assistant setup progress was unavailable. Ross will restart the assistant download from the beginning.",
            "hi": "Saved assistant setup progress उपलब्ध नहीं था। Ross assistant download शुरुआत से restart करेगा.",
            "bn": "Saved assistant setup progress পাওয়া যায়নি। Ross assistant download শুরু থেকে restart করবে.",
            "ta": "Saved assistant setup progress கிடைக்கவில்லை. Ross assistant download-ஐ தொடக்கம் முதல் restart செய்யும்.",
            "te": "Saved assistant setup progress అందుబాటులో లేదు. Ross assistant download ను మొదటి నుండి restart చేస్తుంది."
        ],
        "assistant_download_resume_missing_restart_detail": [
            "en": "Saved assistant setup progress was unavailable, so Ross restarted the assistant download from the beginning. No case files were read.",
            "hi": "Saved assistant setup progress उपलब्ध नहीं था, इसलिए Ross ने assistant download शुरुआत से restart किया। कोई case files नहीं पढ़ी गईं.",
            "bn": "Saved assistant setup progress পাওয়া যায়নি, তাই Ross assistant download শুরু থেকে restart করেছে। কোনো case files পড়া হয়নি.",
            "ta": "Saved assistant setup progress கிடைக்கவில்லை, அதனால் Ross assistant download-ஐ தொடக்கம் முதல் restart செய்தது. Case files எதுவும் வாசிக்கப்படவில்லை.",
            "te": "Saved assistant setup progress అందుబాటులో లేదు, కాబట్టి Ross assistant download ను మొదటి నుండి restart చేసింది. Case files ఏవీ చదవబడలేదు."
        ],
        "assistant_download_resume_stale_restart_detail": [
            "en": "Saved assistant setup progress could not continue, so Ross restarted the assistant download from the beginning. No case files were read.",
            "hi": "Saved assistant setup progress continue नहीं हो पाया, इसलिए Ross ने assistant download शुरुआत से restart किया। कोई case files नहीं पढ़ी गईं.",
            "bn": "Saved assistant setup progress continue করা যায়নি, তাই Ross assistant download শুরু থেকে restart করেছে। কোনো case files পড়া হয়নি.",
            "ta": "Saved assistant setup progress continue செய்ய முடியவில்லை, அதனால் Ross assistant download-ஐ தொடக்கம் முதல் restart செய்தது. Case files எதுவும் வாசிக்கப்படவில்லை.",
            "te": "Saved assistant setup progress continue కాలేదు, కాబట్టి Ross assistant download ను మొదటి నుండి restart చేసింది. Case files ఏవీ చదవబడలేదు."
        ],
        "ask_private_assistant_downloading_detail": [
            "en": "Assistant setup is still downloading or checking the file. Ross will answer after the private assistant is ready.",
            "hi": "सहायक अभी डाउनलोड या जाँच में है. तैयार होते ही Ross जवाब देगा.",
            "bn": "সহায়ক এখনও ডাউনলোড বা পরীক্ষা হচ্ছে. প্রস্তুত হলেই Ross উত্তর দেবে.",
            "ta": "உதவியாளர் இன்னும் பதிவிறக்கம் அல்லது சரிபார்ப்பில் உள்ளது. தயாரானதும் Ross பதிலளிக்கும்.",
            "te": "సహాయకుడు ఇంకా డౌన్‌లోడ్ లేదా తనిఖీలో ఉంది. సిద్ధమైన వెంటనే Ross సమాధానం ఇస్తుంది."
        ],
        "ask_private_assistant_queued_detail": [
            "en": "Assistant setup is queued. Keep Ross open on Wi-Fi or resume setup from My assistant.",
            "hi": "सहायक सेटअप कतार में है. Ross को Wi-Fi पर खुला रखें या My assistant से फिर शुरू करें.",
            "bn": "সহায়ক সেটআপ কিউতে আছে. Ross Wi-Fi-তে খোলা রাখুন বা My assistant থেকে আবার শুরু করুন.",
            "ta": "உதவியாளர் அமைப்பு வரிசையில் உள்ளது. Wi-Fi-யில் Ross-ஐ திறந்தே வைத்திருங்கள் அல்லது My assistant-ல் மீண்டும் தொடங்கவும்.",
            "te": "సహాయకుడి సెటప్ వరుసలో ఉంది. Ross‌ను Wi-Fiలో తెరిచి ఉంచండి లేదా My assistant నుంచి మళ్లీ ప్రారంభించండి."
        ],
        "ask_private_assistant_failed_detail": [
            "en": "Assistant setup did not finish. Open My assistant to retry or repair setup.",
            "hi": "सहायक सेटअप पूरा नहीं हुआ. My assistant खोलकर सेटअप फिर से शुरू या repair करें.",
            "bn": "সহায়ক সেটআপ শেষ হয়নি. My assistant খুলে সেটআপ আবার শুরু বা repair করুন.",
            "ta": "உதவியாளர் அமைப்பு முடியவில்லை. My assistant திறந்து அமைப்பை மீண்டும் தொடங்கவும் அல்லது repair செய்யவும்.",
            "te": "సహాయకుడి సెటప్ పూర్తికాలేదు. My assistant తెరిచి సెటప్‌ను మళ్లీ ప్రారంభించండి లేదా repair చేయండి."
        ],
        "ask_private_assistant_not_started_detail": [
            "en": "Open My assistant and set up a private assistant on this iPhone before asking legal questions.",
            "hi": "कानूनी सवाल पूछने से पहले My assistant खोलकर इस iPhone पर निजी सहायक सेट करें.",
            "bn": "আইনি প্রশ্ন করার আগে My assistant খুলে এই iPhone-এ প্রাইভেট সহায়ক সেট আপ করুন.",
            "ta": "சட்டக் கேள்விகளை கேட்பதற்கு முன் My assistant திறந்து இந்த iPhone-ல் தனிப்பட்ட உதவியாளரை அமைக்கவும்.",
            "te": "న్యాయ ప్రశ్నలు అడగడానికి ముందు My assistant తెరిచి ఈ iPhoneలో ప్రైవేట్ సహాయకుడిని సెటప్ చేయండి."
        ],
        "file_review_assistant_setup_required_warning": [
            "en": "Private assistant setup is required before Ross can review this document with your private assistant.",
            "hi": "Ross इस document को private assistant से review करे उससे पहले private assistant setup ज़रूरी है.",
            "bn": "Ross এই document private assistant দিয়ে review করার আগে private assistant setup প্রয়োজন.",
            "ta": "Ross இந்த document-ஐ private assistant மூலம் review செய்வதற்கு முன் private assistant setup தேவை.",
            "te": "Ross ఈ document ను private assistant తో review చేయడానికి ముందు private assistant setup అవసరం."
        ],
        "file_review_assistant_setup_required_short": [
            "en": "Private assistant setup required.",
            "hi": "Private assistant setup ज़रूरी है.",
            "bn": "Private assistant setup প্রয়োজন.",
            "ta": "Private assistant setup தேவை.",
            "te": "Private assistant setup అవసరం."
        ],
        "file_review_basic_too_long_warning": [
            "en": "Basic is best for shorter files. Choose Standard or Advanced before Ross reviews this longer document with your private assistant.",
            "hi": "Basic छोटी files के लिए बेहतर है। इस लंबे document को private assistant से review करने से पहले Standard या Advanced चुनें.",
            "bn": "Basic ছোট files-এর জন্য ভালো। এই দীর্ঘ document private assistant দিয়ে review করার আগে Standard বা Advanced বেছে নিন.",
            "ta": "Basic குறுகிய files-க்கு சிறந்தது. இந்த நீளமான document-ஐ private assistant மூலம் review செய்வதற்கு முன் Standard அல்லது Advanced தேர்வுசெய்க.",
            "te": "Basic చిన్న files కు మంచిది. ఈ పొడవైన document ను private assistant తో review చేయడానికి ముందు Standard లేదా Advanced ఎంచుకోండి."
        ],
        "import_error_missing_extension": [
            "en": "Files without an extension are not supported yet.",
            "hi": "Extension के बिना files अभी supported नहीं हैं.",
            "bn": "Extension ছাড়া files এখনও supported নয়.",
            "ta": "Extension இல்லாத files இன்னும் supported இல்லை.",
            "te": "Extension లేని files ఇంకా supported కాదు."
        ],
        "import_error_unsupported_extension": [
            "en": ".%@ files are not supported yet.",
            "hi": ".%@ files अभी supported नहीं हैं.",
            "bn": ".%@ files এখনও supported নয়.",
            "ta": ".%@ files இன்னும் supported இல்லை.",
            "te": ".%@ files ఇంకా supported కాదు."
        ],
        "import_error_unreadable_file": [
            "en": "Ross could not read the selected file.",
            "hi": "Ross selected file पढ़ नहीं पाया.",
            "bn": "Ross selected file পড়তে পারেনি.",
            "ta": "Ross selected file-ஐ படிக்க முடியவில்லை.",
            "te": "Ross selected file చదవలేకపోయింది."
        ],
        "import_error_file_too_large": [
            "en": "This file is %@; the current import limit is %@.",
            "hi": "यह file %@ है; current import limit %@ है.",
            "bn": "এই file %@; current import limit %@.",
            "ta": "இந்த file %@; current import limit %@.",
            "te": "ఈ file %@; current import limit %@."
        ],
        "import_error_insufficient_storage": [
            "en": "Ross needs about %@ free, but this device reports %@ available.",
            "hi": "Ross को लगभग %@ free चाहिए, लेकिन इस device पर %@ available दिख रहा है.",
            "bn": "Ross-এর প্রায় %@ free দরকার, কিন্তু এই device-এ %@ available দেখাচ্ছে.",
            "ta": "Ross-க்கு சுமார் %@ free தேவை, ஆனால் இந்த device %@ available என காட்டுகிறது.",
            "te": "Ross కు సుమారు %@ free కావాలి, కానీ ఈ device %@ available అని చూపిస్తోంది."
        ],
        "import_error_unsupported_text_encoding": [
            "en": "This text file uses an encoding Ross cannot read yet.",
            "hi": "यह text file ऐसी encoding use करती है जिसे Ross अभी पढ़ नहीं सकता.",
            "bn": "এই text file এমন encoding ব্যবহার করছে যা Ross এখনও পড়তে পারে না.",
            "ta": "இந்த text file Ross இன்னும் படிக்க முடியாத encoding பயன்படுத்துகிறது.",
            "te": "ఈ text file Ross ఇంకా చదవలేని encoding ను ఉపయోగిస్తోంది."
        ],
        "import_fallback_pdf_unreadable_text": [
            "en": "PDF imported locally. Ross could not read text from this file yet.",
            "hi": "PDF locally import हो गया। Ross इस file से text अभी पढ़ नहीं पाया.",
            "bn": "PDF locally import হয়েছে। Ross এই file থেকে text এখনও পড়তে পারেনি.",
            "ta": "PDF locally import செய்யப்பட்டது. Ross இந்த file-இலிருந்து text இன்னும் படிக்க முடியவில்லை.",
            "te": "PDF locally import అయ్యింది. Ross ఈ file నుండి text ఇంకా చదవలేకపోయింది."
        ],
        "import_fallback_image_unreadable_text": [
            "en": "Image imported locally. Ross could not read text from this image yet.",
            "hi": "Image locally import हो गई। Ross इस image से text अभी पढ़ नहीं पाया.",
            "bn": "Image locally import হয়েছে। Ross এই image থেকে text এখনও পড়তে পারেনি.",
            "ta": "Image locally import செய்யப்பட்டது. Ross இந்த image-இலிருந்து text இன்னும் படிக்க முடியவில்லை.",
            "te": "Image locally import అయ్యింది. Ross ఈ image నుండి text ఇంకా చదవలేకపోయింది."
        ],
        "extraction_error_unreadable_document": [
            "en": "Ross could not read useful text in this document yet.",
            "hi": "Ross इस document में useful text अभी पढ़ नहीं पाया.",
            "bn": "Ross এই document-এ useful text এখনও পড়তে পারেনি.",
            "ta": "Ross இந்த document-இல் useful text இன்னும் படிக்க முடியவில்லை.",
            "te": "Ross ఈ document లో useful text ఇంకా చదవలేకపోయింది."
        ],
        "privacy_ledger_public_law_reviewed_title": [
            "en": "Reviewed public-law search",
            "hi": "Public-law search review किया",
            "bn": "Public-law search review করা হয়েছে",
            "ta": "Public-law search review செய்யப்பட்டது",
            "te": "Public-law search review చేయబడింది"
        ],
        "privacy_ledger_public_law_sent_title": [
            "en": "Used Legal Search",
            "hi": "Legal Search use किया",
            "bn": "Legal Search ব্যবহার করা হয়েছে",
            "ta": "Legal Search பயன்படுத்தப்பட்டது",
            "te": "Legal Search ఉపయోగించబడింది"
        ],
        "privacy_ledger_public_law_cancelled_title": [
            "en": "Cancelled public-law search",
            "hi": "Public-law search cancel किया",
            "bn": "Public-law search cancel করা হয়েছে",
            "ta": "Public-law search cancel செய்யப்பட்டது",
            "te": "Public-law search cancel చేయబడింది"
        ],
        "privacy_ledger_public_law_unavailable_title": [
            "en": "Legal Search needs attention",
            "hi": "Legal Search को ध्यान चाहिए",
            "bn": "Legal Search attention দরকার",
            "ta": "Legal Search கவனம் தேவை",
            "te": "Legal Search కు దృష్టి అవసరం"
        ],
        "privacy_ledger_local_export_generated_title": [
            "en": "Generated Notes & Drafts",
            "hi": "Notes & Drafts बनाए",
            "bn": "Notes & Drafts তৈরি হয়েছে",
            "ta": "Notes & Drafts உருவாக்கப்பட்டது",
            "te": "Notes & Drafts సృష్టించబడింది"
        ],
        "privacy_ledger_local_export_failed_title": [
            "en": "Draft could not be saved",
            "hi": "Draft save नहीं हो पाया",
            "bn": "Draft save করা যায়নি",
            "ta": "Draft save செய்ய முடியவில்லை",
            "te": "Draft save కాలేదు"
        ],
        "privacy_ledger_assistant_catalog_checked_title": [
            "en": "Checked private assistant setup",
            "hi": "Private assistant setup check किया",
            "bn": "Private assistant setup check করা হয়েছে",
            "ta": "Private assistant setup check செய்யப்பட்டது",
            "te": "Private assistant setup check చేయబడింది"
        ],
        "privacy_ledger_assistant_update_available_title": [
            "en": "Private assistant update available",
            "hi": "Private assistant update available है",
            "bn": "Private assistant update available",
            "ta": "Private assistant update available",
            "te": "Private assistant update available ఉంది"
        ],
        "privacy_ledger_private_assistant_setup_title": [
            "en": "Set up private assistant",
            "hi": "Private assistant setup किया",
            "bn": "Private assistant setup করা হয়েছে",
            "ta": "Private assistant setup செய்யப்பட்டது",
            "te": "Private assistant setup చేయబడింది"
        ],
        "privacy_ledger_private_assistant_download_queued_title": [
            "en": "Private assistant setup queued",
            "hi": "Private assistant setup queue हुआ",
            "bn": "Private assistant setup queue হয়েছে",
            "ta": "Private assistant setup queue செய்யப்பட்டது",
            "te": "Private assistant setup queue చేయబడింది"
        ],
        "privacy_ledger_private_assistant_unavailable_title": [
            "en": "Private assistant unavailable",
            "hi": "Private assistant available नहीं",
            "bn": "Private assistant available নয়",
            "ta": "Private assistant available இல்லை",
            "te": "Private assistant available లేదు"
        ],
        "privacy_ledger_local_case_review_title": [
            "en": "Reviewed case locally",
            "hi": "Case locally review किया",
            "bn": "Case locally review করা হয়েছে",
            "ta": "Case locally review செய்யப்பட்டது",
            "te": "Case locally review చేయబడింది"
        ],
        "privacy_ledger_document_imported_title": [
            "en": "Imported document",
            "hi": "Document import किया",
            "bn": "Document import করা হয়েছে",
            "ta": "Document import செய்யப்பட்டது",
            "te": "Document import చేయబడింది"
        ],
        "privacy_ledger_case_created_title": [
            "en": "Created case",
            "hi": "Case बनाया",
            "bn": "Case তৈরি হয়েছে",
            "ta": "Case உருவாக்கப்பட்டது",
            "te": "Case సృష్టించబడింది"
        ],
        "privacy_ledger_public_law_reviewed_detail": [
            "en": "Ross prepared the search locally. 0 private case details left the device.",
            "hi": "Ross ने search locally तैयार किया। 0 private case details device से बाहर गईं.",
            "bn": "Ross search locally প্রস্তুত করেছে। 0 private case details device ছাড়েনি.",
            "ta": "Ross search-ஐ locally தயாரித்தது. 0 private case details device-ஐ விட்டு வெளியேறின.",
            "te": "Ross search ను locally సిద్ధం చేసింది. 0 private case details device బయటకు వెళ్లలేదు."
        ],
        "privacy_ledger_public_law_sent_detail": [
            "en": "Only the reviewed search was sent. Case files stayed on this device.",
            "hi": "सिर्फ reviewed search भेजी गई। Case files इसी device पर रहीं.",
            "bn": "শুধু reviewed search পাঠানো হয়েছে। Case files এই device-এ রয়ে গেছে.",
            "ta": "Reviewed search மட்டும் அனுப்பப்பட்டது. Case files இந்த device-இல் இருந்தன.",
            "te": "Reviewed search మాత్రమే పంపబడింది. Case files ఈ device పైనే ఉన్నాయి."
        ],
        "privacy_ledger_public_law_cancelled_detail": [
            "en": "No public-law network request was made.",
            "hi": "कोई public-law network request नहीं की गई.",
            "bn": "কোনো public-law network request করা হয়নি.",
            "ta": "Public-law network request எதுவும் செய்யப்படவில்லை.",
            "te": "Public-law network request ఏదీ చేయబడలేదు."
        ],
        "privacy_ledger_public_law_unavailable_detail": [
            "en": "Ross could not complete Legal Search. Case files stayed on this device.",
            "hi": "Ross Legal Search complete नहीं कर पाया। Case files इसी device पर रहीं.",
            "bn": "Ross Legal Search complete করতে পারেনি। Case files এই device-এ রয়ে গেছে.",
            "ta": "Ross Legal Search complete செய்ய முடியவில்லை. Case files இந்த device-இல் இருந்தன.",
            "te": "Ross Legal Search complete చేయలేకపోయింది. Case files ఈ device పైనే ఉన్నాయి."
        ],
        "privacy_ledger_local_export_generated_detail": [
            "en": "Ross created the draft locally for advocate review.",
            "hi": "Ross ने advocate review के लिए draft locally बनाया.",
            "bn": "Ross advocate review-এর জন্য draft locally তৈরি করেছে.",
            "ta": "Advocate review-க்காக Ross draft-ஐ locally உருவாக்கியது.",
            "te": "Advocate review కోసం Ross draft ను locally సృష్టించింది."
        ],
        "privacy_ledger_local_export_failed_detail": [
            "en": "Ross could not save the draft file. Case files stayed on this device.",
            "hi": "Ross draft file save नहीं कर पाया। Case files इसी device पर रहीं.",
            "bn": "Ross draft file save করতে পারেনি। Case files এই device-এ রয়ে গেছে.",
            "ta": "Ross draft file-ஐ save செய்ய முடியவில்லை. Case files இந்த device-இல் இருந்தன.",
            "te": "Ross draft file save చేయలేకపోయింది. Case files ఈ device పైనే ఉన్నాయి."
        ],
        "privacy_ledger_assistant_catalog_checked_detail": [
            "en": "Ross checked private assistant setup. No case files were read or sent.",
            "hi": "Ross ने private assistant setup check किया। कोई case file पढ़ी या भेजी नहीं गई.",
            "bn": "Ross private assistant setup check করেছে। কোনো case file পড়া বা পাঠানো হয়নি.",
            "ta": "Ross private assistant setup check செய்தது. Case file எதையும் படிக்கவோ அனுப்பவோ இல்லை.",
            "te": "Ross private assistant setup check చేసింది. Case file ఏదీ చదవలేదు లేదా పంపలేదు."
        ],
        "privacy_ledger_assistant_update_available_detail": [
            "en": "Ross found a newer private assistant setup listing. No case files were read or sent.",
            "hi": "Ross को newer private assistant setup listing मिली। कोई case file पढ़ी या भेजी नहीं गई.",
            "bn": "Ross newer private assistant setup listing পেয়েছে। কোনো case file পড়া বা পাঠানো হয়নি.",
            "ta": "Ross newer private assistant setup listing கண்டது. Case file எதையும் படிக்கவோ அனுப்பவோ இல்லை.",
            "te": "Ross newer private assistant setup listing కనుగొంది. Case file ఏదీ చదవలేదు లేదా పంపలేదు."
        ],
        "privacy_ledger_private_assistant_download_queued_detail": [
            "en": "Ross will prepare a private assistant on this device. No case files were read or sent.",
            "hi": "Ross इस device पर private assistant prepare करेगा। कोई case file पढ़ी या भेजी नहीं गई.",
            "bn": "Ross এই device-এ private assistant prepare করবে। কোনো case file পড়া বা পাঠানো হয়নি.",
            "ta": "Ross இந்த device-இல் private assistant prepare செய்யும். Case file எதையும் படிக்கவோ அனுப்பவோ இல்லை.",
            "te": "Ross ఈ device లో private assistant prepare చేస్తుంది. Case file ఏదీ చదవలేదు లేదా పంపలేదు."
        ],
        "privacy_ledger_private_assistant_unavailable_detail": [
            "en": "Ross checked this iPhone's private assistant. No case files were read or sent.",
            "hi": "Ross ने इस iPhone का private assistant check किया। कोई case file पढ़ी या भेजी नहीं गई.",
            "bn": "Ross এই iPhone-এর private assistant check করেছে। কোনো case file পড়া বা পাঠানো হয়নি.",
            "ta": "Ross இந்த iPhone-இன் private assistant check செய்தது. Case file எதையும் படிக்கவோ அனுப்பவோ இல்லை.",
            "te": "Ross ఈ iPhone private assistant check చేసింది. Case file ఏదీ చదవలేదు లేదా పంపలేదు."
        ],
        "privacy_ledger_private_assistant_prepared_detail": [
            "en": "Private assistant was prepared on this device.",
            "hi": "Private assistant इसी device पर तैयार हुआ.",
            "bn": "Private assistant এই device-এ প্রস্তুত হয়েছে.",
            "ta": "Private assistant இந்த device-இல் தயாரானது.",
            "te": "Private assistant ఈ device పై సిద్ధమైంది."
        ],
        "privacy_ledger_assistant_download_checked_detail": [
            "en": "Ross checked the assistant download before starting. Case files stayed on this device.",
            "hi": "Ross ने assistant download शुरू करने से पहले check किया। Case files इसी device पर रहीं.",
            "bn": "Ross assistant download শুরু করার আগে check করেছে। Case files এই device-এ রয়ে গেছে.",
            "ta": "Assistant download தொடங்குவதற்கு முன் Ross check செய்தது. Case files இந்த device-இல் இருந்தன.",
            "te": "Assistant download ప్రారంభానికి ముందు Ross check చేసింది. Case files ఈ device పైనే ఉన్నాయి."
        ],
        "privacy_ledger_assistant_ready_detail": [
            "en": "Private assistant was checked and is ready on this device.",
            "hi": "Private assistant check हो चुका है और इसी device पर ready है.",
            "bn": "Private assistant check হয়েছে এবং এই device-এ ready.",
            "ta": "Private assistant check செய்யப்பட்டது; இந்த device-இல் ready.",
            "te": "Private assistant check చేయబడింది మరియు ఈ device పై ready గా ఉంది."
        ],
        "privacy_ledger_assistant_download_failed_detail": [
            "en": "Ross could not finish assistant setup. Case files stayed on this device.",
            "hi": "Ross assistant setup finish नहीं कर पाया। Case files इसी device पर रहीं.",
            "bn": "Ross assistant setup finish করতে পারেনি। Case files এই device-এ রয়ে গেছে.",
            "ta": "Ross assistant setup finish செய்ய முடியவில்லை. Case files இந்த device-இல் இருந்தன.",
            "te": "Ross assistant setup finish చేయలేకపోయింది. Case files ఈ device పైనే ఉన్నాయి."
        ],
        "ask_privacy_label_review_pending": [
            "en": "On-device · review pending",
            "hi": "Device पर · review बाकी",
            "bn": "Device-এ · review বাকি",
            "ta": "Device-இல் · review மீதம்",
            "te": "Device పై · review మిగిలింది"
        ],
        "ask_privacy_label_legal_search": [
            "en": "On-device + Legal Search",
            "hi": "Device पर + Legal Search",
            "bn": "Device-এ + Legal Search",
            "ta": "Device-இல் + Legal Search",
            "te": "Device పై + Legal Search"
        ],
        "ask_privacy_label_on_device_only": [
            "en": "On-device only",
            "hi": "सिर्फ device पर",
            "bn": "শুধু device-এ",
            "ta": "Device-இல் மட்டும்",
            "te": "Device పైనే"
        ],
        "ask_privacy_receipt_review_pending": [
            "en": "Your files stay on this device. A Legal Search query is awaiting your review. Nothing has been sent yet.",
            "hi": "आपकी files इसी device पर रहती हैं। Legal Search query आपके review का इंतज़ार कर रही है। अभी कुछ नहीं भेजा गया.",
            "bn": "আপনার files এই device-এ থাকে। Legal Search query আপনার review-এর অপেক্ষায় আছে। এখনও কিছু পাঠানো হয়নি.",
            "ta": "உங்கள் files இந்த device-இல் இருக்கும். Legal Search query உங்கள் review-க்காக காத்திருக்கிறது. இன்னும் எதுவும் அனுப்பப்படவில்லை.",
            "te": "మీ files ఈ device పైనే ఉంటాయి. Legal Search query మీ review కోసం వేచి ఉంది. ఇంకా ఏదీ పంపబడలేదు."
        ],
        "ask_privacy_receipt_files_and_legal_search": [
            "en": "Ross used your local files and Legal Search results. Case details were removed before searching.",
            "hi": "Ross ने आपकी local files और Legal Search results use किए। Search से पहले case details हटाई गईं.",
            "bn": "Ross আপনার local files এবং Legal Search results ব্যবহার করেছে। Search-এর আগে case details সরানো হয়েছে.",
            "ta": "Ross உங்கள் local files மற்றும் Legal Search results பயன்படுத்தியது. Search செய்யும் முன் case details அகற்றப்பட்டன.",
            "te": "Ross మీ local files మరియు Legal Search results ఉపయోగించింది. Search ముందు case details తీసివేయబడ్డాయి."
        ],
        "ask_privacy_receipt_legal_search": [
            "en": "Ross used Legal Search after you approved. Your case files stayed on this device.",
            "hi": "आपके approve करने के बाद Ross ने Legal Search use किया। आपकी case files इसी device पर रहीं.",
            "bn": "আপনি approve করার পরে Ross Legal Search ব্যবহার করেছে। আপনার case files এই device-এ রয়ে গেছে.",
            "ta": "நீங்கள் approve செய்த பிறகு Ross Legal Search பயன்படுத்தியது. உங்கள் case files இந்த device-இல் இருந்தன.",
            "te": "మీరు approve చేసిన తర్వాత Ross Legal Search ఉపయోగించింది. మీ case files ఈ device పైనే ఉన్నాయి."
        ],
        "ask_privacy_receipt_on_device_only": [
            "en": "Answered using only your files on this device. Nothing was sent online.",
            "hi": "सिर्फ इस device पर मौजूद आपकी files से जवाब दिया गया। Online कुछ नहीं भेजा गया.",
            "bn": "শুধু এই device-এ থাকা আপনার files ব্যবহার করে উত্তর দেওয়া হয়েছে। Online কিছু পাঠানো হয়নি.",
            "ta": "இந்த device-இல் உள்ள உங்கள் files மட்டும் பயன்படுத்தி பதிலளிக்கப்பட்டது. Online எதுவும் அனுப்பப்படவில்லை.",
            "te": "ఈ device లో ఉన్న మీ files మాత్రమే ఉపయోగించి సమాధానం ఇచ్చింది. Online ఏదీ పంపబడలేదు."
        ],
        "ask_private_assistant_needs_repair": [
            "en": "Private assistant needs repair",
            "hi": "Private assistant repair चाहता है",
            "bn": "Private assistant repair দরকার",
            "ta": "Private assistant repair தேவை",
            "te": "Private assistant repair అవసరం"
        ],
        "ask_private_assistant_repair_detail": [
            "en": "Open My assistant and use Repair setup. Ross did not generate a substitute answer from case memory.",
            "hi": "My assistant खोलकर Repair setup use करें। Ross ने case memory से substitute answer नहीं बनाया।",
            "bn": "My assistant খুলে Repair setup ব্যবহার করুন। Ross case memory থেকে substitute answer তৈরি করেনি।",
            "ta": "My assistant திறந்து Repair setup பயன்படுத்தவும். Ross case memory-யில் இருந்து substitute answer உருவாக்கவில்லை.",
            "te": "My assistant తెరిచి Repair setup ఉపయోగించండి. Ross case memory నుండి substitute answer సృష్టించలేదు."
        ],
        "ask_private_assistant_answer_repair_detail": [
            "en": "The private assistant could not open this assistant setup for this answer. Open My assistant and use Repair setup.",
            "hi": "Private assistant इस answer के लिए assistant setup खोल नहीं सका। My assistant खोलकर Repair setup चलाएँ.",
            "bn": "Private assistant এই answer-এর জন্য assistant setup খুলতে পারেনি। My assistant খুলে Repair setup ব্যবহার করুন.",
            "ta": "இந்த answer-க்காக private assistant assistant setup-ஐ திறக்க முடியவில்லை. My assistant திறந்து Repair setup பயன்படுத்தவும்.",
            "te": "ఈ answer కోసం private assistant assistant setup తెరవలేకపోయింది. My assistant తెరిచి Repair setup ఉపయోగించండి."
        ],
        "ask_private_assistant_repair_warning": [
            "en": "Private assistant needs repair before it can answer from files.",
            "hi": "files से answer देने से पहले Private assistant repair चाहता है।",
            "bn": "files থেকে answer দেওয়ার আগে Private assistant repair দরকার।",
            "ta": "files-இல் இருந்து answer செய்யும் முன் Private assistant repair தேவை.",
            "te": "files నుండి answer ఇవ్వడానికి ముందు Private assistant repair అవసరం."
        ],
        "ask_private_assistant_could_not_answer": [
            "en": "Private assistant could not answer",
            "hi": "Private assistant answer नहीं दे सका",
            "bn": "Private assistant answer দিতে পারেনি",
            "ta": "Private assistant answer செய்ய முடியவில்லை",
            "te": "Private assistant answer ఇవ్వలేకపోయింది"
        ],
        "ask_private_assistant_unusable_response_detail": [
            "en": "The private assistant ran, but did not return a usable response for this question.",
            "hi": "private assistant चला, लेकिन इस question के लिए usable response नहीं लौटा।",
            "bn": "private assistant চলেছে, কিন্তু এই question-এর জন্য usable response ফেরায়নি।",
            "ta": "private assistant இயங்கியது, ஆனால் இந்த question-க்கு usable response தரவில்லை.",
            "te": "private assistant నడిచింది, కానీ ఈ question కోసం usable response ఇవ్వలేదు."
        ],
        "ask_private_assistant_no_substitute_detail": [
            "en": "Ross did not generate a substitute answer because a private assistant result is required.",
            "hi": "private assistant result ज़रूरी होने के कारण Ross ने substitute answer नहीं बनाया।",
            "bn": "private assistant result দরকার হওয়ায় Ross substitute answer তৈরি করেনি।",
            "ta": "private assistant result தேவை என்பதால் Ross substitute answer உருவாக்கவில்லை.",
            "te": "private assistant result అవసరం కాబట్టి Ross substitute answer సృష్టించలేదు."
        ],
        "ask_private_assistant_answer_unavailable": [
            "en": "Private assistant answer unavailable",
            "hi": "Private assistant answer उपलब्ध नहीं",
            "bn": "Private assistant answer পাওয়া যাচ্ছে না",
            "ta": "Private assistant answer கிடைக்கவில்லை",
            "te": "Private assistant answer అందుబాటులో లేదు"
        ],
        "ask_private_assistant_answer_unavailable_warning": [
            "en": "Private assistant answer unavailable. Ross did not guess from case memory.",
            "hi": "Private assistant answer उपलब्ध नहीं। Ross ने case memory से guess नहीं किया।",
            "bn": "Private assistant answer পাওয়া যাচ্ছে না। Ross case memory থেকে guess করেনি।",
            "ta": "Private assistant answer கிடைக்கவில்லை. Ross case memory-யிலிருந்து guess செய்யவில்லை.",
            "te": "Private assistant answer అందుబాటులో లేదు. Ross case memory నుండి guess చేయలేదు."
        ],
        "public_law_results_status": [
            "en": "Public-law results",
            "hi": "Public-law results",
            "bn": "Public-law results",
            "ta": "Public-law results",
            "te": "Public-law results"
        ],
        "private_assistant_running_public_law_ready_status": [
            "en": "Private assistant running locally · public-law results ready",
            "hi": "Private assistant locally चल रहा है · public-law results ready",
            "bn": "Private assistant locally চলছে · public-law results ready",
            "ta": "Private assistant locally இயங்குகிறது · public-law results ready",
            "te": "Private assistant locally నడుస్తోంది · public-law results ready"
        ],
        "private_assistant_public_law_results_status": [
            "en": "Private assistant + public-law results",
            "hi": "Private assistant + public-law results",
            "bn": "Private assistant + public-law results",
            "ta": "Private assistant + public-law results",
            "te": "Private assistant + public-law results"
        ],
        "public_law_results_unavailable_status": [
            "en": "Public-law results are unavailable right now.",
            "hi": "Public-law results अभी उपलब्ध नहीं हैं।",
            "bn": "Public-law results এখন পাওয়া যাচ্ছে না।",
            "ta": "Public-law results இப்போது கிடைக்கவில்லை.",
            "te": "Public-law results ప్రస్తుతం అందుబాటులో లేవు."
        ],
        "assistant_local_answers_need_setup": [
            "en": "Local answers need setup on this iPhone.",
            "hi": "स्थानीय उत्तरों के लिए इस iPhone पर सेटअप चाहिए।",
            "bn": "স্থানীয় উত্তরের জন্য এই iPhone-এ সেটআপ দরকার।",
            "ta": "உள்ளூர் பதில்களுக்கு இந்த iPhone-இல் அமைப்பு தேவை.",
            "te": "స్థానిక సమాధానాలకు ఈ iPhone లో సెటప్ అవసరం."
        ],
        "assistant_setup_section": [
            "en": "Setup",
            "hi": "सेटअप",
            "bn": "সেটআপ",
            "ta": "அமைப்பு",
            "te": "సెటప్"
        ],
        "assistant_setup_on_phone": [
            "en": "Set up on this iPhone",
            "hi": "इस iPhone पर सेट करें",
            "bn": "এই iPhone-এ সেট আপ করুন",
            "ta": "இந்த iPhone-இல் அமைக்கவும்",
            "te": "ఈ iPhone లో సెటప్ చేయండి"
        ],
        "assistant_choose_option_files": [
            "en": "Choose the option that fits the files you usually handle.",
            "hi": "आप जिन फ़ाइलों पर आमतौर पर काम करते हैं, उनके अनुसार विकल्प चुनें।",
            "bn": "আপনি সাধারণত যে ফাইল সামলান, তার সঙ্গে মানানসই বিকল্প বেছে নিন।",
            "ta": "நீங்கள் வழக்கமாக கையாளும் கோப்புகளுக்கு பொருந்தும் விருப்பத்தைத் தேர்வுசெய்க.",
            "te": "మీరు సాధారణంగా చూసే ఫైళ్లకు సరిపోయే ఎంపికను ఎంచుకోండి."
        ],
        "assistant_wifi_section": [
            "en": "Wi-Fi",
            "hi": "Wi-Fi",
            "bn": "Wi-Fi",
            "ta": "Wi-Fi",
            "te": "Wi-Fi"
        ],
        "assistant_wifi_larger_downloads": [
            "en": "Use Wi-Fi for larger downloads",
            "hi": "बड़े डाउनलोड के लिए Wi-Fi उपयोग करें",
            "bn": "বড় ডাউনলোডের জন্য Wi-Fi ব্যবহার করুন",
            "ta": "பெரிய பதிவிறக்கங்களுக்கு Wi-Fi பயன்படுத்தவும்",
            "te": "పెద్ద డౌన్‌లోడ్‌లకు Wi-Fi ఉపయోగించండి"
        ],
        "assistant_wifi_larger_downloads_detail": [
            "en": "Ross waits for Wi-Fi before downloading larger assistant setup files.",
            "hi": "बड़ी सहायक सेटअप फ़ाइलें डाउनलोड करने से पहले Ross Wi-Fi की प्रतीक्षा करता है।",
            "bn": "বড় সহকারী সেটআপ ফাইল ডাউনলোডের আগে Ross Wi-Fi-এর অপেক্ষা করে।",
            "ta": "பெரிய உதவியாளர் அமைப்பு கோப்புகளை பதிவிறக்குவதற்கு முன் Ross Wi-Fi காத்திருக்கும்.",
            "te": "పెద్ద సహాయక సెటప్ ఫైళ్లను డౌన్‌లోడ్ చేయడానికి ముందు Ross Wi-Fi కోసం వేచి ఉంటుంది."
        ],
        "assistant_allow_mobile_data": [
            "en": "Allow mobile data",
            "hi": "मोबाइल डेटा की अनुमति दें",
            "bn": "মোবাইল ডেটা অনুমতি দিন",
            "ta": "மொபைல் தரவை அனுமதிக்கவும்",
            "te": "మొబైల్ డేటాను అనుమతించండి"
        ],
        "assistant_allow_mobile_data_detail": [
            "en": "Only use cellular data for assistant setup when you choose to.",
            "hi": "सहायक सेटअप के लिए cellular data तभी उपयोग करें जब आप चुनें।",
            "bn": "আপনি চাইলে তবেই সহকারী সেটআপে cellular data ব্যবহার করুন।",
            "ta": "நீங்கள் தேர்வு செய்தால் மட்டுமே உதவியாளர் அமைப்புக்கு cellular data பயன்படுத்தவும்.",
            "te": "మీరు ఎంచుకున్నప్పుడు మాత్రమే సహాయక సెటప్‌కు cellular data ఉపయోగించండి."
        ],
        "assistant_background_downloads": [
            "en": "Background downloads",
            "hi": "बैकग्राउंड डाउनलोड",
            "bn": "ব্যাকগ্রাউন্ড ডাউনলোড",
            "ta": "பின்னணி பதிவிறக்கங்கள்",
            "te": "బ్యాక్‌గ్రౌండ్ డౌన్‌లోడ్‌లు"
        ],
        "assistant_background_downloads_detail": [
            "en": "Keep assistant downloads eligible to continue when Ross is backgrounded.",
            "hi": "Ross background में होने पर सहायक डाउनलोड जारी रहने योग्य रखें।",
            "bn": "Ross background-এ থাকলেও সহকারী ডাউনলোড চালিয়ে যাওয়ার সুযোগ রাখুন।",
            "ta": "Ross background-இல் இருந்தாலும் உதவியாளர் பதிவிறக்கங்கள் தொடர அனுமதிக்கவும்.",
            "te": "Ross background లో ఉన్నప్పుడు కూడా సహాయక డౌన్‌లోడ్‌లు కొనసాగేందుకు అనుమతించండి."
        ],
        "assistant_update_checks_title": [
            "en": "Check for assistant updates",
            "hi": "assistant updates जांचें",
            "bn": "assistant updates দেখুন",
            "ta": "assistant updates சரிபார்க்கவும்",
            "te": "assistant updates తనిఖీ చేయండి"
        ],
        "assistant_update_checks_detail": [
            "en": "Ross checks assistant listings and asks before replacing assistant setup.",
            "hi": "Ross assistant listings जांचता है और setup बदलने से पहले पूछता है।",
            "bn": "Ross assistant listings দেখে এবং setup বদলানোর আগে জিজ্ঞাসা করে।",
            "ta": "Ross assistant listings சரிபார்த்து setup மாற்றுவதற்கு முன் கேட்கும்.",
            "te": "Ross assistant listings తనిఖీ చేసి setup మార్చే ముందు అడుగుతుంది."
        ],
        "assistant_update_title": [
            "en": "Assistant update",
            "hi": "Assistant update",
            "bn": "Assistant update",
            "ta": "Assistant update",
            "te": "Assistant update"
        ],
        "assistant_update_available": [
            "en": "%@ has a newer assistant setup available.",
            "hi": "%@ के लिए नया assistant setup उपलब्ध है।",
            "bn": "%@-এর জন্য নতুন assistant setup উপলব্ধ।",
            "ta": "%@-க்கு புதிய assistant setup உள்ளது.",
            "te": "%@ కోసం కొత్త assistant setup అందుబాటులో ఉంది."
        ],
        "assistant_update_detail": [
            "en": "Ross will download it with the same resumable Wi-Fi-first rules. Existing assistant setup stays until the new setup verifies.",
            "hi": "Ross इसे उन्हीं resumable Wi-Fi-first rules से तैयार करेगा। नया setup verify होने तक मौजूदा assistant setup रहेगा।",
            "bn": "Ross একই resumable Wi-Fi-first rules দিয়ে এটি প্রস্তুত করবে। নতুন setup verify না হওয়া পর্যন্ত বর্তমান assistant setup থাকবে।",
            "ta": "Ross அதையே resumable Wi-Fi-first rules உடன் தயாரிக்கும். புதிய setup verify ஆகும் வரை தற்போதைய assistant setup இருக்கும்.",
            "te": "Ross అదే resumable Wi-Fi-first rules తో దాన్ని సిద్ధం చేస్తుంది. కొత్త setup verify అయ్యే వరకు ప్రస్తుత assistant setup అలాగే ఉంటుంది."
        ],
        "assistant_update_on_wifi": [
            "en": "Update on Wi-Fi",
            "hi": "Wi-Fi पर update करें",
            "bn": "Wi-Fi-তে update করুন",
            "ta": "Wi-Fi-இல் update செய்யவும்",
            "te": "Wi-Fi లో update చేయండి"
        ],
        "assistant_storage_title": [
            "en": "Assistant storage",
            "hi": "Assistant storage",
            "bn": "Assistant storage",
            "ta": "Assistant storage",
            "te": "Assistant storage"
        ],
        "assistant_storage_detail": [
            "en": "App updates keep assistant setup files in Ross storage. A full uninstall removes the app container; iOS does not let Ross ask a question during uninstall.",
            "hi": "App updates assistant setup files को Ross storage में रखते हैं। Full uninstall app container हटाता है; uninstall के दौरान iOS Ross को question पूछने नहीं देता।",
            "bn": "App updates assistant setup files Ross storage-এ রাখে। Full uninstall app container সরায়; uninstall-এর সময় iOS Ross-কে question জিজ্ঞাসা করতে দেয় না।",
            "ta": "App updates assistant setup files-ஐ Ross storage-இல் வைத்திருக்கும். Full uninstall app container-ஐ நீக்கும்; uninstall நடக்கும் போது iOS Ross-ஐ question கேட்க அனுமதிக்காது.",
            "te": "App updates assistant setup files ను Ross storage లో ఉంచుతాయి. Full uninstall app container ను తొలగిస్తుంది; uninstall సమయంలో iOS Ross ను question అడగనివ్వదు."
        ],
        "assistant_delete_setup_files_title": [
            "en": "Delete assistant setup files",
            "hi": "assistant setup files delete करें",
            "bn": "assistant setup files delete করুন",
            "ta": "assistant setup files delete செய்யவும்",
            "te": "assistant setup files delete చేయండి"
        ],
        "assistant_delete_setup_files_detail": [
            "en": "Keeps matters and drafts, removes local assistant setup files and resume data.",
            "hi": "matters और drafts रखता है, local assistant setup files और resume data हटाता है।",
            "bn": "matters এবং drafts রেখে local assistant setup files ও resume data সরায়।",
            "ta": "matters மற்றும் drafts வைத்துக்கொண்டு local assistant setup files மற்றும் resume data நீக்கும்.",
            "te": "matters మరియు drafts ను ఉంచి local assistant setup files మరియు resume data ను తొలగిస్తుంది."
        ],
        "privacy_summary": [
            "en": "Privacy summary",
            "hi": "Privacy summary",
            "bn": "Privacy summary",
            "ta": "Privacy summary",
            "te": "Privacy summary"
        ],
        "privacy_summary_detail": [
            "en": "In the last 30 days, 0 case details left this phone. Legal Search only used sanitized legal queries.",
            "hi": "पिछले 30 दिनों में 0 case details इस phone से बाहर गए। Legal Search ने केवल sanitized legal queries use कीं।",
            "bn": "গত 30 দিনে 0 case details এই phone ছেড়েছে। Legal Search শুধু sanitized legal queries ব্যবহার করেছে।",
            "ta": "கடைசி 30 நாட்களில் 0 case details இந்த phone-ஐ விட்டுச் சென்றன. Legal Search sanitized legal queries மட்டும் பயன்படுத்தியது.",
            "te": "గత 30 రోజుల్లో 0 case details ఈ phone బయటకు వెళ్లాయి. Legal Search sanitized legal queries మాత్రమే ఉపయోగించింది."
        ],
        "privacy_ledger_empty": [
            "en": "Ross has not logged any local or network actions yet.",
            "hi": "Ross ने अभी तक कोई local या network actions log नहीं किए हैं।",
            "bn": "Ross এখনও কোনো local বা network actions log করেনি।",
            "ta": "Ross இன்னும் local அல்லது network actions எதையும் log செய்யவில்லை.",
            "te": "Ross ఇంకా ఏ local లేదా network actions log చేయలేదు."
        ],
        "assistant_check": [
            "en": "Assistant check",
            "hi": "Assistant check",
            "bn": "Assistant check",
            "ta": "Assistant check",
            "te": "Assistant check"
        ],
        "assistant_check_after_setup": [
            "en": "Ross will check the assistant after setup.",
            "hi": "setup के बाद Ross assistant check करेगा।",
            "bn": "setup-এর পরে Ross assistant check করবে।",
            "ta": "setup பிறகு Ross assistant check செய்யும்.",
            "te": "setup తర్వాత Ross assistant check చేస్తుంది."
        ],
        "assistant_status_ready_title": [
            "en": "My assistant is ready",
            "hi": "My assistant ready है",
            "bn": "My assistant ready",
            "ta": "My assistant ready",
            "te": "My assistant ready"
        ],
        "assistant_status_ready_detail": [
            "en": "Ross can help read files, draft notes, and answer from local matter files on this device.",
            "hi": "Ross इस device पर local matter files से files पढ़ने, notes draft करने, और answers देने में help कर सकता है।",
            "bn": "Ross এই device-এ local matter files থেকে files পড়তে, notes draft করতে, এবং answers দিতে help করতে পারে।",
            "ta": "Ross இந்த device-இல் local matter files-இருந்து files படிக்க, notes draft செய்ய, answers தர help செய்யும்.",
            "te": "Ross ఈ device లో local matter files నుండి files చదవడానికి, notes draft చేయడానికి, answers ఇవ్వడానికి help చేస్తుంది."
        ],
        "assistant_status_setting_up_title": [
            "en": "My assistant is setting up",
            "hi": "My assistant setup हो रहा है",
            "bn": "My assistant setup হচ্ছে",
            "ta": "My assistant setup ஆகிறது",
            "te": "My assistant setup అవుతోంది"
        ],
        "assistant_status_setting_up_detail": [
            "en": "You can keep working while Ross finishes setup on this device.",
            "hi": "Ross इस device पर setup finish करते समय आप काम जारी रख सकते हैं।",
            "bn": "Ross এই device-এ setup শেষ করার সময় আপনি কাজ চালিয়ে যেতে পারেন।",
            "ta": "Ross இந்த device-இல் setup முடிக்கும் போது நீங்கள் வேலை தொடரலாம்.",
            "te": "Ross ఈ device లో setup పూర్తి చేసే సమయంలో మీరు పని కొనసాగించవచ్చు."
        ],
        "assistant_status_waiting_wifi_detail": [
            "en": "Ross will continue setup when Wi-Fi is available.",
            "hi": "Wi-Fi उपलब्ध होने पर Ross setup continue करेगा।",
            "bn": "Wi-Fi available হলে Ross setup continue করবে।",
            "ta": "Wi-Fi கிடைக்கும் போது Ross setup continue செய்யும்.",
            "te": "Wi-Fi అందుబాటులో ఉన్నప్పుడు Ross setup continue చేస్తుంది."
        ],
        "assistant_status_needs_attention_title": [
            "en": "My assistant needs attention",
            "hi": "My assistant को attention चाहिए",
            "bn": "My assistant attention চায়",
            "ta": "My assistant-க்கு attention தேவை",
            "te": "My assistant కు attention కావాలి"
        ],
        "assistant_status_paused_detail": [
            "en": "Setup is paused. You can continue working and resume whenever you are ready.",
            "hi": "Setup paused है। आप काम जारी रख सकते हैं और ready होने पर resume कर सकते हैं।",
            "bn": "Setup paused। আপনি কাজ চালিয়ে যেতে পারেন এবং ready হলে resume করতে পারেন।",
            "ta": "Setup paused. நீங்கள் வேலை தொடரலாம்; ready ஆனபோது resume செய்யலாம்.",
            "te": "Setup paused. మీరు పని కొనసాగించవచ్చు; ready అయినప్పుడు resume చేయవచ్చు."
        ],
        "assistant_status_storage_detail": [
            "en": "Free up space and try again.",
            "hi": "Space खाली करें और फिर कोशिश करें।",
            "bn": "Space খালি করে আবার চেষ্টা করুন।",
            "ta": "Space காலி செய்து மீண்டும் முயற்சிக்கவும்.",
            "te": "Space ఖాళీ చేసి మళ్లీ ప్రయత్నించండి."
        ],
        "assistant_status_retry_detail": [
            "en": "Setup could not finish. Open My assistant to retry or repair setup.",
            "hi": "Setup finish नहीं हो पाया। retry या Repair setup के लिए My assistant खोलें।",
            "bn": "Setup finish হয়নি। retry বা Repair setup করতে My assistant খুলুন।",
            "ta": "Setup finish ஆகவில்லை. retry அல்லது Repair setup செய்ய My assistant திறக்கவும்.",
            "te": "Setup finish కాలేదు. retry లేదా Repair setup కోసం My assistant తెరవండి."
        ],
        "assistant_status_preparing_detail": [
            "en": "Ross is still preparing on this device.",
            "hi": "Ross अभी भी इस device पर prepare कर रहा है।",
            "bn": "Ross এখনও এই device-এ prepare করছে।",
            "ta": "Ross இன்னும் இந்த device-இல் prepare செய்கிறது.",
            "te": "Ross ఇంకా ఈ device లో prepare చేస్తోంది."
        ],
        "assistant_status_needs_check_detail": [
            "en": "Ross needs to check setup before answering legal questions.",
            "hi": "Legal questions का answer देने से पहले Ross को setup check करना होगा।",
            "bn": "Legal questions-এর answer দেওয়ার আগে Ross-কে setup check করতে হবে।",
            "ta": "Legal questions-க்கு answer தருவதற்கு முன் Ross setup check செய்ய வேண்டும்.",
            "te": "Legal questions కు answer ఇవ్వడానికి ముందు Ross setup check చేయాలి."
        ],
        "assistant_status_not_set_up_title": [
            "en": "My assistant is not set up",
            "hi": "My assistant setup नहीं है",
            "bn": "My assistant setup করা নেই",
            "ta": "My assistant setup செய்யப்படவில்லை",
            "te": "My assistant setup కాలేదు"
        ],
        "assistant_status_not_set_up_detail": [
            "en": "Ross can still organize matters, tasks, dates, and files. Legal answers need assistant setup.",
            "hi": "Ross फिर भी matters, tasks, dates, और files organize कर सकता है। Legal answers के लिए assistant setup चाहिए।",
            "bn": "Ross এখনও matters, tasks, dates, এবং files organize করতে পারে। Legal answers-এর জন্য assistant setup দরকার।",
            "ta": "Ross இன்னும் matters, tasks, dates மற்றும் files organize செய்ய முடியும். Legal answers-க்கு assistant setup தேவை.",
            "te": "Ross ఇంకా matters, tasks, dates, files organize చేయగలదు. Legal answers కు assistant setup కావాలి."
        ],
        "assistant_verification_no_setup": [
            "en": "No assistant setup is active yet.",
            "hi": "अभी कोई assistant setup active नहीं है।",
            "bn": "এখনও কোনো assistant setup active নেই।",
            "ta": "இன்னும் assistant setup active இல்லை.",
            "te": "ఇంకా assistant setup active లేదు."
        ],
        "assistant_verification_test_active": [
            "en": "Test assistant setup is active for this build.",
            "hi": "इस build के लिए test assistant setup active है।",
            "bn": "এই build-এর জন্য test assistant setup active আছে।",
            "ta": "இந்த build-க்கு test assistant setup active உள்ளது.",
            "te": "ఈ build కోసం test assistant setup active ఉంది."
        ],
        "assistant_verification_test_disabled": [
            "en": "Test assistant setup is disabled for this build.",
            "hi": "इस build के लिए test assistant setup disabled है।",
            "bn": "এই build-এর জন্য test assistant setup disabled আছে।",
            "ta": "இந்த build-க்கு test assistant setup disabled உள்ளது.",
            "te": "ఈ build కోసం test assistant setup disabled ఉంది."
        ],
        "assistant_verification_pending": [
            "en": "Ross will verify assistant setup after setup finishes.",
            "hi": "setup पूरा होने के बाद Ross assistant setup verify करेगा।",
            "bn": "setup শেষ হলে Ross assistant setup verify করবে।",
            "ta": "setup முடிந்த பிறகு Ross assistant setup verify செய்யும்.",
            "te": "setup పూర్తయ్యాక Ross assistant setup verify చేస్తుంది."
        ],
        "assistant_verification_ready": [
            "en": "Assistant setup opened and verified on this iPhone.",
            "hi": "Assistant setup इस iPhone पर खुला और verify हुआ।",
            "bn": "Assistant setup এই iPhone-এ খুলেছে এবং verify হয়েছে।",
            "ta": "Assistant setup இந்த iPhone-இல் திறந்து verify செய்யப்பட்டது.",
            "te": "Assistant setup ఈ iPhone లో తెరుచుకుని verify అయ్యింది."
        ],
        "assistant_verification_opened": [
            "en": "Assistant setup opened on this iPhone.",
            "hi": "Assistant setup इस iPhone पर खुला।",
            "bn": "Assistant setup এই iPhone-এ খুলেছে।",
            "ta": "Assistant setup இந்த iPhone-இல் திறந்தது.",
            "te": "Assistant setup ఈ iPhone లో తెరుచుకుంది."
        ],
        "assistant_verification_needs_repair": [
            "en": "Assistant setup needs Repair setup before Ross can use it.",
            "hi": "Ross इसे use करे उससे पहले Assistant setup को Repair setup चाहिए।",
            "bn": "Ross এটি ব্যবহার করার আগে Assistant setup-এ Repair setup দরকার।",
            "ta": "Ross பயன்படுத்துவதற்கு முன் Assistant setup-க்கு Repair setup தேவை.",
            "te": "Ross దీన్ని ఉపయోగించే ముందు Assistant setup కు Repair setup కావాలి."
        ],
        "assistant_verification_missing": [
            "en": "Assistant setup is missing. Open My assistant and set up again.",
            "hi": "Assistant setup missing है। My assistant खोलकर फिर setup करें।",
            "bn": "Assistant setup missing। My assistant খুলে আবার setup করুন।",
            "ta": "Assistant setup missing. My assistant திறந்து மீண்டும் setup செய்யவும்.",
            "te": "Assistant setup missing. My assistant తెరిచి మళ్లీ setup చేయండి."
        ],
        "assistant_repair_setup_removes_broken": [
            "en": "Repair setup removes the broken assistant setup and starts a fresh local check.",
            "hi": "Repair setup टूटे assistant setup को हटाकर नया local check शुरू करता है।",
            "bn": "Repair setup ভাঙা assistant setup সরিয়ে নতুন local check শুরু করে।",
            "ta": "Repair setup உடைந்த assistant setup-ஐ நீக்கி புதிய local check தொடங்கும்.",
            "te": "Repair setup పాడైన assistant setup ను తొలగించి కొత్త local check ప్రారంభిస్తుంది."
        ],
        "runtime_health_deterministic_dev": [
            "en": "Development assistant is active for this build.",
            "hi": "इस build के लिए development assistant active है।",
            "bn": "এই build-এর জন্য development assistant active আছে।",
            "ta": "இந்த build-க்கு development assistant active உள்ளது.",
            "te": "ఈ build కోసం development assistant active ఉంది."
        ],
        "runtime_health_llama_missing_setup": [
            "en": "Assistant setup is missing or incomplete. Open My assistant to set up again.",
            "hi": "Assistant setup missing या incomplete है। My assistant खोलकर फिर setup करें।",
            "bn": "Assistant setup missing বা incomplete। My assistant খুলে আবার setup করুন।",
            "ta": "Assistant setup missing அல்லது incomplete. My assistant திறந்து மீண்டும் setup செய்யவும்.",
            "te": "Assistant setup missing లేదా incomplete. My assistant తెరిచి మళ్లీ setup చేయండి."
        ],
        "runtime_health_llama_ready": [
            "en": "Private assistant is ready on this iPhone.",
            "hi": "Private assistant इस iPhone पर ready है।",
            "bn": "Private assistant এই iPhone-এ ready।",
            "ta": "Private assistant இந்த iPhone-இல் ready.",
            "te": "Private assistant ఈ iPhone లో ready."
        ],
        "runtime_health_llama_needs_repair": [
            "en": "Ross could not open this assistant setup. Open My assistant and use Repair setup.",
            "hi": "Ross यह assistant setup खोल नहीं पाया। My assistant खोलकर Repair setup चलाएँ।",
            "bn": "Ross এই assistant setup খুলতে পারেনি। My assistant খুলে Repair setup ব্যবহার করুন।",
            "ta": "Ross இந்த assistant setup-ஐ திறக்க முடியவில்லை. My assistant திறந்து Repair setup பயன்படுத்தவும்.",
            "te": "Ross ఈ assistant setup తెరవలేకపోయింది. My assistant తెరిచి Repair setup ఉపయోగించండి."
        ],
        "runtime_health_foundation_available": [
            "en": "Private assistant on this device is available.",
            "hi": "इस device पर private assistant available है।",
            "bn": "এই device-এ private assistant available।",
            "ta": "இந்த device-இல் private assistant available.",
            "te": "ఈ device లో private assistant available."
        ],
        "runtime_health_foundation_unavailable": [
            "en": "The on-device private assistant is not available on this iPhone yet.",
            "hi": "On-device private assistant अभी इस iPhone पर available नहीं है।",
            "bn": "On-device private assistant এখনও এই iPhone-এ available নয়।",
            "ta": "On-device private assistant இன்னும் இந்த iPhone-இல் available இல்லை.",
            "te": "On-device private assistant ఇంకా ఈ iPhone లో available లేదు."
        ],
        "runtime_health_foundation_unknown": [
            "en": "The on-device private assistant availability is unknown.",
            "hi": "On-device private assistant availability अभी unknown है।",
            "bn": "On-device private assistant availability এখন unknown।",
            "ta": "On-device private assistant availability இப்போது unknown.",
            "te": "On-device private assistant availability ప్రస్తుతం unknown."
        ],
        "runtime_health_foundation_could_not_open": [
            "en": "Ross could not open the private assistant on this iPhone.",
            "hi": "Ross इस iPhone पर private assistant खोल नहीं पाया।",
            "bn": "Ross এই iPhone-এ private assistant খুলতে পারেনি।",
            "ta": "Ross இந்த iPhone-இல் private assistant திறக்க முடியவில்லை.",
            "te": "Ross ఈ iPhone లో private assistant తెరవలేకపోయింది."
        ],
        "runtime_health_dev_artifacts_disabled": [
            "en": "Development-only assistant setup is disabled for this build.",
            "hi": "इस build के लिए development-only assistant setup disabled है।",
            "bn": "এই build-এর জন্য development-only assistant setup disabled।",
            "ta": "இந்த build-க்கு development-only assistant setup disabled உள்ளது.",
            "te": "ఈ build కోసం development-only assistant setup disabled ఉంది."
        ],
        "runtime_health_private_assistant_unavailable": [
            "en": "Private assistant is unavailable on this device right now.",
            "hi": "Private assistant अभी इस device पर unavailable है।",
            "bn": "Private assistant এখন এই device-এ unavailable।",
            "ta": "Private assistant இப்போது இந்த device-இல் unavailable.",
            "te": "Private assistant ప్రస్తుతం ఈ device లో unavailable."
        ],
        "ready_for_private_answers_on_iphone": [
            "en": "Ready for private answers on this iPhone.",
            "hi": "इस iPhone पर private answers के लिए ready।",
            "bn": "এই iPhone-এ private answers-এর জন্য ready।",
            "ta": "இந்த iPhone-இல் private answers-க்கு ready.",
            "te": "ఈ iPhone లో private answers కోసం ready."
        ],
        "no_private_answer_recorded_yet": [
            "en": "No private answer recorded yet",
            "hi": "अभी कोई private answer recorded नहीं है",
            "bn": "এখনও কোনো private answer recorded নেই",
            "ta": "இன்னும் private answer recorded இல்லை",
            "te": "ఇంకా private answer recorded లేదు"
        ],
        "started_but_did_not_finish": [
            "en": "Started but did not finish",
            "hi": "शुरू हुआ लेकिन finish नहीं हुआ",
            "bn": "শুরু হয়েছে কিন্তু finish হয়নি",
            "ta": "தொடங்கியது ஆனால் finish ஆகவில்லை",
            "te": "ప్రారంభమైంది కానీ finish కాలేదు"
        ],
        "status": [
            "en": "Status",
            "hi": "Status",
            "bn": "Status",
            "ta": "Status",
            "te": "Status"
        ],
        "yes": [
            "en": "Yes",
            "hi": "हाँ",
            "bn": "হ্যাঁ",
            "ta": "ஆம்",
            "te": "అవును"
        ],
        "no": [
            "en": "No",
            "hi": "नहीं",
            "bn": "না",
            "ta": "இல்லை",
            "te": "లేదు"
        ],
        "local_file": [
            "en": "Local file",
            "hi": "Local file",
            "bn": "Local file",
            "ta": "Local file",
            "te": "Local file"
        ],
        "last_private_answer": [
            "en": "Last private answer",
            "hi": "Last private answer",
            "bn": "Last private answer",
            "ta": "Last private answer",
            "te": "Last private answer"
        ],
        "setup_resets": [
            "en": "Setup resets",
            "hi": "Setup resets",
            "bn": "Setup resets",
            "ta": "Setup resets",
            "te": "Setup resets"
        ],
        "assistant_can_answer": [
            "en": "Can answer",
            "hi": "Answer दे सकता है",
            "bn": "Answer দিতে পারে",
            "ta": "Answer செய்ய முடியும்",
            "te": "Answer ఇవ్వగలదు"
        ],
        "setup_file_present": [
            "en": "Setup file present",
            "hi": "Setup file मौजूद है",
            "bn": "Setup file আছে",
            "ta": "Setup file உள்ளது",
            "te": "Setup file ఉంది"
        ],
        "last_answer_check": [
            "en": "Last answer check",
            "hi": "Last answer check",
            "bn": "Last answer check",
            "ta": "Last answer check",
            "te": "Last answer check"
        ],
        "last_check_result": [
            "en": "Last check result",
            "hi": "Last check result",
            "bn": "Last check result",
            "ta": "Last check result",
            "te": "Last check result"
        ],
        "approx_time": [
            "en": "Approx time",
            "hi": "Approx time",
            "bn": "Approx time",
            "ta": "Approx time",
            "te": "Approx time"
        ],
        "public_law_check": [
            "en": "Public-law check",
            "hi": "Public-law check",
            "bn": "Public-law check",
            "ta": "Public-law check",
            "te": "Public-law check"
        ],
        "none_yet": [
            "en": "None yet",
            "hi": "अभी नहीं",
            "bn": "এখনও নেই",
            "ta": "இன்னும் இல்லை",
            "te": "ఇంకా లేదు"
        ],
        "workspace_refreshes": [
            "en": "Workspace refreshes",
            "hi": "Workspace refreshes",
            "bn": "Workspace refreshes",
            "ta": "Workspace refreshes",
            "te": "Workspace refreshes"
        ],
        "check_private_assistant_with_sample_file": [
            "en": "Check private assistant with a sample file",
            "hi": "Sample file से private assistant check करें",
            "bn": "Sample file দিয়ে private assistant check করুন",
            "ta": "Sample file கொண்டு private assistant check செய்யவும்",
            "te": "Sample file తో private assistant check చేయండి"
        ],
        "checking_private_assistant_sample_file": [
            "en": "Checking private assistant with a sample file...",
            "hi": "Sample file से private assistant check हो रहा है...",
            "bn": "Sample file দিয়ে private assistant check হচ্ছে...",
            "ta": "Sample file கொண்டு private assistant check செய்கிறது...",
            "te": "Sample file తో private assistant check చేస్తోంది..."
        ],
        "completed": [
            "en": "Completed",
            "hi": "पूरा हुआ",
            "bn": "সম্পন্ন",
            "ta": "முடிந்தது",
            "te": "పూర్తయింది"
        ],
        "needs_attention": [
            "en": "Needs attention",
            "hi": "ध्यान चाहिए",
            "bn": "মনোযোগ দরকার",
            "ta": "கவனம் தேவை",
            "te": "శ్రద్ధ అవసరం"
        ],
        "my_assistant_ready": [
            "en": "My assistant is ready",
            "hi": "My assistant तैयार है",
            "bn": "My assistant প্রস্তুত",
            "ta": "My assistant தயாராக உள்ளது",
            "te": "My assistant సిద్ధంగా ఉంది"
        ],
        "my_assistant_needs_attention": [
            "en": "My assistant needs attention",
            "hi": "My assistant को attention चाहिए",
            "bn": "My assistant-এর attention দরকার",
            "ta": "My assistant-க்கு attention தேவை",
            "te": "My assistant కు attention అవసరం"
        ],
        "ready": [
            "en": "Ready",
            "hi": "तैयार",
            "bn": "প্রস্তুত",
            "ta": "தயார்",
            "te": "సిద్ధం"
        ],
        "use_this_option": [
            "en": "Use this option",
            "hi": "यह option use करें",
            "bn": "এই option use করুন",
            "ta": "இந்த option use செய்யவும்",
            "te": "ఈ option use చేయండి"
        ],
        "remove": [
            "en": "Remove",
            "hi": "हटाएं",
            "bn": "সরান",
            "ta": "நீக்கவும்",
            "te": "తొలగించండి"
        ],
        "assistant_files": [
            "en": "Assistant files",
            "hi": "Assistant files",
            "bn": "Assistant files",
            "ta": "Assistant files",
            "te": "Assistant files"
        ],
        "cleaning": [
            "en": "Cleaning",
            "hi": "Cleaning",
            "bn": "Cleaning",
            "ta": "Cleaning",
            "te": "Cleaning"
        ],
        "reclaim": [
            "en": "Reclaim",
            "hi": "Reclaim",
            "bn": "Reclaim",
            "ta": "Reclaim",
            "te": "Reclaim"
        ],
        "interrupted_downloads": [
            "en": "Interrupted downloads",
            "hi": "Interrupted downloads",
            "bn": "Interrupted downloads",
            "ta": "Interrupted downloads",
            "te": "Interrupted downloads"
        ],
        "resume_data": [
            "en": "Resume data",
            "hi": "Resume data",
            "bn": "Resume data",
            "ta": "Resume data",
            "te": "Resume data"
        ],
        "device_cache": [
            "en": "Device cache",
            "hi": "Device cache",
            "bn": "Device cache",
            "ta": "Device cache",
            "te": "Device cache"
        ],
        "cleaning_interrupted_setup_files": [
            "en": "Cleaning interrupted setup files...",
            "hi": "interrupted setup files clean हो रहे हैं...",
            "bn": "interrupted setup files clean হচ্ছে...",
            "ta": "interrupted setup files clean ஆகின்றன...",
            "te": "interrupted setup files clean అవుతున్నాయి..."
        ],
        "reclaimed_assistant_storage": [
            "en": "Reclaimed %@.",
            "hi": "%@ reclaim हुआ।",
            "bn": "%@ reclaim হয়েছে।",
            "ta": "%@ reclaim செய்யப்பட்டது.",
            "te": "%@ reclaim అయింది."
        ],
        "no_extra_assistant_setup_files": [
            "en": "No extra assistant setup files found.",
            "hi": "extra assistant setup files नहीं मिले।",
            "bn": "extra assistant setup files পাওয়া যায়নি।",
            "ta": "extra assistant setup files இல்லை.",
            "te": "extra assistant setup files కనబడలేదు."
        ],
        "answer_style": [
            "en": "Answer style",
            "hi": "Answer style",
            "bn": "Answer style",
            "ta": "Answer style",
            "te": "Answer style"
        ],
        "current_style": [
            "en": "Current style",
            "hi": "Current style",
            "bn": "Current style",
            "ta": "Current style",
            "te": "Current style"
        ],
        "grounded_legal_answers": [
            "en": "Grounded legal answers",
            "hi": "Grounded legal answers",
            "bn": "Grounded legal answers",
            "ta": "Grounded legal answers",
            "te": "Grounded legal answers"
        ],
        "answer_style_detail": [
            "en": "Ross uses conservative defaults for legal Q&A so answers stay concise and tied to your files.",
            "hi": "legal Q&A में answers concise और आपकी files से tied रहें, इसलिए Ross conservative defaults use करता है।",
            "bn": "legal Q&A-তে answers concise এবং আপনার files-এর সঙ্গে tied রাখতে Ross conservative defaults ব্যবহার করে।",
            "ta": "legal Q&A-யில் answers concise ஆகவும் உங்கள் files-க்கு tied ஆகவும் இருக்க Ross conservative defaults பயன்படுத்துகிறது.",
            "te": "legal Q&A లో answers concise గా మరియు మీ files కు tied గా ఉండేందుకు Ross conservative defaults ఉపయోగిస్తుంది."
        ],
        "answer_style_tuning_detail": [
            "en": "Tune how boldly the private assistant writes. The recommended defaults keep answers grounded and concise.",
            "hi": "private assistant कितना bold लिखे, यह tune करें। recommended defaults answers को grounded और concise रखते हैं।",
            "bn": "private assistant কতটা bold লিখবে তা tune করুন। recommended defaults answers grounded এবং concise রাখে।",
            "ta": "private assistant எவ்வளவு bold ஆக எழுதும் என்பதை tune செய்யவும். recommended defaults answers grounded மற்றும் concise ஆக வைத்திருக்கும்.",
            "te": "private assistant ఎంత bold గా రాయాలో tune చేయండి. recommended defaults answers ను grounded మరియు concise గా ఉంచుతాయి."
        ],
        "creativity": [
            "en": "Creativity",
            "hi": "Creativity",
            "bn": "Creativity",
            "ta": "Creativity",
            "te": "Creativity"
        ],
        "focus": [
            "en": "Focus",
            "hi": "Focus",
            "bn": "Focus",
            "ta": "Focus",
            "te": "Focus"
        ],
        "repetition_control": [
            "en": "Repetition control",
            "hi": "Repetition control",
            "bn": "Repetition control",
            "ta": "Repetition control",
            "te": "Repetition control"
        ],
        "candidate_limit": [
            "en": "Candidate limit",
            "hi": "Candidate limit",
            "bn": "Candidate limit",
            "ta": "Candidate limit",
            "te": "Candidate limit"
        ],
        "restore_recommended_style": [
            "en": "Restore recommended style",
            "hi": "recommended style restore करें",
            "bn": "recommended style restore করুন",
            "ta": "recommended style restore செய்யவும்",
            "te": "recommended style restore చేయండి"
        ],
        "advanced_tuning": [
            "en": "Advanced tuning",
            "hi": "Advanced tuning",
            "bn": "Advanced tuning",
            "ta": "Advanced tuning",
            "te": "Advanced tuning"
        ],
        "settings_advanced": [
            "en": "Advanced",
            "hi": "उन्नत",
            "bn": "উন্নত",
            "ta": "மேம்பட்டது",
            "te": "అధునాతనం"
        ],
        "settings_support_details": [
            "en": "Support details",
            "hi": "Support विवरण",
            "bn": "Support details",
            "ta": "Support விவரங்கள்",
            "te": "Support వివరాలు"
        ],
        "settings_current_server": [
            "en": "Current server",
            "hi": "मौजूदा server",
            "bn": "বর্তমান server",
            "ta": "தற்போதைய server",
            "te": "ప్రస్తుత server"
        ],
        "settings_test_server_detail": [
            "en": "For internal testing only. iPhone Simulator usually uses 127.0.0.1, Android emulator uses 10.0.2.2, and a physical device needs your Mac's LAN IP.",
            "hi": "केवल internal testing के लिए। iPhone Simulator आमतौर पर 127.0.0.1 use करता है, Android emulator 10.0.2.2 use करता है, और physical device को आपके Mac का LAN IP चाहिए।",
            "bn": "শুধু internal testing-এর জন্য। iPhone Simulator সাধারণত 127.0.0.1 ব্যবহার করে, Android emulator 10.0.2.2 ব্যবহার করে, এবং physical device-এ আপনার Mac-এর LAN IP দরকার।",
            "ta": "Internal testing-க்கு மட்டும். iPhone Simulator பொதுவாக 127.0.0.1 பயன்படுத்தும், Android emulator 10.0.2.2 பயன்படுத்தும், physical device-க்கு உங்கள் Mac LAN IP தேவை.",
            "te": "Internal testing కోసం మాత్రమే. iPhone Simulator సాధారణంగా 127.0.0.1 ఉపయోగిస్తుంది, Android emulator 10.0.2.2 ఉపయోగిస్తుంది, physical device కు మీ Mac LAN IP కావాలి."
        ],
        "settings_save_test_server": [
            "en": "Save test server",
            "hi": "Test server save करें",
            "bn": "Test server save করুন",
            "ta": "Test server save செய்யவும்",
            "te": "Test server save చేయండి"
        ],
        "settings_use_default_address": [
            "en": "Use default address",
            "hi": "Default address use करें",
            "bn": "Default address use করুন",
            "ta": "Default address use செய்யவும்",
            "te": "Default address use చేయండి"
        ],
        "shown": [
            "en": "Shown",
            "hi": "दिखाया गया",
            "bn": "দেখানো",
            "ta": "காட்டப்பட்டது",
            "te": "చూపబడింది"
        ],
        "hidden": [
            "en": "Hidden",
            "hi": "छिपा हुआ",
            "bn": "লুকানো",
            "ta": "மறைக்கப்பட்டது",
            "te": "దాచబడింది"
        ],
        "ross_summary": [
            "en": "Ross Summary",
            "hi": "Ross Summary",
            "bn": "Ross Summary",
            "ta": "Ross Summary",
            "te": "Ross Summary"
        ],
        "case_number": [
            "en": "Case number",
            "hi": "Case number",
            "bn": "Case number",
            "ta": "Case number",
            "te": "Case number"
        ],
        "parties": [
            "en": "Parties",
            "hi": "Parties",
            "bn": "Parties",
            "ta": "Parties",
            "te": "Parties"
        ],
        "next_hearing_deadline": [
            "en": "Next hearing/deadline",
            "hi": "Next hearing/deadline",
            "bn": "Next hearing/deadline",
            "ta": "Next hearing/deadline",
            "te": "Next hearing/deadline"
        ],
        "needs_review_detail": [
            "en": "Accept, edit, or dismiss facts before Ross relies on them.",
            "hi": "Ross rely करे उससे पहले facts accept, edit, या dismiss करें।",
            "bn": "Ross rely করার আগে facts accept, edit, বা dismiss করুন।",
            "ta": "Ross rely செய்வதற்கு முன் facts accept, edit அல்லது dismiss செய்யவும்.",
            "te": "Ross rely చేయడానికి ముందు facts accept, edit, లేదా dismiss చేయండి."
        ],
        "assistant_device_cache": [
            "en": "Device cache",
            "hi": "डिवाइस cache",
            "bn": "ডিভাইস cache",
            "ta": "சாதன cache",
            "te": "పరికర cache"
        ],
        "assistant_device_cache_detail": [
            "en": "Keep local workspace indexes on this device so Ross opens faster.",
            "hi": "Ross जल्दी खुले, इसके लिए स्थानीय workspace indexes इसी डिवाइस पर रखें।",
            "bn": "Ross দ্রুত খুলতে স্থানীয় workspace indexes এই ডিভাইসে রাখুন।",
            "ta": "Ross வேகமாக திறக்க உள்ளூர் workspace indexes-ஐ இந்த சாதனத்தில் வைத்திருங்கள்.",
            "te": "Ross వేగంగా తెరుచుకోవడానికి స్థానిక workspace indexes ను ఈ పరికరంలో ఉంచండి."
        ],
        "assistant_network": [
            "en": "Network",
            "hi": "नेटवर्क",
            "bn": "নেটওয়ার্ক",
            "ta": "நெட்வொர்க்",
            "te": "నెట్‌వర్క్"
        ],
        "assistant_network_wifi_mobile": [
            "en": "Wi-Fi or mobile data",
            "hi": "Wi-Fi या मोबाइल डेटा",
            "bn": "Wi-Fi বা মোবাইল ডেটা",
            "ta": "Wi-Fi அல்லது மொபைல் தரவு",
            "te": "Wi-Fi లేదా మొబైల్ డేటా"
        ],
        "assistant_network_wifi_preferred": [
            "en": "Wi-Fi preferred",
            "hi": "Wi-Fi बेहतर है",
            "bn": "Wi-Fi পছন্দনীয়",
            "ta": "Wi-Fi விரும்பப்படுகிறது",
            "te": "Wi-Fi ప్రాధాన్యం"
        ],
        "notes_drafts_title": [
            "en": "Notes & Drafts",
            "hi": "नोट्स और ड्राफ्ट",
            "bn": "নোট ও খসড়া",
            "ta": "குறிப்புகள் & வரைவுகள்",
            "te": "గమనికలు & డ్రాఫ్ట్‌లు"
        ],
        "notes_drafts_detail": [
            "en": "Generate local notes and drafts for advocate review.",
            "hi": "अधिवक्ता समीक्षा के लिए स्थानीय नोट्स और ड्राफ्ट बनाएं।",
            "bn": "আইনজীবীর পর্যালোচনার জন্য স্থানীয় নোট ও খসড়া তৈরি করুন।",
            "ta": "வழக்கறிஞர் மதிப்பாய்வுக்கு உள்ளூர் குறிப்புகள் மற்றும் வரைவுகளை உருவாக்கவும்.",
            "te": "న్యాయవాది సమీక్ష కోసం స్థానిక గమనికలు మరియు డ్రాఫ్ట్‌లను సృష్టించండి."
        ],
        "notes_drafts_generate": [
            "en": "Generate",
            "hi": "बनाएं",
            "bn": "তৈরি করুন",
            "ta": "உருவாக்கு",
            "te": "సృష్టించండి"
        ],
        "notes_drafts_generate_detail": [
            "en": "Use the compact actions here, or type \"draft case note\" in Ask Ross below.",
            "hi": "यहां छोटे actions उपयोग करें, या नीचे Ask Ross में \"draft case note\" लिखें।",
            "bn": "এখানে compact actions ব্যবহার করুন, অথবা নিচের Ask Ross-এ \"draft case note\" লিখুন।",
            "ta": "இங்கே உள்ள compact actions-ஐ பயன்படுத்தவும், அல்லது கீழே Ask Ross-இல் \"draft case note\" என தட்டச்சு செய்யவும்.",
            "te": "ఇక్కడ compact actions ఉపయోగించండి, లేదా దిగువ Ask Ross లో \"draft case note\" అని టైప్ చేయండి."
        ],
        "draft_action_chronology": [
            "en": "Chronology",
            "hi": "कालक्रम",
            "bn": "ঘটনাক্রম",
            "ta": "காலவரிசை",
            "te": "కాలక్రమం"
        ],
        "draft_action_case_note": [
            "en": "Case note",
            "hi": "केस नोट",
            "bn": "কেস নোট",
            "ta": "வழக்கு குறிப்பு",
            "te": "కేసు గమనిక"
        ],
        "draft_action_order_summary": [
            "en": "Order summary",
            "hi": "आदेश सारांश",
            "bn": "আদেশ সারাংশ",
            "ta": "உத்தரவு சுருக்கம்",
            "te": "ఆర్డర్ సారాంశం"
        ],
        "draft_action_transcript": [
            "en": "Transcript",
            "hi": "प्रतिलिपि",
            "bn": "ট্রান্সক্রিপ্ট",
            "ta": "உரைநகல்",
            "te": "ట్రాన్స్‌క్రిప్ట్"
        ],
        "notes_drafts_before_file": [
            "en": "Before you file",
            "hi": "फाइल करने से पहले",
            "bn": "ফাইল করার আগে",
            "ta": "தாக்கல் செய்வதற்கு முன்",
            "te": "ఫైల్ చేసే ముందు"
        ],
        "notes_drafts_ai_review_warning": [
            "en": "This draft was generated by AI. Review all content carefully. Ross is a tool to help you work faster, not a substitute for your professional judgement.",
            "hi": "यह ड्राफ्ट AI ने बनाया है। सभी सामग्री ध्यान से जांचें। Ross आपको तेज़ काम करने में मदद करने वाला tool है, आपके पेशेवर निर्णय का विकल्प नहीं।",
            "bn": "এই খসড়া AI তৈরি করেছে। সব বিষয় সাবধানে পর্যালোচনা করুন। Ross দ্রুত কাজ করতে সাহায্য করার tool, আপনার পেশাদার সিদ্ধান্তের বিকল্প নয়।",
            "ta": "இந்த வரைவு AI மூலம் உருவாக்கப்பட்டது. உள்ளடக்கத்தை கவனமாக மதிப்பாய்வு செய்யவும். Ross வேகமாக வேலை செய்ய உதவும் tool; உங்கள் தொழில்முறை தீர்ப்புக்கு மாற்றாகாது.",
            "te": "ఈ డ్రాఫ్ట్ AI ద్వారా రూపొందించబడింది. మొత్తం విషయాన్ని జాగ్రత్తగా సమీక్షించండి. Ross మీరు వేగంగా పని చేయడానికి సహాయపడే tool మాత్రమే; మీ వృత్తిపరమైన నిర్ణయానికి ప్రత్యామ్నాయం కాదు."
        ],
        "notes_drafts_empty_title": [
            "en": "No drafts yet",
            "hi": "अभी कोई ड्राफ्ट नहीं",
            "bn": "এখনও কোনো খসড়া নেই",
            "ta": "இன்னும் வரைவுகள் இல்லை",
            "te": "ఇంకా డ్రాఫ్ట్‌లు లేవు"
        ],
        "notes_drafts_empty_detail": [
            "en": "Generate a case note, chronology, order summary, or transcript to keep a local draft ready for advocate review.",
            "hi": "अधिवक्ता समीक्षा के लिए स्थानीय ड्राफ्ट तैयार रखने हेतु case note, chronology, order summary या transcript बनाएं।",
            "bn": "আইনজীবীর পর্যালোচনার জন্য স্থানীয় খসড়া প্রস্তুত রাখতে case note, chronology, order summary বা transcript তৈরি করুন।",
            "ta": "வழக்கறிஞர் மதிப்பாய்வுக்கு உள்ளூர் வரைவை தயார் வைத்திருக்க case note, chronology, order summary அல்லது transcript உருவாக்கவும்.",
            "te": "న్యాయవాది సమీక్ష కోసం స్థానిక డ్రాఫ్ట్ సిద్ధంగా ఉండేందుకు case note, chronology, order summary లేదా transcript సృష్టించండి."
        ],
        "notes_drafts_share_detail": [
            "en": "Review this draft before sending or filing. Sharing uses the iOS share sheet and keeps the saved draft on this device.",
            "hi": "भेजने या फाइल करने से पहले इस ड्राफ्ट की समीक्षा करें। Sharing iOS share sheet उपयोग करता है और saved draft इसी डिवाइस पर रहता है।",
            "bn": "পাঠানো বা ফাইল করার আগে এই খসড়া পর্যালোচনা করুন। Sharing iOS share sheet ব্যবহার করে এবং saved draft এই ডিভাইসেই রাখে।",
            "ta": "அனுப்புவதற்கு அல்லது தாக்கல் செய்வதற்கு முன் இந்த வரைவை மதிப்பாய்வு செய்யவும். Sharing iOS share sheet-ஐ பயன்படுத்துகிறது; saved draft இந்த சாதனத்திலேயே இருக்கும்.",
            "te": "పంపే లేదా ఫైల్ చేసే ముందు ఈ డ్రాఫ్ట్‌ను సమీక్షించండి. Sharing iOS share sheet ఉపయోగిస్తుంది; saved draft ఈ పరికరంలోనే ఉంటుంది."
        ],
        "notes_drafts_share_action": [
            "en": "Review or share draft",
            "hi": "ड्राफ्ट देखें या share करें",
            "bn": "খসড়া দেখুন বা share করুন",
            "ta": "வரைவை பார்க்கவும் அல்லது share செய்யவும்",
            "te": "డ్రాఫ్ట్‌ను చూడండి లేదా share చేయండి"
        ],
        "notes_drafts_metadata_type": [
            "en": "Draft type",
            "hi": "ड्राफ्ट प्रकार",
            "bn": "খসড়ার ধরন",
            "ta": "வரைவு வகை",
            "te": "డ్రాఫ్ట్ రకం"
        ],
        "notes_drafts_metadata_created": [
            "en": "Created",
            "hi": "बनाया गया",
            "bn": "তৈরি হয়েছে",
            "ta": "உருவாக்கப்பட்டது",
            "te": "సృష్టించబడింది"
        ],
        "notes_drafts_metadata_saved_file": [
            "en": "Saved file",
            "hi": "सहेजी गई फ़ाइल",
            "bn": "সংরক্ষিত ফাইল",
            "ta": "சேமித்த கோப்பு",
            "te": "సేవ్ చేసిన ఫైల్"
        ],
        "open_ask_ross": [
            "en": "Open Ask Ross",
            "hi": "Ask Ross खोलें",
            "bn": "Ask Ross খুলুন",
            "ta": "Ask Ross திறக்கவும்",
            "te": "Ask Ross తెరవండి"
        ],
        "tab_today": [
            "en": "Today",
            "hi": "आज",
            "bn": "আজ",
            "ta": "இன்று",
            "te": "ఈ రోజు"
        ],
        "tab_matters": [
            "en": "Matters",
            "hi": "मामले",
            "bn": "মামলা",
            "ta": "வழக்குகள்",
            "te": "కేసులు"
        ],
        "tab_files": [
            "en": "Files",
            "hi": "फ़ाइलें",
            "bn": "ফাইল",
            "ta": "கோப்புகள்",
            "te": "ఫైళ్లు"
        ],
        "tab_work": [
            "en": "Work",
            "hi": "काम",
            "bn": "কাজ",
            "ta": "வேலை",
            "te": "పని"
        ],
        "tab_settings": [
            "en": "Settings",
            "hi": "सेटिंग्स",
            "bn": "সেটিংস",
            "ta": "அமைப்புகள்",
            "te": "సెట్టింగ్‌లు"
        ],
        "appearance_auto": [
            "en": "Auto (Default)",
            "hi": "ऑटो (Default)",
            "bn": "অটো (Default)",
            "ta": "தானாக (Default)",
            "te": "ఆటో (Default)"
        ],
        "appearance_dark": [
            "en": "Dark",
            "hi": "डार्क",
            "bn": "ডার্ক",
            "ta": "இருண்ட",
            "te": "డార్క్"
        ],
        "appearance_light": [
            "en": "Light",
            "hi": "लाइट",
            "bn": "লাইট",
            "ta": "ஒளி",
            "te": "లైట్"
        ],
        "appearance_auto_detail": [
            "en": "Follow this phone",
            "hi": "इस फ़ोन का पालन करें",
            "bn": "এই ফোন অনুসরণ করুন",
            "ta": "இந்த தொலைபேசியைப் பின்பற்றவும்",
            "te": "ఈ ఫోన్‌ను అనుసరించండి"
        ],
        "appearance_dark_detail": [
            "en": "Always use dark",
            "hi": "हमेशा डार्क उपयोग करें",
            "bn": "সবসময় ডার্ক ব্যবহার করুন",
            "ta": "எப்போதும் இருண்ட தோற்றம் பயன்படுத்தவும்",
            "te": "ఎల్లప్పుడూ డార్క్ ఉపయోగించండి"
        ],
        "appearance_light_detail": [
            "en": "Always use light",
            "hi": "हमेशा लाइट उपयोग करें",
            "bn": "সবসময় লাইট ব্যবহার করুন",
            "ta": "எப்போதும் ஒளி தோற்றம் பயன்படுத்தவும்",
            "te": "ఎల్లప్పుడూ లైట్ ఉపయోగించండి"
        ],
        "documents_title": [
            "en": "Documents",
            "hi": "दस्तावेज़",
            "bn": "নথি",
            "ta": "ஆவணங்கள்",
            "te": "పత్రాలు"
        ],
        "file_room_title": [
            "en": "File Room",
            "hi": "फ़ाइल रूम",
            "bn": "ফাইল রুম",
            "ta": "கோப்பு அறை",
            "te": "ఫైల్ రూమ్"
        ],
        "files_in_matter": [
            "en": "%@ in this matter",
            "hi": "इस मामले में %@",
            "bn": "এই মামলায় %@",
            "ta": "இந்த வழக்கில் %@",
            "te": "ఈ కేసులో %@"
        ],
        "files_stored_for_matter": [
            "en": "%@ stored for this matter",
            "hi": "इस मामले के लिए %@ सहेजी गईं",
            "bn": "এই মামলার জন্য %@ সংরক্ষিত",
            "ta": "இந்த வழக்கிற்காக %@ சேமிக்கப்பட்டுள்ளது",
            "te": "ఈ కేసు కోసం %@ నిల్వ చేయబడ్డాయి"
        ],
        "files_on_matter": [
            "en": "%@ on this matter",
            "hi": "इस मामले पर %@",
            "bn": "এই মামলায় %@",
            "ta": "இந்த வழக்கில் %@",
            "te": "ఈ కేసులో %@"
        ],
        "file_room_import_first_file": [
            "en": "Import the first file",
            "hi": "पहली फ़ाइल import करें",
            "bn": "প্রথম ফাইল import করুন",
            "ta": "முதல் கோப்பை import செய்யவும்",
            "te": "మొదటి ఫైల్‌ను import చేయండి"
        ],
        "file_room_import_first_file_detail": [
            "en": "Add an order, pleading, notice, image, or note. Ross reads it on this iPhone and makes it available for review and Ask.",
            "hi": "आदेश, pleading, notice, image या note जोड़ें। Ross इसे इसी iPhone पर पढ़ता है और review व Ask के लिए उपलब्ध करता है।",
            "bn": "order, pleading, notice, image বা note যোগ করুন। Ross এটি এই iPhone-এ পড়ে এবং review ও Ask-এর জন্য প্রস্তুত করে।",
            "ta": "order, pleading, notice, image அல்லது note சேர்க்கவும். Ross இதை இந்த iPhone-இல் வாசித்து review மற்றும் Ask-க்கு கிடைக்கச் செய்கிறது.",
            "te": "order, pleading, notice, image లేదా note జోడించండి. Ross దీన్ని ఈ iPhone లో చదివి review మరియు Ask కోసం అందుబాటులో ఉంచుతుంది."
        ],
        "file_room_import_first_real_file": [
            "en": "Import the first real file",
            "hi": "पहली असली फ़ाइल import करें",
            "bn": "প্রথম আসল ফাইল import করুন",
            "ta": "முதல் உண்மையான கோப்பை import செய்யவும்",
            "te": "మొదటి నిజమైన ఫైల్‌ను import చేయండి"
        ],
        "file_room_import_first_real_file_detail": [
            "en": "Add a PDF, image, or text note. Ross will read it locally, prepare review items, and make it available for Ask.",
            "hi": "PDF, image या text note जोड़ें। Ross इसे locally पढ़ेगा, review items तैयार करेगा, और Ask के लिए उपलब्ध करेगा।",
            "bn": "PDF, image বা text note যোগ করুন। Ross এটি locally পড়বে, review items তৈরি করবে, এবং Ask-এর জন্য প্রস্তুত করবে।",
            "ta": "PDF, image அல்லது text note சேர்க்கவும். Ross அதை locally வாசித்து, review items தயாரித்து, Ask-க்கு கிடைக்கச் செய்யும்.",
            "te": "PDF, image లేదా text note జోడించండి. Ross దాన్ని locally చదివి, review items సిద్ధం చేసి, Ask కోసం అందుబాటులో ఉంచుతుంది."
        ],
        "import_document": [
            "en": "Import document",
            "hi": "दस्तावेज़ import करें",
            "bn": "নথি import করুন",
            "ta": "ஆவணத்தை import செய்யவும்",
            "te": "పత్రాన్ని import చేయండి"
        ],
        "document_title": [
            "en": "Document",
            "hi": "दस्तावेज़",
            "bn": "নথি",
            "ta": "ஆவணம்",
            "te": "పత్రం"
        ],
        "back": [
            "en": "Back",
            "hi": "वापस",
            "bn": "ফিরে যান",
            "ta": "பின் செல்லவும்",
            "te": "వెనక్కి"
        ],
        "ask_ross_about_document": [
            "en": "Ask Ross about this document",
            "hi": "इस दस्तावेज़ के बारे में Ross से पूछें",
            "bn": "এই নথি সম্পর্কে Ross-কে জিজ্ঞাসা করুন",
            "ta": "இந்த ஆவணம் பற்றி Ross-ஐ கேளுங்கள்",
            "te": "ఈ పత్రం గురించి Ross‌ను అడగండి"
        ],
        "review_document_again": [
            "en": "Review document again",
            "hi": "दस्तावेज़ फिर review करें",
            "bn": "নথি আবার review করুন",
            "ta": "ஆவணத்தை மீண்டும் review செய்யவும்",
            "te": "పత్రాన్ని మళ్లీ review చేయండి"
        ],
        "document_review_what_ross_found": [
            "en": "What Ross found",
            "hi": "Ross ने क्या पाया",
            "bn": "Ross যা পেয়েছে",
            "ta": "Ross கண்டது",
            "te": "Ross కనుగొన్నది"
        ],
        "document_review_important": [
            "en": "Important",
            "hi": "ज़रूरी",
            "bn": "গুরুত্বপূর্ণ",
            "ta": "முக்கியம்",
            "te": "ముఖ్యం"
        ],
        "document_review_important_detail": [
            "en": "Check details that can change dates, parties, filing position, or what happens next.",
            "hi": "तारीख़, पक्षकार, filing position या आगे क्या होगा बदल सकने वाली details जांचें।",
            "bn": "তারিখ, পক্ষ, filing position, বা এরপর কী হবে বদলাতে পারে এমন details যাচাই করুন।",
            "ta": "தேதிகள், தரப்புகள், filing position அல்லது அடுத்து நடப்பதை மாற்றக்கூடிய details-ஐ சரிபார்க்கவும்.",
            "te": "తేదీలు, పక్షాలు, filing position లేదా తర్వాత జరిగేదాన్ని మార్చగల details ను తనిఖీ చేయండి."
        ],
        "document_review_helpful_details": [
            "en": "Helpful details you can accept, edit, or ignore after the essentials are clear.",
            "hi": "ज़रूरी बातें साफ़ होने के बाद accept, edit या ignore कर सकने वाली helpful details.",
            "bn": "মূল বিষয় পরিষ্কার হলে accept, edit বা ignore করা যায় এমন helpful details.",
            "ta": "முக்கியவை தெளிவான பிறகு accept, edit அல்லது ignore செய்யக்கூடிய helpful details.",
            "te": "ముఖ్యమైనవి స్పష్టమైన తర్వాత accept, edit లేదా ignore చేయగల helpful details."
        ],
        "document_review_other_details": [
            "en": "Other details",
            "hi": "अन्य details",
            "bn": "অন্যান্য details",
            "ta": "மற்ற details",
            "te": "ఇతర details"
        ],
        "document_review_queue_summary_needs_review": [
            "en": "Ross found key details. Please review the uncertain ones.",
            "hi": "Ross ने key details ढूंढीं। uncertain details review करें।",
            "bn": "Ross key details খুঁজে পেয়েছে। uncertain details review করুন।",
            "ta": "Ross key details கண்டது. uncertain details review செய்யவும்.",
            "te": "Ross key details కనుగొంది. uncertain details review చేయండి."
        ],
        "document_review_queue_summary_ready": [
            "en": "Ross found key details.",
            "hi": "Ross ने key details ढूंढीं।",
            "bn": "Ross key details খুঁজে পেয়েছে।",
            "ta": "Ross key details கண்டது.",
            "te": "Ross key details కనుగొంది."
        ],
        "document_review_summary_counts": [
            "en": "Fields found: %d · Verified: %d · Please confirm: %d",
            "hi": "Fields मिले: %d · Verified: %d · Confirm करें: %d",
            "bn": "Fields পাওয়া গেছে: %d · Verified: %d · Confirm করুন: %d",
            "ta": "Fields கண்டது: %d · Verified: %d · Confirm செய்யவும்: %d",
            "te": "Fields కనుగొంది: %d · Verified: %d · Confirm చేయండి: %d"
        ],
        "document_review_upgrade_standard": [
            "en": "Better extraction is available with Standard.",
            "hi": "Standard के साथ better extraction available है.",
            "bn": "Standard দিয়ে better extraction available.",
            "ta": "Standard-இல் better extraction available.",
            "te": "Standard తో better extraction available."
        ],
        "document_review_upgrade_advanced_scan": [
            "en": "This scan has mixed language or unclear text. Advanced may improve review.",
            "hi": "इस scan में mixed language या unclear text है। Advanced review बेहतर कर सकता है.",
            "bn": "এই scan-এ mixed language বা unclear text আছে। Advanced review উন্নত করতে পারে.",
            "ta": "இந்த scan-இல் mixed language அல்லது unclear text உள்ளது. Advanced review-ஐ மேம்படுத்தலாம்.",
            "te": "ఈ scan లో mixed language లేదా unclear text ఉంది. Advanced review ను మెరుగుపరచవచ్చు."
        ],
        "document_run_better_extraction": [
            "en": "Run better extraction",
            "hi": "बेहतर extraction चलाएं",
            "bn": "ভাল extraction চালান",
            "ta": "சிறந்த extraction இயக்கவும்",
            "te": "మెరుగైన extraction నడపండి"
        ],
        "file_readiness": [
            "en": "File readiness",
            "hi": "फ़ाइल readiness",
            "bn": "ফাইল readiness",
            "ta": "கோப்பு readiness",
            "te": "ఫైల్ readiness"
        ],
        "ask_ready": [
            "en": "Ask ready",
            "hi": "Ask तैयार",
            "bn": "Ask প্রস্তুত",
            "ta": "Ask தயாராக உள்ளது",
            "te": "Ask సిద్ధం"
        ],
        "preparing": [
            "en": "Preparing",
            "hi": "तैयार हो रहा है",
            "bn": "প্রস্তুত হচ্ছে",
            "ta": "தயாராகிறது",
            "te": "సిద్ధమవుతోంది"
        ],
        "translate_this_file": [
            "en": "Translate this file",
            "hi": "इस फ़ाइल का अनुवाद करें",
            "bn": "এই ফাইল অনুবাদ করুন",
            "ta": "இந்த கோப்பை மொழிபெயர்க்கவும்",
            "te": "ఈ ఫైల్‌ను అనువదించండి"
        ],
        "document_readiness_ask_review_running": [
            "en": "Ross can answer from extracted text now. Deeper review is still running in the background.",
            "hi": "Ross अब extracted text से जवाब दे सकता है। deeper review अभी background में चल रहा है।",
            "bn": "Ross এখন extracted text থেকে উত্তর দিতে পারে। deeper review এখনও background-এ চলছে।",
            "ta": "Ross இப்போது extracted text-இல் இருந்து பதிலளிக்க முடியும். deeper review இன்னும் background-இல் நடக்கிறது.",
            "te": "Ross ఇప్పుడు extracted text నుండి సమాధానం ఇవ్వగలదు. deeper review ఇంకా background లో నడుస్తోంది."
        ],
        "document_readiness_ask_review_findings": [
            "en": "Ross can answer from extracted text now. Review the highlighted findings before relying on this file in notes or exports.",
            "hi": "Ross अब extracted text से जवाब दे सकता है। notes या exports में इस फ़ाइल पर भरोसा करने से पहले highlighted findings review करें।",
            "bn": "Ross এখন extracted text থেকে উত্তর দিতে পারে। notes বা exports-এ এই ফাইলের ওপর নির্ভর করার আগে highlighted findings review করুন।",
            "ta": "Ross இப்போது extracted text-இல் இருந்து பதிலளிக்க முடியும். notes அல்லது exports-இல் இந்த கோப்பை நம்புவதற்கு முன் highlighted findings-ஐ review செய்யவும்.",
            "te": "Ross ఇప్పుడు extracted text నుండి సమాధానం ఇవ్వగలదు. notes లేదా exports లో ఈ ఫైల్‌పై ఆధారపడే ముందు highlighted findings ను review చేయండి."
        ],
        "document_readiness_ask_verified": [
            "en": "Ross can answer from extracted text now. Verified details are ready for notes, tasks, and exports.",
            "hi": "Ross अब extracted text से जवाब दे सकता है। verified details notes, tasks और exports के लिए तैयार हैं।",
            "bn": "Ross এখন extracted text থেকে উত্তর দিতে পারে। verified details notes, tasks, এবং exports-এর জন্য প্রস্তুত।",
            "ta": "Ross இப்போது extracted text-இல் இருந்து பதிலளிக்க முடியும். verified details notes, tasks மற்றும் exports-க்கு தயாராக உள்ளன.",
            "te": "Ross ఇప్పుడు extracted text నుండి సమాధానం ఇవ్వగలదు. verified details notes, tasks మరియు exports కోసం సిద్ధంగా ఉన్నాయి."
        ],
        "document_readiness_ask_review_failed": [
            "en": "Ross can answer from extracted text now, but full review did not finish. Check the source before relying on this file.",
            "hi": "Ross अब extracted text से जवाब दे सकता है, लेकिन full review पूरा नहीं हुआ। इस फ़ाइल पर भरोसा करने से पहले source जांचें।",
            "bn": "Ross এখন extracted text থেকে উত্তর দিতে পারে, কিন্তু full review শেষ হয়নি। এই ফাইলের ওপর নির্ভর করার আগে source দেখুন।",
            "ta": "Ross இப்போது extracted text-இல் இருந்து பதிலளிக்க முடியும், ஆனால் full review முடிக்கப்படவில்லை. இந்த கோப்பை நம்புவதற்கு முன் source-ஐ சரிபார்க்கவும்.",
            "te": "Ross ఇప్పుడు extracted text నుండి సమాధానం ఇవ్వగలదు, కానీ full review పూర్తికాలేదు. ఈ ఫైల్‌పై ఆధారపడే ముందు source తనిఖీ చేయండి."
        ],
        "document_readiness_still_reading": [
            "en": "Ross is still reading this file. Ask from this file as soon as readable text appears.",
            "hi": "Ross अभी यह फ़ाइल पढ़ रहा है। readable text आते ही इस फ़ाइल से Ask उपलब्ध होगा।",
            "bn": "Ross এখনও এই ফাইল পড়ছে। readable text দেখা দিলেই এই ফাইল থেকে Ask করা যাবে।",
            "ta": "Ross இன்னும் இந்த கோப்பை வாசிக்கிறது. readable text கிடைத்தவுடன் இந்த கோப்பிலிருந்து Ask செய்யலாம்.",
            "te": "Ross ఇంకా ఈ ఫైల్‌ను చదువుతోంది. readable text కనిపించగానే ఈ ఫైల్ నుండి Ask చేయవచ్చు."
        ],
        "document_readiness_needs_clearer_text": [
            "en": "Ross could not find readable text in this file yet. Re-import a clearer PDF, image, or text file, then ask again.",
            "hi": "Ross को अभी इस फ़ाइल में readable text नहीं मिला। साफ़ PDF, image या text file फिर import करें, फिर पूछें।",
            "bn": "Ross এখনও এই ফাইলে readable text পায়নি। আরও পরিষ্কার PDF, image, বা text file আবার import করুন, তারপর জিজ্ঞাসা করুন।",
            "ta": "Ross இன்னும் இந்த கோப்பில் readable text காணவில்லை. தெளிவான PDF, image அல்லது text file-ஐ மீண்டும் import செய்து, பிறகு கேளுங்கள்.",
            "te": "Ross ఇంకా ఈ ఫైల్‌లో readable text కనుగొనలేదు. మరింత స్పష్టమైన PDF, image లేదా text file ను మళ్లీ import చేసి, తర్వాత అడగండి."
        ],
        "document_readiness_ask_ready_title": [
            "en": "Ask is ready",
            "hi": "Ask तैयार है",
            "bn": "Ask প্রস্তুত",
            "ta": "Ask தயாராக உள்ளது",
            "te": "Ask సిద్ధంగా ఉంది"
        ],
        "document_readiness_ask_ready_detail": [
            "en": "Ross can answer from this file and cite its pages.",
            "hi": "Ross इस फ़ाइल से जवाब दे सकता है और इसके pages cite कर सकता है।",
            "bn": "Ross এই ফাইল থেকে উত্তর দিতে এবং এর pages cite করতে পারে।",
            "ta": "Ross இந்த கோப்பிலிருந்து பதிலளித்து அதன் pages-ஐ cite செய்ய முடியும்.",
            "te": "Ross ఈ ఫైల్ నుండి సమాధానం ఇచ్చి దాని pages ను cite చేయగలదు."
        ],
        "document_readiness_still_reading_title": [
            "en": "Still reading",
            "hi": "अभी पढ़ रहा है",
            "bn": "এখনও পড়ছে",
            "ta": "இன்னும் வாசிக்கிறது",
            "te": "ఇంకా చదువుతోంది"
        ],
        "document_readiness_still_reading_detail": [
            "en": "Ask from this file will unlock as soon as readable text appears.",
            "hi": "readable text आते ही इस फ़ाइल से Ask unlock होगा।",
            "bn": "readable text দেখা দিলেই এই ফাইল থেকে Ask unlock হবে।",
            "ta": "readable text கிடைத்தவுடன் இந்த கோப்பிலிருந்து Ask unlock ஆகும்.",
            "te": "readable text కనిపించగానే ఈ ఫైల్ నుండి Ask unlock అవుతుంది."
        ],
        "document_readiness_needs_clearer_title": [
            "en": "Needs clearer text",
            "hi": "साफ़ text चाहिए",
            "bn": "আরও পরিষ্কার text দরকার",
            "ta": "தெளிவான text தேவை",
            "te": "మరింత స్పష్టమైన text అవసరం"
        ],
        "document_readiness_needs_clearer_detail": [
            "en": "Re-import a clearer PDF, image, or text file before asking from it.",
            "hi": "इससे पूछने से पहले साफ़ PDF, image या text file फिर import करें।",
            "bn": "এটি থেকে জিজ্ঞাসা করার আগে আরও পরিষ্কার PDF, image, বা text file আবার import করুন।",
            "ta": "இதிலிருந்து கேட்கும் முன் தெளிவான PDF, image அல்லது text file-ஐ மீண்டும் import செய்யவும்.",
            "te": "దీనినుంచి అడగే ముందు మరింత స్పష్టమైన PDF, image లేదా text file ను మళ్లీ import చేయండి."
        ],
        "document_readiness_review_complete_title": [
            "en": "Review complete",
            "hi": "Review पूरा",
            "bn": "Review শেষ",
            "ta": "Review முடிந்தது",
            "te": "Review పూర్తయింది"
        ],
        "document_readiness_review_complete_detail": [
            "en": "Verified details are ready for notes, tasks, and exports.",
            "hi": "verified details notes, tasks और exports के लिए तैयार हैं।",
            "bn": "verified details notes, tasks, এবং exports-এর জন্য প্রস্তুত।",
            "ta": "verified details notes, tasks மற்றும் exports-க்கு தயாராக உள்ளன.",
            "te": "verified details notes, tasks మరియు exports కోసం సిద్ధంగా ఉన్నాయి."
        ],
        "document_readiness_review_attention_title": [
            "en": "Review needs attention",
            "hi": "Review पर ध्यान चाहिए",
            "bn": "Review-তে নজর দরকার",
            "ta": "Review கவனம் தேவை",
            "te": "Review కు శ్రద్ధ అవసరం"
        ],
        "document_readiness_review_attention_detail": [
            "en": "Readable text is available, but the deeper review did not finish.",
            "hi": "readable text उपलब्ध है, लेकिन deeper review पूरा नहीं हुआ।",
            "bn": "readable text আছে, কিন্তু deeper review শেষ হয়নি।",
            "ta": "readable text கிடைக்கிறது, ஆனால் deeper review முடிக்கப்படவில்லை.",
            "te": "readable text అందుబాటులో ఉంది, కానీ deeper review పూర్తికాలేదు."
        ],
        "document_readiness_check_details_title": [
            "en": "Check highlighted details",
            "hi": "highlighted details जांचें",
            "bn": "highlighted details দেখুন",
            "ta": "highlighted details சரிபார்க்கவும்",
            "te": "highlighted details తనిఖీ చేయండి"
        ],
        "document_readiness_check_details_detail": [
            "en": "Confirm findings before relying on this file in notes or exports.",
            "hi": "notes या exports में इस फ़ाइल पर भरोसा करने से पहले findings confirm करें।",
            "bn": "notes বা exports-এ এই ফাইলের ওপর নির্ভর করার আগে findings confirm করুন।",
            "ta": "notes அல்லது exports-இல் இந்த கோப்பை நம்புவதற்கு முன் findings-ஐ confirm செய்யவும்.",
            "te": "notes లేదా exports లో ఈ ఫైల్‌పై ఆధారపడే ముందు findings ను confirm చేయండి."
        ],
        "document_readiness_review_progress_title": [
            "en": "Review in progress",
            "hi": "Review चल रहा है",
            "bn": "Review চলছে",
            "ta": "Review நடைபெறுகிறது",
            "te": "Review కొనసాగుతోంది"
        ],
        "document_readiness_review_progress_detail": [
            "en": "Ross is preparing structured details in the background.",
            "hi": "Ross background में structured details तैयार कर रहा है।",
            "bn": "Ross background-এ structured details তৈরি করছে।",
            "ta": "Ross background-இல் structured details தயாரிக்கிறது.",
            "te": "Ross background లో structured details సిద్ధం చేస్తోంది."
        ],
        "document_status_reading": [
            "en": "Reading",
            "hi": "Reading",
            "bn": "Reading",
            "ta": "Reading",
            "te": "Reading"
        ],
        "document_status_imported": [
            "en": "Imported",
            "hi": "Imported",
            "bn": "Imported",
            "ta": "Imported",
            "te": "Imported"
        ],
        "document_status_failed": [
            "en": "Failed",
            "hi": "Failed",
            "bn": "Failed",
            "ta": "Failed",
            "te": "Failed"
        ],
        "document_status_ready": [
            "en": "Ready",
            "hi": "Ready",
            "bn": "Ready",
            "ta": "Ready",
            "te": "Ready"
        ],
        "document_status_confirm": [
            "en": "Confirm",
            "hi": "Confirm",
            "bn": "Confirm",
            "ta": "Confirm",
            "te": "Confirm"
        ],
        "one_finding": [
            "en": "1 finding",
            "hi": "1 finding",
            "bn": "1 finding",
            "ta": "1 finding",
            "te": "1 finding"
        ],
        "findings_count": [
            "en": "%d findings",
            "hi": "%d findings",
            "bn": "%d findings",
            "ta": "%d findings",
            "te": "%d findings"
        ],
        "working_locally": [
            "en": "Working locally",
            "hi": "locally काम कर रहा है",
            "bn": "locally কাজ করছে",
            "ta": "locally வேலை செய்கிறது",
            "te": "locally పని చేస్తోంది"
        ],
        "extraction_stage_reading_text": [
            "en": "Reading text",
            "hi": "Text पढ़ रहा है",
            "bn": "Text পড়ছে",
            "ta": "Text வாசிக்கிறது",
            "te": "Text చదువుతోంది"
        ],
        "extraction_stage_checking_language": [
            "en": "Checking language",
            "hi": "Language जांच रहा है",
            "bn": "Language পরীক্ষা করছে",
            "ta": "Language சரிபார்க்கிறது",
            "te": "Language తనిఖీ చేస్తోంది"
        ],
        "extraction_stage_finding_key_details": [
            "en": "Finding key details",
            "hi": "Key details खोज रहा है",
            "bn": "Key details খুঁজছে",
            "ta": "Key details கண்டறிகிறது",
            "te": "Key details కనుగొంటోంది"
        ],
        "extraction_stage_checking_sources": [
            "en": "Checking sources",
            "hi": "Sources जांच रहा है",
            "bn": "Sources পরীক্ষা করছে",
            "ta": "Sources சரிபார்க்கிறது",
            "te": "Sources తనిఖీ చేస్తోంది"
        ],
        "extraction_stage_preparing_review": [
            "en": "Preparing review",
            "hi": "Review तैयार हो रहा है",
            "bn": "Review প্রস্তুত হচ্ছে",
            "ta": "Review தயாராகிறது",
            "te": "Review సిద్ధమవుతోంది"
        ],
        "extraction_stage_complete": [
            "en": "Complete",
            "hi": "Complete",
            "bn": "Complete",
            "ta": "Complete",
            "te": "Complete"
        ],
        "extraction_stage_please_confirm": [
            "en": "Please confirm",
            "hi": "Confirm करें",
            "bn": "Confirm করুন",
            "ta": "Confirm செய்யவும்",
            "te": "Confirm చేయండి"
        ],
        "extraction_stage_needs_attention": [
            "en": "Needs attention",
            "hi": "Attention चाहिए",
            "bn": "Attention দরকার",
            "ta": "Attention தேவை",
            "te": "Attention అవసరం"
        ],
        "extraction_pages_progress": [
            "en": "%@ · %d of %d pages",
            "hi": "%@ · %d/%d pages",
            "bn": "%@ · %d/%d pages",
            "ta": "%@ · %d/%d pages",
            "te": "%@ · %d/%d pages"
        ],
        "document_review_progress_detail": [
            "en": "%@. Ross will update this file as soon as it finishes reading.",
            "hi": "%@। पढ़ना पूरा होते ही Ross इस file को update करेगा।",
            "bn": "%@। পড়া শেষ হলেই Ross এই file update করবে।",
            "ta": "%@. வாசித்து முடிந்தவுடன் Ross இந்த file-ஐ update செய்யும்.",
            "te": "%@. చదవడం పూర్తయ్యగానే Ross ఈ file ను update చేస్తుంది."
        ],
        "document_review_reading_detail": [
            "en": "Ross is reading the file and will show what it found as soon as it finishes.",
            "hi": "Ross file पढ़ रहा है और finish होते ही findings दिखाएगा।",
            "bn": "Ross file পড়ছে এবং শেষ হলেই findings দেখাবে।",
            "ta": "Ross file வாசிக்கிறது; முடிந்தவுடன் கண்டதை காட்டும்.",
            "te": "Ross file చదువుతోంది; పూర్తయ్యగానే కనుగొన్నదాన్ని చూపిస్తుంది."
        ],
        "document_review_still_reading_warning": [
            "en": "Ross is still reading this file. Do not rely on full-document facts until review finishes.",
            "hi": "Ross अभी यह file पढ़ रहा है। review पूरा होने तक full-document facts पर भरोसा न करें।",
            "bn": "Ross এখনও এই file পড়ছে। review শেষ না হওয়া পর্যন্ত full-document facts-এ নির্ভর করবেন না।",
            "ta": "Ross இன்னும் இந்த file வாசிக்கிறது. review முடியும் வரை full-document facts-ஐ நம்ப வேண்டாம்.",
            "te": "Ross ఇంకా ఈ file చదువుతోంది. review పూర్తయ్యే వరకు full-document facts పై ఆధారపడవద్దు."
        ],
        "document_review_check_findings_warning": [
            "en": "Check the highlighted items before relying on this file in a note or export.",
            "hi": "Note या export में इस file पर भरोसा करने से पहले highlighted items check करें।",
            "bn": "Note বা export-এ এই file-এ নির্ভর করার আগে highlighted items check করুন।",
            "ta": "Note அல்லது export-இல் இந்த file-ஐ நம்புவதற்கு முன் highlighted items check செய்யவும்.",
            "te": "Note లేదా export లో ఈ file పై ఆధారపడే ముందు highlighted items check చేయండి."
        ],
        "document_review_verified_ready_warning": [
            "en": "Verified details can be used in notes, tasks, and exports for this matter.",
            "hi": "Verified details इस matter के notes, tasks और exports में use हो सकते हैं।",
            "bn": "Verified details এই matter-এর notes, tasks, এবং exports-এ use করা যেতে পারে।",
            "ta": "Verified details இந்த matter-இன் notes, tasks மற்றும் exports-இல் use செய்யலாம்.",
            "te": "Verified details ఈ matter యొక్క notes, tasks మరియు exports లో use చేయవచ్చు."
        ],
        "document_review_failed_warning": [
            "en": "Ross could not finish reading this file. Review the source manually before using it.",
            "hi": "Ross यह file पढ़ना पूरा नहीं कर सका। use करने से पहले source manually review करें।",
            "bn": "Ross এই file পড়া শেষ করতে পারেনি। ব্যবহার করার আগে source manually review করুন।",
            "ta": "Ross இந்த file வாசிப்பை முடிக்க முடியவில்லை. பயன்படுத்துவதற்கு முன் source-ஐ manually review செய்யவும்.",
            "te": "Ross ఈ file చదవడం పూర్తి చేయలేకపోయింది. ఉపయోగించే ముందు source ను manually review చేయండి."
        ],
        "document_language_mixed": [
            "en": "Mixed language",
            "hi": "मिश्रित भाषा",
            "bn": "মিশ্র ভাষা",
            "ta": "கலப்பு மொழி",
            "te": "మిశ్రమ భాష"
        ],
        "document_language_unknown": [
            "en": "Unknown",
            "hi": "अज्ञात",
            "bn": "অজানা",
            "ta": "தெரியாதது",
            "te": "తెలియదు"
        ],
        "document_script_detected": [
            "en": "script detected",
            "hi": "script detected",
            "bn": "script detected",
            "ta": "script detected",
            "te": "script detected"
        ],
        "document_language_detected_detail": [
            "en": "Language detected from this file: %@.",
            "hi": "इस फ़ाइल से detected language: %@.",
            "bn": "এই ফাইল থেকে detected language: %@.",
            "ta": "இந்த கோப்பில் detected language: %@.",
            "te": "ఈ ఫైల్ నుండి detected language: %@."
        ],
        "document_language_pending_title": [
            "en": "Language pending",
            "hi": "भाषा pending",
            "bn": "ভাষা pending",
            "ta": "மொழி pending",
            "te": "భాష pending"
        ],
        "document_language_pending_detail": [
            "en": "Ross will detect language after readable text is available.",
            "hi": "readable text उपलब्ध होने के बाद Ross भाषा detect करेगा।",
            "bn": "readable text পাওয়া গেলে Ross ভাষা detect করবে।",
            "ta": "readable text கிடைத்த பிறகு Ross மொழியை detect செய்யும்.",
            "te": "readable text అందుబాటులోకి వచ్చిన తర్వాత Ross భాషను detect చేస్తుంది."
        ],
        "advocate_note": [
            "en": "Advocate note",
            "hi": "अधिवक्ता नोट",
            "bn": "আইনজীবীর নোট",
            "ta": "வழக்கறிஞர் குறிப்பு",
            "te": "న్యాయవాది గమనిక"
        ],
        "advocate_note_placeholder": [
            "en": "Write your manual note for this document.",
            "hi": "इस दस्तावेज़ के लिए अपना manual note लिखें।",
            "bn": "এই নথির জন্য আপনার manual note লিখুন।",
            "ta": "இந்த ஆவணத்திற்கான உங்கள் manual note-ஐ எழுதுங்கள்.",
            "te": "ఈ పత్రం కోసం మీ manual note రాయండి."
        ],
        "save_note": [
            "en": "Save note",
            "hi": "नोट save करें",
            "bn": "নোট save করুন",
            "ta": "குறிப்பை save செய்யவும்",
            "te": "గమనికను save చేయండి"
        ],
        "ask": [
            "en": "Ask",
            "hi": "पूछें",
            "bn": "জিজ্ঞাসা করুন",
            "ta": "கேள்",
            "te": "అడగండి"
        ],
        "review": [
            "en": "Review",
            "hi": "Review",
            "bn": "Review",
            "ta": "Review",
            "te": "Review"
        ],
        "check_sources": [
            "en": "Check sources",
            "hi": "स्रोत जांचें",
            "bn": "সোর্স দেখুন",
            "ta": "மூலங்களைச் சரிபார்க்கவும்",
            "te": "మూలాలను తనిఖీ చేయండి"
        ],
        "check_sources_detail": [
            "en": "Open the evidence Ross used, or inspect extracted text.",
            "hi": "Ross ने जो evidence उपयोग किया उसे खोलें, या extracted text जांचें।",
            "bn": "Ross যে evidence ব্যবহার করেছে তা খুলুন, অথবা extracted text দেখুন।",
            "ta": "Ross பயன்படுத்திய evidence-ஐ திறக்கவும், அல்லது extracted text-ஐ பரிசோதிக்கவும்.",
            "te": "Ross ఉపయోగించిన evidence తెరవండి, లేదా extracted text పరిశీలించండి."
        ],
        "no_source_previews": [
            "en": "No source previews available for this page.",
            "hi": "इस page के लिए source previews उपलब्ध नहीं हैं।",
            "bn": "এই page-এর জন্য source previews নেই।",
            "ta": "இந்த page-க்கு source previews இல்லை.",
            "te": "ఈ page కోసం source previews లేవు."
        ],
        "source_links": [
            "en": "Source links",
            "hi": "Source links",
            "bn": "Source links",
            "ta": "Source links",
            "te": "Source links"
        ],
        "hide_source_links": [
            "en": "Hide source links",
            "hi": "source links छिपाएं",
            "bn": "source links লুকান",
            "ta": "source links மறைக்கவும்",
            "te": "source links దాచండి"
        ],
        "source_links_detail": [
            "en": "Jump to the page or snippet behind a detail",
            "hi": "किसी detail के पीछे वाले page या snippet पर जाएं",
            "bn": "কোনো detail-এর পেছনের page বা snippet-এ যান",
            "ta": "ஒரு detail-க்கு பின்னுள்ள page அல்லது snippet-க்கு செல்லவும்",
            "te": "ఒక detail వెనుక ఉన్న page లేదా snippet కు వెళ్లండి"
        ],
        "extracted_text": [
            "en": "Extracted text",
            "hi": "Extracted text",
            "bn": "Extracted text",
            "ta": "Extracted text",
            "te": "Extracted text"
        ],
        "hide_extracted_text": [
            "en": "Hide extracted text",
            "hi": "extracted text छिपाएं",
            "bn": "extracted text লুকান",
            "ta": "extracted text மறைக்கவும்",
            "te": "extracted text దాచండి"
        ],
        "extracted_text_detail": [
            "en": "Use this when scan text needs manual checking",
            "hi": "जब scan text को manual checking चाहिए, तब इसका उपयोग करें",
            "bn": "scan text manual checking চাইলে এটি ব্যবহার করুন",
            "ta": "scan text-க்கு manual checking தேவைப்படும் போது இதைப் பயன்படுத்தவும்",
            "te": "scan text కు manual checking అవసరమైనప్పుడు దీన్ని ఉపయోగించండి"
        ],
        "no_extracted_text": [
            "en": "No extracted text is available for this page yet.",
            "hi": "इस page के लिए अभी extracted text उपलब्ध नहीं है।",
            "bn": "এই page-এর জন্য এখনও extracted text নেই।",
            "ta": "இந்த page-க்கு இன்னும் extracted text இல்லை.",
            "te": "ఈ page కోసం ఇంకా extracted text అందుబాటులో లేదు."
        ],
        "no_linked_source_yet": [
            "en": "No linked source yet",
            "hi": "अभी linked source नहीं",
            "bn": "এখনও linked source নেই",
            "ta": "இன்னும் linked source இல்லை",
            "te": "ఇంకా linked source లేదు"
        ],
        "this_file": [
            "en": "This file",
            "hi": "यह फ़ाइल",
            "bn": "এই ফাইল",
            "ta": "இந்த கோப்பு",
            "te": "ఈ ఫైల్"
        ],
        "matter_details": [
            "en": "Matter details",
            "hi": "मामले की details",
            "bn": "মামলার details",
            "ta": "வழக்கின் details",
            "te": "కేసు details"
        ],
        "no_linked_page": [
            "en": "No linked page",
            "hi": "linked page नहीं",
            "bn": "linked page নেই",
            "ta": "linked page இல்லை",
            "te": "linked page లేదు"
        ],
        "suggestion": [
            "en": "Suggestion",
            "hi": "सुझाव",
            "bn": "পরামর্শ",
            "ta": "பரிந்துரை",
            "te": "సూచన"
        ],
        "confirmed": [
            "en": "Confirmed",
            "hi": "पुष्टि हुई",
            "bn": "নিশ্চিত",
            "ta": "உறுதிப்படுத்தப்பட்டது",
            "te": "నిర్ధారించబడింది"
        ],
        "document_title_suggestion_title": [
            "en": "Ross suggests a clearer name",
            "hi": "Ross एक साफ़ नाम सुझाता है",
            "bn": "Ross একটি পরিষ্কার নাম প্রস্তাব করছে",
            "ta": "Ross தெளிவான பெயரை பரிந்துரைக்கிறது",
            "te": "Ross స్పష్టమైన పేరు సూచిస్తోంది"
        ],
        "document_title_suggestion_detail": [
            "en": "Keep the file name, accept this label, or edit it before saving.",
            "hi": "file name रखें, यह label accept करें, या save करने से पहले edit करें।",
            "bn": "file name রাখুন, এই label accept করুন, বা save করার আগে edit করুন।",
            "ta": "file name வைத்துக்கொள்ளவும், இந்த label accept செய்யவும், அல்லது save செய்வதற்கு முன் edit செய்யவும்.",
            "te": "file name ఉంచండి, ఈ label accept చేయండి, లేదా save చేసే ముందు edit చేయండి."
        ],
        "document_name": [
            "en": "Document name",
            "hi": "Document name",
            "bn": "Document name",
            "ta": "Document name",
            "te": "Document name"
        ],
        "keep_original_file_name": [
            "en": "Keep %@",
            "hi": "%@ रखें",
            "bn": "%@ রাখুন",
            "ta": "%@ வைத்துக்கொள்ளவும்",
            "te": "%@ ఉంచండి"
        ],
        "type": [
            "en": "Type",
            "hi": "Type",
            "bn": "Type",
            "ta": "Type",
            "te": "Type"
        ],
        "may_not_be_legal_document": [
            "en": "This may not be a legal case document",
            "hi": "यह legal case document नहीं हो सकता",
            "bn": "এটি legal case document নাও হতে পারে",
            "ta": "இது legal case document ஆக இருக்காமல் இருக்கலாம்",
            "te": "ఇది legal case document కాకపోవచ్చు"
        ],
        "may_not_be_legal_document_detail": [
            "en": "Ross found language suggesting this file is fictional, instructional, or non-legal. Ross will not save case details, hearing dates, or tasks from this file unless you confirm.",
            "hi": "Ross को ऐसी language मिली जिससे file fictional, instructional, या non-legal लगती है। आप confirm न करें तो Ross इस file से case details, hearing dates, या tasks save नहीं करेगा।",
            "bn": "Ross এমন language পেয়েছে যা file-টিকে fictional, instructional, বা non-legal মনে করায়। আপনি confirm না করলে Ross এই file থেকে case details, hearing dates, বা tasks save করবে না।",
            "ta": "இந்த file fictional, instructional அல்லது non-legal ஆக இருக்கலாம் என Ross language கண்டது. நீங்கள் confirm செய்யாவிட்டால் Ross இந்த file-இலிருந்து case details, hearing dates அல்லது tasks save செய்யாது.",
            "te": "ఈ file fictional, instructional, లేదా non-legal కావచ్చని సూచించే language ను Ross కనుగొంది. మీరు confirm చేయకపోతే Ross ఈ file నుండి case details, hearing dates, లేదా tasks save చేయదు."
        ],
        "use_as_reference_only": [
            "en": "Use as reference only",
            "hi": "सिर्फ reference की तरह use करें",
            "bn": "শুধু reference হিসেবে use করুন",
            "ta": "reference ஆக மட்டும் use செய்யவும்",
            "te": "reference గా మాత్రమే use చేయండి"
        ],
        "mark_as_legal_document": [
            "en": "Mark as legal document",
            "hi": "legal document mark करें",
            "bn": "legal document হিসেবে mark করুন",
            "ta": "legal document ஆக mark செய்யவும்",
            "te": "legal document గా mark చేయండి"
        ],
        "edit_field_placeholder": [
            "en": "Edit %@",
            "hi": "%@ edit करें",
            "bn": "%@ edit করুন",
            "ta": "%@ edit செய்யவும்",
            "te": "%@ edit చేయండి"
        ],
        "ignore": [
            "en": "Ignore",
            "hi": "Ignore",
            "bn": "Ignore",
            "ta": "Ignore",
            "te": "Ignore"
        ],
        "matter_value": [
            "en": "Matter value",
            "hi": "Matter value",
            "bn": "Matter value",
            "ta": "Matter value",
            "te": "Matter value"
        ],
        "file_value": [
            "en": "File value",
            "hi": "File value",
            "bn": "File value",
            "ta": "File value",
            "te": "File value"
        ],
        "keep_matter_value": [
            "en": "Keep matter value",
            "hi": "matter value रखें",
            "bn": "matter value রাখুন",
            "ta": "matter value வைத்துக்கொள்ளவும்",
            "te": "matter value ఉంచండి"
        ],
        "use_file_value": [
            "en": "Use file value",
            "hi": "file value use करें",
            "bn": "file value use করুন",
            "ta": "file value use செய்யவும்",
            "te": "file value use చేయండి"
        ],
        "save_as_alternate_reference": [
            "en": "Save as alternate reference",
            "hi": "alternate reference की तरह save करें",
            "bn": "alternate reference হিসেবে save করুন",
            "ta": "alternate reference ஆக save செய்யவும்",
            "te": "alternate reference గా save చేయండి"
        ],
        "preview": [
            "en": "Preview",
            "hi": "Preview",
            "bn": "Preview",
            "ta": "Preview",
            "te": "Preview"
        ],
        "confirmed_details_usage_detail": [
            "en": "Ross will use these confirmed details when preparing notes, tasks, and matter answers.",
            "hi": "notes, tasks और matter answers तैयार करते समय Ross ये confirmed details use करेगा।",
            "bn": "notes, tasks, এবং matter answers তৈরি করার সময় Ross এই confirmed details ব্যবহার করবে।",
            "ta": "notes, tasks மற்றும் matter answers தயாரிக்கும் போது Ross இந்த confirmed details பயன்படுத்தும்.",
            "te": "notes, tasks, మరియు matter answers సిద్ధం చేసే సమయంలో Ross ఈ confirmed details ఉపయోగిస్తుంది."
        ],
        "confirmed_for_ross": [
            "en": "Confirmed for Ross",
            "hi": "Ross के लिए confirmed",
            "bn": "Ross-এর জন্য confirmed",
            "ta": "Ross-க்கு confirmed",
            "te": "Ross కోసం confirmed"
        ],
        "details_already_approved_for_matter": [
            "en": "Details already approved for this matter",
            "hi": "इस matter के लिए details already approved हैं",
            "bn": "এই matter-এর জন্য details already approved",
            "ta": "இந்த matter-க்கு details already approved",
            "te": "ఈ matter కోసం details already approved"
        ],
        "page_number": [
            "en": "Page %d",
            "hi": "Page %d",
            "bn": "Page %d",
            "ta": "Page %d",
            "te": "Page %d"
        ],
        "no_readable_preview": [
            "en": "No readable preview is available yet.",
            "hi": "अभी readable preview उपलब्ध नहीं है।",
            "bn": "এখনও readable preview নেই।",
            "ta": "இன்னும் readable preview இல்லை.",
            "te": "ఇంకా readable preview అందుబాటులో లేదు."
        ],
        "image_preview_unavailable": [
            "en": "Image preview unavailable.",
            "hi": "Image preview उपलब्ध नहीं है।",
            "bn": "Image preview নেই।",
            "ta": "Image preview இல்லை.",
            "te": "Image preview అందుబాటులో లేదు."
        ],
        "sources": [
            "en": "Sources",
            "hi": "स्रोत",
            "bn": "সোর্স",
            "ta": "மூலங்கள்",
            "te": "మూలాలు"
        ],
        "copy": [
            "en": "Copy",
            "hi": "कॉपी",
            "bn": "কপি",
            "ta": "நகலெடு",
            "te": "కాపీ"
        ],
        "copy_answer": [
            "en": "Copy answer",
            "hi": "उत्तर copy करें",
            "bn": "উত্তর copy করুন",
            "ta": "பதிலை copy செய்யவும்",
            "te": "సమాధానాన్ని copy చేయండి"
        ],
        "more_answer_actions": [
            "en": "More answer actions",
            "hi": "उत्तर के और actions",
            "bn": "উত্তরের আরও actions",
            "ta": "பதிலுக்கான மேலும் actions",
            "te": "సమాధానానికి మరిన్ని actions"
        ],
        "report_answer": [
            "en": "Report answer",
            "hi": "उत्तर report करें",
            "bn": "উত্তর report করুন",
            "ta": "பதிலை report செய்யவும்",
            "te": "సమాధానాన్ని report చేయండి"
        ],
        "hide_sources": [
            "en": "Hide sources",
            "hi": "स्रोत छिपाएं",
            "bn": "সোর্স লুকান",
            "ta": "மூலங்களை மறைக்கவும்",
            "te": "మూలాలను దాచండి"
        ],
        "show_sources_count": [
            "en": "Show %d sources",
            "hi": "%d स्रोत दिखाएं",
            "bn": "%d সোর্স দেখান",
            "ta": "%d மூலங்களை காண்பி",
            "te": "%d మూలాలను చూపండి"
        ],
        "ross_answering": [
            "en": "Ross is answering...",
            "hi": "Ross जवाब दे रहा है...",
            "bn": "Ross উত্তর দিচ্ছে...",
            "ta": "Ross பதிலளிக்கிறது...",
            "te": "Ross సమాధానం ఇస్తోంది..."
        ],
        "local_model_running_on_phone": [
            "en": "%@ is running on this iPhone",
            "hi": "%@ इस iPhone पर चल रहा है",
            "bn": "%@ এই iPhone-এ চলছে",
            "ta": "%@ இந்த iPhone-இல் இயங்குகிறது",
            "te": "%@ ఈ iPhone లో నడుస్తోంది"
        ],
        "ross_checking_local_files": [
            "en": "Ross is checking your local files and will replace this loading state with the final answer.",
            "hi": "Ross आपकी local files जांच रहा है और final answer आने पर यह loading state बदल देगा।",
            "bn": "Ross আপনার local files দেখছে এবং final answer এলে এই loading state বদলে দেবে।",
            "ta": "Ross உங்கள் local files-ஐ சரிபார்க்கிறது; final answer வந்ததும் இந்த loading state மாறும்.",
            "te": "Ross మీ local files ను తనిఖీ చేస్తోంది; final answer వచ్చినప్పుడు ఈ loading state మారుతుంది."
        ],
        "tagged_file_line": [
            "en": "Tagged file: %@",
            "hi": "Tagged file: %@",
            "bn": "Tagged file: %@",
            "ta": "Tagged file: %@",
            "te": "Tagged file: %@"
        ],
        "tagged_files_line": [
            "en": "Tagged files: %@",
            "hi": "Tagged files: %@",
            "bn": "Tagged files: %@",
            "ta": "Tagged files: %@",
            "te": "Tagged files: %@"
        ],
        "threads": [
            "en": "Threads",
            "hi": "Threads",
            "bn": "Threads",
            "ta": "Threads",
            "te": "Threads"
        ],
        "choose_chat_scope": [
            "en": "Choose chat scope",
            "hi": "chat scope चुनें",
            "bn": "chat scope বেছে নিন",
            "ta": "chat scope தேர்வுசெய்க",
            "te": "chat scope ఎంచుకోండి"
        ],
        "add_files_or_images": [
            "en": "Add files or images",
            "hi": "files या images जोड़ें",
            "bn": "files বা images যোগ করুন",
            "ta": "files அல்லது images சேர்க்கவும்",
            "te": "files లేదా images జోడించండి"
        ],
        "answers_starting_point_warning": [
            "en": "Responses are a starting point. Always verify with your own judgement.",
            "hi": "Responses starting point हैं। हमेशा अपने judgement से verify करें।",
            "bn": "Responses starting point. সবসময় নিজের judgement দিয়ে verify করুন।",
            "ta": "Responses starting point ஆகும். எப்போதும் உங்கள் judgement மூலம் verify செய்யவும்.",
            "te": "Responses starting point మాత్రమే. ఎల్లప్పుడూ మీ judgement తో verify చేయండి."
        ],
        "legal_search_verify_citations_warning": [
            "en": "Legal Search results. Verify citations before use.",
            "hi": "Legal Search results. use करने से पहले citations verify करें।",
            "bn": "Legal Search results. ব্যবহারের আগে citations verify করুন।",
            "ta": "Legal Search results. பயன்படுத்துவதற்கு முன் citations verify செய்யவும்.",
            "te": "Legal Search results. ఉపయోగించే ముందు citations verify చేయండి."
        ],
        "new_thread": [
            "en": "New thread",
            "hi": "नई thread",
            "bn": "নতুন thread",
            "ta": "புதிய thread",
            "te": "కొత్త thread"
        ],
        "current": [
            "en": "Current",
            "hi": "वर्तमान",
            "bn": "বর্তমান",
            "ta": "தற்போதைய",
            "te": "ప్రస్తుత"
        ],
        "no_saved_threads": [
            "en": "No saved threads yet.",
            "hi": "अभी saved threads नहीं हैं।",
            "bn": "এখনও saved threads নেই।",
            "ta": "இன்னும் saved threads இல்லை.",
            "te": "ఇంకా saved threads లేవు."
        ],
        "matter_update": [
            "en": "Matter update",
            "hi": "मामले का update",
            "bn": "মামলার update",
            "ta": "வழக்கு update",
            "te": "కేసు update"
        ],
        "new_matter": [
            "en": "New matter",
            "hi": "नया मामला",
            "bn": "নতুন মামলা",
            "ta": "புதிய வழக்கு",
            "te": "కొత్త కేసు"
        ],
        "shared_files_count": [
            "en": "%d shared files",
            "hi": "%d साझा फ़ाइलें",
            "bn": "%d shared files",
            "ta": "%d பகிரப்பட்ட கோப்புகள்",
            "te": "%d షేర్ చేసిన ఫైళ్లు"
        ],
        "shared_files_add_to_matter": [
            "en": "Add files to a matter",
            "hi": "फ़ाइलें किसी मामले में जोड़ें",
            "bn": "ফাইল একটি মামলায় যোগ করুন",
            "ta": "கோப்புகளை ஒரு வழக்கில் சேர்க்கவும்",
            "te": "ఫైళ్లను ఒక కేసుకు జోడించండి"
        ],
        "shared_files_private_storage_detail": [
            "en": "Ross copies the files into private storage before reading them.",
            "hi": "Ross फ़ाइलें पढ़ने से पहले उन्हें private storage में copy करता है।",
            "bn": "Ross ফাইল পড়ার আগে private storage-এ copy করে।",
            "ta": "Ross கோப்புகளை வாசிப்பதற்கு முன் private storage-க்கு copy செய்கிறது.",
            "te": "Ross ఫైళ్లను చదవడానికి ముందు private storage లోకి copy చేస్తుంది."
        ],
        "import_existing_matter": [
            "en": "Import into an existing matter",
            "hi": "मौजूदा मामले में import करें",
            "bn": "বিদ্যমান মামলায় import করুন",
            "ta": "ஏற்கனவே உள்ள வழக்கில் import செய்யவும்",
            "te": "ఉన్న కేసులోకి import చేయండి"
        ],
        "create_new_matter": [
            "en": "Create a new matter",
            "hi": "नया मामला बनाएं",
            "bn": "নতুন মামলা তৈরি করুন",
            "ta": "புதிய வழக்கை உருவாக்கவும்",
            "te": "కొత్త కేసు సృష్టించండి"
        ],
        "create_matter_import_files": [
            "en": "Create matter and import files",
            "hi": "मामला बनाएं और फ़ाइलें import करें",
            "bn": "মামলা তৈরি করে ফাইল import করুন",
            "ta": "வழக்கை உருவாக்கி கோப்புகளை import செய்யவும்",
            "te": "కేసు సృష్టించి ఫైళ్లను import చేయండి"
        ],
        "create_matter_import_hint": [
            "en": "Creates a matter named %@ and imports the shared files.",
            "hi": "%@ नाम का मामला बनाता है और shared files import करता है।",
            "bn": "%@ নামে মামলা তৈরি করে shared files import করে।",
            "ta": "%@ என்ற பெயரில் வழக்கை உருவாக்கி shared files-ஐ import செய்கிறது.",
            "te": "%@ పేరుతో కేసు సృష్టించి shared files ను import చేస్తుంది."
        ],
        "shared_files": [
            "en": "Shared files",
            "hi": "साझा फ़ाइलें",
            "bn": "shared files",
            "ta": "பகிரப்பட்ட கோப்புகள்",
            "te": "షేర్ చేసిన ఫైళ్లు"
        ],
        "incoming_file_ready": [
            "en": "%@, ready to import into private storage",
            "hi": "%@, private storage में import के लिए तैयार",
            "bn": "%@, private storage-এ import করার জন্য প্রস্তুত",
            "ta": "%@, private storage-க்கு import செய்ய தயாராக உள்ளது",
            "te": "%@, private storage లోకి import చేయడానికి సిద్ధంగా ఉంది"
        ],
        "matter_name": [
            "en": "Matter name",
            "hi": "मामले का नाम",
            "bn": "মামলার নাম",
            "ta": "வழக்கின் பெயர்",
            "te": "కేసు పేరు"
        ],
        "create_matter_title": [
            "en": "Create a matter",
            "hi": "मामला बनाएं",
            "bn": "মামলা তৈরি করুন",
            "ta": "வழக்கை உருவாக்கவும்",
            "te": "కేసు సృష్టించండి"
        ],
        "create_matter_detail": [
            "en": "Start with the name. Ross can extract the court, parties, and next date after you import a file.",
            "hi": "नाम से शुरू करें। फ़ाइल import करने के बाद Ross court, parties और next date निकाल सकता है।",
            "bn": "নাম দিয়ে শুরু করুন। ফাইল import করার পরে Ross court, parties, এবং next date বের করতে পারে।",
            "ta": "பெயருடன் தொடங்குங்கள். கோப்பை import செய்த பிறகு Ross court, parties மற்றும் next date-ஐ எடுக்க முடியும்.",
            "te": "పేరుతో ప్రారంభించండి. ఫైల్ import చేసిన తర్వాత Ross court, parties మరియు next date ను తీసుకోగలదు."
        ],
        "enter_matter_name": [
            "en": "Enter matter name",
            "hi": "मामले का नाम दर्ज करें",
            "bn": "মামলার নাম লিখুন",
            "ta": "வழக்கின் பெயரை உள்ளிடவும்",
            "te": "కేసు పేరు నమోదు చేయండి"
        ],
        "required": [
            "en": "Required",
            "hi": "ज़रूरी",
            "bn": "প্রয়োজনীয়",
            "ta": "தேவை",
            "te": "అవసరం"
        ],
        "create_matter": [
            "en": "Create matter",
            "hi": "मामला बनाएं",
            "bn": "মামলা তৈরি করুন",
            "ta": "வழக்கை உருவாக்கவும்",
            "te": "కేసు సృష్టించండి"
        ],
        "add_next_hearing_date": [
            "en": "Add next hearing date",
            "hi": "अगली hearing date जोड़ें",
            "bn": "পরবর্তী hearing date যোগ করুন",
            "ta": "அடுத்த hearing date சேர்க்கவும்",
            "te": "తదుపరి hearing date జోడించండి"
        ],
        "clear_date": [
            "en": "Clear date",
            "hi": "date साफ़ करें",
            "bn": "date পরিষ্কার করুন",
            "ta": "date அழிக்கவும்",
            "te": "date క్లియర్ చేయండి"
        ],
        "one_open_task": [
            "en": "%d open",
            "hi": "%d open",
            "bn": "%d open",
            "ta": "%d open",
            "te": "%d open"
        ],
        "open_tasks_count": [
            "en": "%d open",
            "hi": "%d open",
            "bn": "%d open",
            "ta": "%d open",
            "te": "%d open"
        ],
        "matter_chat": [
            "en": "Matter chat",
            "hi": "मामला chat",
            "bn": "মামলা chat",
            "ta": "வழக்கு chat",
            "te": "కేసు chat"
        ],
        "matter_chat_empty_detail": [
            "en": "Keep questions, file follow-up, and next steps together for this matter.",
            "hi": "इस मामले के questions, file follow-up और next steps साथ रखें।",
            "bn": "এই মামলার questions, file follow-up, এবং next steps একসঙ্গে রাখুন।",
            "ta": "இந்த வழக்கின் questions, file follow-up மற்றும் next steps-ஐ ஒன்றாக வைத்திருங்கள்.",
            "te": "ఈ కేసు questions, file follow-up మరియు next steps ను కలిసి ఉంచండి."
        ],
        "matter_chat_continue_detail": [
            "en": "Continue in the current matter thread to keep related work in one place.",
            "hi": "संबंधित काम एक जगह रखने के लिए current matter thread में जारी रखें।",
            "bn": "সম্পর্কিত কাজ এক জায়গায় রাখতে current matter thread-এ চালিয়ে যান।",
            "ta": "தொடர்புடைய வேலையை ஒரே இடத்தில் வைத்திருக்க current matter thread-இல் தொடரவும்.",
            "te": "సంబంధిత పనిని ఒకే చోట ఉంచడానికి current matter thread లో కొనసాగించండి."
        ],
        "recent_activity": [
            "en": "Recent activity",
            "hi": "हाल की activity",
            "bn": "সাম্প্রতিক activity",
            "ta": "சமீபத்திய activity",
            "te": "ఇటీవలి activity"
        ],
        "no_matter_chat_detail": [
            "en": "No matter chat yet. Ross will start one when you import a file, review a document, or ask the first question here.",
            "hi": "अभी matter chat नहीं है। फ़ाइल import करने, document review करने, या पहला सवाल पूछने पर Ross इसे शुरू करेगा।",
            "bn": "এখনও matter chat নেই। ফাইল import, document review, বা প্রথম প্রশ্ন করলে Ross এটি শুরু করবে।",
            "ta": "இன்னும் matter chat இல்லை. நீங்கள் கோப்பை import செய்யும் போது, document review செய்யும் போது, அல்லது முதல் கேள்வியை இங்கே கேட்கும் போது Ross அதை தொடங்கும்.",
            "te": "ఇంకా matter chat లేదు. మీరు ఫైల్ import చేసినప్పుడు, document review చేసినప్పుడు, లేదా ఇక్కడ మొదటి ప్రశ్న అడిగినప్పుడు Ross దాన్ని ప్రారంభిస్తుంది."
        ],
        "open_chat": [
            "en": "Open chat",
            "hi": "chat खोलें",
            "bn": "chat খুলুন",
            "ta": "chat திறக்கவும்",
            "te": "chat తెరవండి"
        ],
        "continue_chat": [
            "en": "Continue chat",
            "hi": "chat जारी रखें",
            "bn": "chat চালিয়ে যান",
            "ta": "chat தொடரவும்",
            "te": "chat కొనసాగించండి"
        ],
        "use_ask_ross_below": [
            "en": "Use Ask Ross below",
            "hi": "नीचे Ask Ross उपयोग करें",
            "bn": "নিচে Ask Ross ব্যবহার করুন",
            "ta": "கீழே Ask Ross-ஐ பயன்படுத்தவும்",
            "te": "కింద Ask Ross ఉపయోగించండి"
        ],
        "ross_found_title": [
            "en": "Ross found: %@",
            "hi": "Ross ने पाया: %@",
            "bn": "Ross পেয়েছে: %@",
            "ta": "Ross கண்டது: %@",
            "te": "Ross కనుగొన్నది: %@"
        ],
        "correct": [
            "en": "Correct",
            "hi": "सही",
            "bn": "সঠিক",
            "ta": "சரி",
            "te": "సరైంది"
        ],
        "accept": [
            "en": "Accept",
            "hi": "स्वीकार करें",
            "bn": "গ্রহণ করুন",
            "ta": "ஏற்கவும்",
            "te": "అంగీకరించండి"
        ],
        "edit": [
            "en": "Edit",
            "hi": "संपादित करें",
            "bn": "সম্পাদনা করুন",
            "ta": "திருத்தவும்",
            "te": "సవరించండి"
        ],
        "dismiss": [
            "en": "Dismiss",
            "hi": "हटाएं",
            "bn": "সরান",
            "ta": "நீக்கவும்",
            "te": "తొలగించండి"
        ],
        "settings_privacy": [
            "en": "Privacy",
            "hi": "गोपनीयता",
            "bn": "গোপনীয়তা",
            "ta": "தனியுரிமை",
            "te": "గోప్యత"
        ],
        "review_required": [
            "en": "Review required",
            "hi": "Review ज़रूरी",
            "bn": "Review দরকার",
            "ta": "Review தேவை",
            "te": "Review అవసరం"
        ],
        "settings_privacy_detail": [
            "en": "Ross shows the Legal Search wording first. Matter files stay on this iPhone.",
            "hi": "Ross पहले Legal Search wording दिखाता है। मामले की फ़ाइलें इसी iPhone पर रहती हैं।",
            "bn": "Ross আগে Legal Search wording দেখায়। মামলার ফাইল এই iPhone-এই থাকে।",
            "ta": "Ross முதலில் Legal Search wording-ஐ காட்டுகிறது. வழக்கு கோப்புகள் இந்த iPhone-இலேயே இருக்கும்.",
            "te": "Ross ముందుగా Legal Search wording చూపుతుంది. కేసు ఫైళ్లు ఈ iPhone లోనే ఉంటాయి."
        ],
        "activity_log": [
            "en": "Activity Log",
            "hi": "Activity Log",
            "bn": "Activity Log",
            "ta": "Activity Log",
            "te": "Activity Log"
        ],
        "activity_log_detail": [
            "en": "Local work and Legal Search, separated.",
            "hi": "Local work और Legal Search अलग-अलग।",
            "bn": "Local work এবং Legal Search আলাদা।",
            "ta": "Local work மற்றும் Legal Search தனித்தனியாக.",
            "te": "Local work మరియు Legal Search వేర్వేరుగా."
        ],
        "settings_appearance": [
            "en": "Appearance",
            "hi": "रूप",
            "bn": "চেহারা",
            "ta": "தோற்றம்",
            "te": "రూపం"
        ],
        "theme": [
            "en": "Theme",
            "hi": "Theme",
            "bn": "Theme",
            "ta": "Theme",
            "te": "Theme"
        ],
        "open_my_assistant": [
            "en": "Open My assistant",
            "hi": "My assistant खोलें",
            "bn": "My assistant খুলুন",
            "ta": "My assistant திறக்கவும்",
            "te": "My assistant తెరవండి"
        ],
        "open_my_assistant_detail": [
            "en": "Use this when answers are unavailable or setup is paused.",
            "hi": "जब answers उपलब्ध न हों या setup रुका हो, तब इसका उपयोग करें।",
            "bn": "answers না থাকলে বা setup থেমে থাকলে এটি ব্যবহার করুন।",
            "ta": "answers கிடைக்காதபோது அல்லது setup இடைநிறுத்தப்பட்டபோது இதைப் பயன்படுத்தவும்.",
            "te": "answers అందుబాటులో లేకపోతే లేదా setup నిలిచిపోయితే దీన్ని ఉపయోగించండి."
        ],
        "ross_routines": [
            "en": "Ross Routines",
            "hi": "Ross Routines",
            "bn": "Ross Routines",
            "ta": "Ross Routines",
            "te": "Ross Routines"
        ],
        "ross_routines_detail": [
            "en": "Routines run locally from saved matters, files, dates, tasks, drafts, and accepted corrections.",
            "hi": "Routines saved matters, files, dates, tasks, drafts और accepted corrections से locally चलते हैं।",
            "bn": "Routines saved matters, files, dates, tasks, drafts, এবং accepted corrections থেকে locally চলে।",
            "ta": "Routines saved matters, files, dates, tasks, drafts மற்றும் accepted corrections-இல் இருந்து locally இயங்கும்.",
            "te": "Routines saved matters, files, dates, tasks, drafts మరియు accepted corrections నుండి locally నడుస్తాయి."
        ],
        "morning_brief": [
            "en": "Morning brief",
            "hi": "Morning brief",
            "bn": "Morning brief",
            "ta": "Morning brief",
            "te": "Morning brief"
        ],
        "morning_brief_detail": [
            "en": "On app open, once per day.",
            "hi": "App खुलने पर, दिन में एक बार।",
            "bn": "App খুললে, দিনে একবার।",
            "ta": "App திறக்கும் போது, ஒரு நாளில் ஒருமுறை.",
            "te": "App తెరిచినప్పుడు, రోజుకు ఒకసారి."
        ],
        "after_document_import": [
            "en": "After document import",
            "hi": "Document import के बाद",
            "bn": "Document import-এর পরে",
            "ta": "Document import பிறகு",
            "te": "Document import తర్వాత"
        ],
        "after_document_import_detail": [
            "en": "Update case memory and review items after extraction.",
            "hi": "Extraction के बाद case memory और review items update करें।",
            "bn": "Extraction-এর পরে case memory এবং review items update করুন।",
            "ta": "Extraction பிறகு case memory மற்றும் review items update செய்யவும்.",
            "te": "Extraction తర్వాత case memory మరియు review items update చేయండి."
        ],
        "before_hearing": [
            "en": "Before hearing",
            "hi": "Hearing से पहले",
            "bn": "Hearing-এর আগে",
            "ta": "Hearing முன்",
            "te": "Hearing ముందు"
        ],
        "before_hearing_detail": [
            "en": "Prepare checklist, missing facts, and hearing note prompt.",
            "hi": "Checklist, missing facts और hearing note prompt तैयार करें।",
            "bn": "Checklist, missing facts, এবং hearing note prompt তৈরি করুন।",
            "ta": "Checklist, missing facts மற்றும் hearing note prompt தயாரிக்கவும்.",
            "te": "Checklist, missing facts మరియు hearing note prompt సిద్ధం చేయండి."
        ],
        "missing_facts_scan": [
            "en": "Missing facts scan",
            "hi": "Missing facts scan",
            "bn": "Missing facts scan",
            "ta": "Missing facts scan",
            "te": "Missing facts scan"
        ],
        "missing_facts_scan_detail": [
            "en": "Find gaps and weak support in source-backed matter memory.",
            "hi": "Source-backed matter memory में gaps और weak support खोजें।",
            "bn": "Source-backed matter memory-তে gaps এবং weak support খুঁজুন।",
            "ta": "Source-backed matter memory-இல் gaps மற்றும் weak support கண்டறியவும்.",
            "te": "Source-backed matter memory లో gaps మరియు weak support కనుగొనండి."
        ],
        "draft_refresh": [
            "en": "Draft refresh",
            "hi": "Draft refresh",
            "bn": "Draft refresh",
            "ta": "Draft refresh",
            "te": "Draft refresh"
        ],
        "draft_refresh_detail": [
            "en": "Refresh local drafts from latest files and corrections.",
            "hi": "Latest files और corrections से local drafts refresh करें।",
            "bn": "Latest files এবং corrections থেকে local drafts refresh করুন।",
            "ta": "Latest files மற்றும் corrections-இல் இருந்து local drafts refresh செய்யவும்.",
            "te": "Latest files మరియు corrections నుండి local drafts refresh చేయండి."
        ],
        "public_law_search": [
            "en": "Public-law search",
            "hi": "Public-law search",
            "bn": "Public-law search",
            "ta": "Public-law search",
            "te": "Public-law search"
        ],
        "approval_required": [
            "en": "Approval required",
            "hi": "Approval ज़रूरी",
            "bn": "Approval দরকার",
            "ta": "Approval தேவை",
            "te": "Approval అవసరం"
        ],
        "public_law_search_detail": [
            "en": "Ross may prepare a sanitized query preview. It must not search the web until you approve it.",
            "hi": "Ross sanitized query preview तैयार कर सकता है। आपकी approval से पहले यह web search नहीं करेगा।",
            "bn": "Ross sanitized query preview তৈরি করতে পারে। আপনার approval-এর আগে এটি web search করবে না।",
            "ta": "Ross sanitized query preview தயாரிக்கலாம். நீங்கள் approve செய்யும் வரை இது web search செய்யாது.",
            "te": "Ross sanitized query preview సిద్ధం చేయవచ్చు. మీరు approve చేసే వరకు ఇది web search చేయదు."
        ],
        "storage": [
            "en": "Storage",
            "hi": "Storage",
            "bn": "Storage",
            "ta": "Storage",
            "te": "Storage"
        ],
        "case_files": [
            "en": "Case files",
            "hi": "Case files",
            "bn": "Case files",
            "ta": "Case files",
            "te": "Case files"
        ],
        "drafts": [
            "en": "Drafts",
            "hi": "Drafts",
            "bn": "Drafts",
            "ta": "Drafts",
            "te": "Drafts"
        ],
        "notes": [
            "en": "Notes",
            "hi": "Notes",
            "bn": "Notes",
            "ta": "Notes",
            "te": "Notes"
        ],
        "snooze_by_one_day": [
            "en": "Snooze by 1 day",
            "hi": "1 दिन snooze करें",
            "bn": "1 দিন snooze করুন",
            "ta": "1 நாள் snooze செய்யவும்",
            "te": "1 రోజు snooze చేయండి"
        ],
        "delete_task": [
            "en": "Delete task",
            "hi": "task delete करें",
            "bn": "task delete করুন",
            "ta": "task delete செய்யவும்",
            "te": "task delete చేయండి"
        ],
        "prepared_locally": [
            "en": "Prepared locally",
            "hi": "locally तैयार",
            "bn": "locally প্রস্তুত",
            "ta": "locally தயாரானது",
            "te": "locally సిద్ధం"
        ],
        "no_prepared_work_needs_review": [
            "en": "No prepared work needs review",
            "hi": "कोई prepared work review के लिए नहीं है",
            "bn": "কোনো prepared work review দরকার নেই",
            "ta": "review தேவைப்படும் prepared work இல்லை",
            "te": "review అవసరమైన prepared work లేదు"
        ],
        "nothing_prepared_yet": [
            "en": "Nothing prepared yet",
            "hi": "अभी कुछ prepared नहीं है",
            "bn": "এখনও কিছু prepared নয়",
            "ta": "இன்னும் எதுவும் prepared இல்லை",
            "te": "ఇంకా ఏదీ prepared కాలేదు"
        ],
        "nothing_prepared_yet_detail": [
            "en": "Import matter files or ask Ross to prepare today. Ross will not invent work without local matter state.",
            "hi": "matter files import करें या Ross से today prepare करने को कहें। local matter state के बिना Ross work invent नहीं करेगा।",
            "bn": "matter files import করুন বা Ross-কে today prepare করতে বলুন। local matter state ছাড়া Ross work invent করবে না।",
            "ta": "matter files import செய்யவும் அல்லது today prepare செய்ய Ross-ஐ கேளுங்கள். local matter state இல்லாமல் Ross work invent செய்யாது.",
            "te": "matter files import చేయండి లేదా today prepare చేయమని Ross‌ను అడగండి. local matter state లేకుండా Ross work invent చేయదు."
        ],
        "prepared_work_headline_one": [
            "en": "%d prepared item needs review",
            "hi": "%d prepared item review चाहता है",
            "bn": "%d prepared item review দরকার",
            "ta": "%d prepared item review தேவை",
            "te": "%d prepared item review అవసరం"
        ],
        "prepared_work_headline_many": [
            "en": "%d prepared items need review",
            "hi": "%d prepared items review चाहते हैं",
            "bn": "%d prepared items review দরকার",
            "ta": "%d prepared items review தேவை",
            "te": "%d prepared items review అవసరం"
        ],
        "prepared_work_count_one": [
            "en": "%d prepared item",
            "hi": "%d prepared item",
            "bn": "%d prepared item",
            "ta": "%d prepared item",
            "te": "%d prepared item"
        ],
        "prepared_work_count_many": [
            "en": "%d prepared items",
            "hi": "%d prepared items",
            "bn": "%d prepared items",
            "ta": "%d prepared items",
            "te": "%d prepared items"
        ],
        "plain_item_count_one": [
            "en": "%d item",
            "hi": "%d item",
            "bn": "%d item",
            "ta": "%d item",
            "te": "%d item"
        ],
        "plain_item_count_many": [
            "en": "%d items",
            "hi": "%d items",
            "bn": "%d items",
            "ta": "%d items",
            "te": "%d items"
        ],
        "view_all_prepared_work": [
            "en": "View all %@",
            "hi": "सभी %@ देखें",
            "bn": "সব %@ দেখুন",
            "ta": "அனைத்து %@ பார்க்கவும்",
            "te": "అన్ని %@ చూడండి"
        ],
        "upcoming_dates_and_urgent_tasks": [
            "en": "Upcoming dates and urgent tasks",
            "hi": "Upcoming dates और urgent tasks",
            "bn": "Upcoming dates এবং urgent tasks",
            "ta": "Upcoming dates மற்றும் urgent tasks",
            "te": "Upcoming dates మరియు urgent tasks"
        ],
        "work": [
            "en": "Work",
            "hi": "Work",
            "bn": "Work",
            "ta": "Work",
            "te": "Work"
        ],
        "prepared_work_inbox": [
            "en": "Prepared work inbox",
            "hi": "Prepared work inbox",
            "bn": "Prepared work inbox",
            "ta": "Prepared work inbox",
            "te": "Prepared work inbox"
        ],
        "all": [
            "en": "All",
            "hi": "सभी",
            "bn": "সব",
            "ta": "அனைத்தும்",
            "te": "అన్నీ"
        ],
        "no_prepared_work": [
            "en": "No prepared work",
            "hi": "कोई prepared work नहीं",
            "bn": "কোনো prepared work নেই",
            "ta": "prepared work இல்லை",
            "te": "prepared work లేదు"
        ],
        "no_prepared_work_detail": [
            "en": "Ross only shows prepared work generated from real saved matters, files, dates, tasks, drafts, public-law previews, and source refs.",
            "hi": "Ross सिर्फ real saved matters, files, dates, tasks, drafts, public-law previews और source refs से generated prepared work दिखाता है।",
            "bn": "Ross শুধু real saved matters, files, dates, tasks, drafts, public-law previews, এবং source refs থেকে generated prepared work দেখায়।",
            "ta": "real saved matters, files, dates, tasks, drafts, public-law previews மற்றும் source refs-இலிருந்து generated prepared work மட்டும் Ross காட்டும்.",
            "te": "real saved matters, files, dates, tasks, drafts, public-law previews, మరియు source refs నుండి generated prepared work మాత్రమే Ross చూపిస్తుంది."
        ],
        "works_locally_on_this_device": [
            "en": "Works locally on this device",
            "hi": "इस device पर locally काम करता है",
            "bn": "এই device-এ locally কাজ করে",
            "ta": "இந்த device-இல் locally இயங்கும்",
            "te": "ఈ device లో locally పనిచేస్తుంది"
        ],
        "no_dates_or_urgent_tasks_today": [
            "en": "No dates or urgent tasks saved for today.",
            "hi": "आज के लिए कोई dates या urgent tasks saved नहीं हैं।",
            "bn": "আজকের জন্য কোনো dates বা urgent tasks saved নেই।",
            "ta": "இன்றுக்கான dates அல்லது urgent tasks saved இல்லை.",
            "te": "ఈరోజుకు dates లేదా urgent tasks saved లేవు."
        ],
        "setting_up_ross": [
            "en": "Setting up Ross",
            "hi": "Ross setup हो रहा है",
            "bn": "Ross setup হচ্ছে",
            "ta": "Ross setup ஆகிறது",
            "te": "Ross setup అవుతోంది"
        ],
        "assistant_setup_preparing_detail": [
            "en": "%@ is being prepared on this iPhone. You can keep using Ross while setup continues.",
            "hi": "%@ इस iPhone पर prepared हो रहा है। setup जारी रहने तक आप Ross use कर सकते हैं।",
            "bn": "%@ এই iPhone-এ prepared হচ্ছে। setup চলাকালীন আপনি Ross use করতে পারেন।",
            "ta": "%@ இந்த iPhone-இல் prepared ஆகிறது. setup தொடரும் போது Ross use செய்யலாம்.",
            "te": "%@ ఈ iPhone లో prepared అవుతోంది. setup కొనసాగుతున్నప్పుడు Ross use చేయవచ్చు."
        ],
        "open_assistant_setup": [
            "en": "Open assistant setup",
            "hi": "assistant setup खोलें",
            "bn": "assistant setup খুলুন",
            "ta": "assistant setup திறக்கவும்",
            "te": "assistant setup తెరవండి"
        ],
        "refresh_matter_after_import_detail": [
            "en": "Ask Ross to refresh this matter after importing real files.",
            "hi": "real files import करने के बाद Ross से इस matter को refresh कराएं।",
            "bn": "real files import করার পরে Ross-কে এই matter refresh করতে বলুন।",
            "ta": "real files import செய்த பிறகு இந்த matter-ஐ refresh செய்ய Ross-ஐ கேளுங்கள்.",
            "te": "real files import చేసిన తర్వాత ఈ matter ను refresh చేయమని Ross‌ను అడగండి."
        ],
        "refresh_matter": [
            "en": "Refresh matter",
            "hi": "matter refresh करें",
            "bn": "matter refresh করুন",
            "ta": "matter refresh செய்யவும்",
            "te": "matter refresh చేయండి"
        ],
        "no_drafts_generated_yet": [
            "en": "No drafts generated yet.",
            "hi": "अभी drafts generated नहीं हैं।",
            "bn": "এখনও drafts generated হয়নি।",
            "ta": "இன்னும் drafts generated ஆகவில்லை.",
            "te": "ఇంకా drafts generated కాలేదు."
        ],
        "ask_prepare_local_draft_detail": [
            "en": "Ask Ross to prepare a chronology, case note, or order summary from local matter state.",
            "hi": "local matter state से chronology, case note, या order summary तैयार करने के लिए Ross से पूछें।",
            "bn": "local matter state থেকে chronology, case note, বা order summary তৈরি করতে Ross-কে জিজ্ঞাসা করুন।",
            "ta": "local matter state-இலிருந்து chronology, case note அல்லது order summary தயாரிக்க Ross-ஐ கேளுங்கள்.",
            "te": "local matter state నుండి chronology, case note, లేదా order summary సిద్ధం చేయమని Ross‌ను అడగండి."
        ],
        "ask_about_this_matter": [
            "en": "Ask about this matter",
            "hi": "इस matter के बारे में पूछें",
            "bn": "এই matter সম্পর্কে জিজ্ঞাসা করুন",
            "ta": "இந்த matter பற்றி கேளுங்கள்",
            "te": "ఈ matter గురించి అడగండి"
        ],
        "open_drafts": [
            "en": "Open drafts",
            "hi": "drafts खोलें",
            "bn": "drafts খুলুন",
            "ta": "drafts திறக்கவும்",
            "te": "drafts తెరవండి"
        ],
        "open_review": [
            "en": "Open review",
            "hi": "review खोलें",
            "bn": "review খুলুন",
            "ta": "review திறக்கவும்",
            "te": "review తెరవండి"
        ],
        "latest_summary": [
            "en": "Latest summary",
            "hi": "Latest summary",
            "bn": "Latest summary",
            "ta": "Latest summary",
            "te": "Latest summary"
        ],
        "next_hearing_date": [
            "en": "Next hearing: %@",
            "hi": "अगली hearing: %@",
            "bn": "পরবর্তী hearing: %@",
            "ta": "அடுத்த hearing: %@",
            "te": "తదుపరి hearing: %@"
        ],
        "important": [
            "en": "Important",
            "hi": "ज़रूरी",
            "bn": "গুরুত্বপূর্ণ",
            "ta": "முக்கியம்",
            "te": "ముఖ్యం"
        ],
        "stored_on_phone_unless_shared": [
            "en": "Stored on this iPhone unless you share it.",
            "hi": "जब तक आप share नहीं करते, यह इसी iPhone पर stored रहता है।",
            "bn": "আপনি share না করলে এটি এই iPhone-এ stored থাকে।",
            "ta": "நீங்கள் share செய்யாவிட்டால் இது இந்த iPhone-இல் stored இருக்கும்.",
            "te": "మీరు share చేయనంత వరకు ఇది ఈ iPhone లో stored ఉంటుంది."
        ],
        "used_on_this_iphone": [
            "en": "Used on this iPhone",
            "hi": "इस iPhone पर used",
            "bn": "এই iPhone-এ used",
            "ta": "இந்த iPhone-இல் used",
            "te": "ఈ iPhone లో used"
        ],
        "help": [
            "en": "Help",
            "hi": "मदद",
            "bn": "সহায়তা",
            "ta": "உதவி",
            "te": "సహాయం"
        ],
        "start": [
            "en": "Start",
            "hi": "शुरू करें",
            "bn": "শুরু করুন",
            "ta": "தொடங்கு",
            "te": "ప్రారంభం"
        ],
        "help_start_detail": [
            "en": "Add a matter, import a file, then ask Ross.",
            "hi": "मामला जोड़ें, फ़ाइल import करें, फिर Ross से पूछें।",
            "bn": "মামলা যোগ করুন, ফাইল import করুন, তারপর Ross-কে জিজ্ঞাসা করুন।",
            "ta": "வழக்கை சேர்த்து, கோப்பை import செய்து, பிறகு Ross-ஐ கேளுங்கள்.",
            "te": "కేసు జోడించి, ఫైల్ import చేసి, తర్వాత Ross‌ను అడగండి."
        ],
        "help_sharing_detail": [
            "en": "For sharing, open Notes & Drafts and use the system share sheet.",
            "hi": "Sharing के लिए Notes & Drafts खोलें और system share sheet उपयोग करें।",
            "bn": "Sharing-এর জন্য Notes & Drafts খুলে system share sheet ব্যবহার করুন।",
            "ta": "Sharing-க்கு Notes & Drafts திறந்து system share sheet-ஐ பயன்படுத்தவும்.",
            "te": "Sharing కోసం Notes & Drafts తెరిచి system share sheet ఉపయోగించండి."
        ],
        "choose_document_view": [
            "en": "Choose document view",
            "hi": "Document view चुनें",
            "bn": "Document view বেছে নিন",
            "ta": "Document view தேர்வுசெய்க",
            "te": "Document view ఎంచుకోండి"
        ],
        "open_document": [
            "en": "Open document",
            "hi": "दस्तावेज़ खोलें",
            "bn": "নথি খুলুন",
            "ta": "ஆவணத்தை திறக்கவும்",
            "te": "పత్రాన్ని తెరవండి"
        ],
        "continue_in_chat": [
            "en": "Continue in chat",
            "hi": "chat में जारी रखें",
            "bn": "chat-এ চালিয়ে যান",
            "ta": "chat-இல் தொடரவும்",
            "te": "chat లో కొనసాగించండి"
        ],
        "start_review_chat": [
            "en": "Start review chat",
            "hi": "review chat शुरू करें",
            "bn": "review chat শুরু করুন",
            "ta": "review chat தொடங்கவும்",
            "te": "review chat ప్రారంభించండి"
        ],
        "move_earlier": [
            "en": "Move earlier",
            "hi": "पहले ले जाएं",
            "bn": "আগে সরান",
            "ta": "முன்னே நகர்த்தவும்",
            "te": "ముందుకు తరలించండి"
        ],
        "move_later": [
            "en": "Move later",
            "hi": "बाद में ले जाएं",
            "bn": "পরে সরান",
            "ta": "பின்னே நகர்த்தவும்",
            "te": "తర్వాతకు తరలించండి"
        ],
        "open": [
            "en": "Open",
            "hi": "खोलें",
            "bn": "খুলুন",
            "ta": "திறக்கவும்",
            "te": "తెరవండి"
        ],
        "chat": [
            "en": "Chat",
            "hi": "Chat",
            "bn": "Chat",
            "ta": "Chat",
            "te": "Chat"
        ],
        "new_review_chat": [
            "en": "New review chat",
            "hi": "नई review chat",
            "bn": "নতুন review chat",
            "ta": "புதிய review chat",
            "te": "కొత్త review chat"
        ],
        "move_document_earlier": [
            "en": "Move document earlier",
            "hi": "दस्तावेज़ पहले ले जाएं",
            "bn": "নথি আগে সরান",
            "ta": "ஆவணத்தை முன்னே நகர்த்தவும்",
            "te": "పత్రాన్ని ముందుకు తరలించండి"
        ],
        "move_document_later": [
            "en": "Move document later",
            "hi": "दस्तावेज़ बाद में ले जाएं",
            "bn": "নথি পরে সরান",
            "ta": "ஆவணத்தை பின்னே நகர்த்தவும்",
            "te": "పత్రాన్ని తర్వాతకు తరలించండి"
        ],
        "imported_document_label": [
            "en": "Imported %@",
            "hi": "Imported %@",
            "bn": "Imported %@",
            "ta": "Imported %@",
            "te": "Imported %@"
        ],
        "rename_matter": [
            "en": "Rename matter",
            "hi": "मामले का नाम बदलें",
            "bn": "মামলার নাম বদলান",
            "ta": "வழக்கின் பெயரை மாற்றவும்",
            "te": "కేసు పేరు మార్చండి"
        ],
        "folder_color": [
            "en": "Folder color",
            "hi": "Folder color",
            "bn": "Folder color",
            "ta": "Folder color",
            "te": "Folder color"
        ],
        "archive_matter": [
            "en": "Archive matter",
            "hi": "मामला archive करें",
            "bn": "মামলা archive করুন",
            "ta": "வழக்கை archive செய்யவும்",
            "te": "కేసును archive చేయండి"
        ],
        "delete_matter": [
            "en": "Delete matter",
            "hi": "मामला delete करें",
            "bn": "মামলা delete করুন",
            "ta": "வழக்கை delete செய்யவும்",
            "te": "కేసును delete చేయండి"
        ],
        "start_first_matter": [
            "en": "Start with your first matter",
            "hi": "अपने पहले मामले से शुरू करें",
            "bn": "আপনার প্রথম মামলা দিয়ে শুরু করুন",
            "ta": "உங்கள் முதல் வழக்குடன் தொடங்குங்கள்",
            "te": "మీ మొదటి కేసుతో ప్రారంభించండి"
        ],
        "start_first_matter_detail": [
            "en": "Name it now. Ross can extract the details from the first file.",
            "hi": "अभी नाम दें। Ross पहली फ़ाइल से details निकाल सकता है।",
            "bn": "এখন নাম দিন। Ross প্রথম ফাইল থেকে details বের করতে পারে।",
            "ta": "இப்போது பெயரிடுங்கள். Ross முதல் கோப்பிலிருந்து details எடுக்க முடியும்.",
            "te": "ఇప్పుడు పేరు పెట్టండి. Ross మొదటి ఫైల్ నుండి details తీసుకోగలదు."
        ],
        "client_or_case_name": [
            "en": "Client or case name",
            "hi": "Client या case name",
            "bn": "Client বা case name",
            "ta": "Client அல்லது case name",
            "te": "Client లేదా case name"
        ],
        "after_first_matter_import_detail": [
            "en": "After this, import the first PDF, image, or text file. Ross keeps it on this iPhone and prepares the review locally.",
            "hi": "इसके बाद पहली PDF, image या text file import करें। Ross इसे इसी iPhone पर रखता है और review locally तैयार करता है।",
            "bn": "এর পরে প্রথম PDF, image, বা text file import করুন। Ross এটি এই iPhone-এ রাখে এবং review locally প্রস্তুত করে।",
            "ta": "இதற்குப் பிறகு முதல் PDF, image அல்லது text file-ஐ import செய்யவும். Ross அதை இந்த iPhone-இல் வைத்து review-ஐ locally தயாரிக்கும்.",
            "te": "దీని తర్వాత మొదటి PDF, image లేదా text file ను import చేయండి. Ross దాన్ని ఈ iPhone లో ఉంచి review ను locally సిద్ధం చేస్తుంది."
        ],
        "create_matter_workspace": [
            "en": "Create matter workspace",
            "hi": "matter workspace बनाएं",
            "bn": "matter workspace তৈরি করুন",
            "ta": "matter workspace உருவாக்கவும்",
            "te": "matter workspace సృష్టించండి"
        ],
        "setting_up_your_assistant": [
            "en": "Setting up your assistant",
            "hi": "आपका assistant setup हो रहा है",
            "bn": "আপনার assistant setup হচ্ছে",
            "ta": "உங்கள் assistant setup ஆகிறது",
            "te": "మీ assistant setup అవుతోంది"
        ],
        "setup_my_assistant": [
            "en": "Set up My assistant",
            "hi": "My assistant setup करें",
            "bn": "My assistant setup করুন",
            "ta": "My assistant setup செய்யவும்",
            "te": "My assistant setup చేయండి"
        ],
        "required_for_local_ai_tasks": [
            "en": "Required for local AI tasks",
            "hi": "local AI tasks के लिए ज़रूरी",
            "bn": "local AI tasks-এর জন্য দরকার",
            "ta": "local AI tasks-க்கு தேவை",
            "te": "local AI tasks కోసం అవసరం"
        ],
        "sort_matters": [
            "en": "Sort matters",
            "hi": "मामले sort करें",
            "bn": "মামলা sort করুন",
            "ta": "வழக்குகளை sort செய்யவும்",
            "te": "కేసులను sort చేయండి"
        ],
        "choose_matter_view": [
            "en": "Choose matter view",
            "hi": "matter view चुनें",
            "bn": "matter view বেছে নিন",
            "ta": "matter view தேர்வுசெய்க",
            "te": "matter view ఎంచుకోండి"
        ],
        "needs_review": [
            "en": "Needs review",
            "hi": "Review चाहिए",
            "bn": "Review দরকার",
            "ta": "Review தேவை",
            "te": "Review అవసరం"
        ],
        "review_items_from_files": [
            "en": "%@ from your files.",
            "hi": "आपकी files से %@.",
            "bn": "আপনার files থেকে %@.",
            "ta": "உங்கள் files-இலிருந்து %@.",
            "te": "మీ files నుండి %@."
        ],
        "review_items_need_advocate_review": [
            "en": "%@ still need advocate review.",
            "hi": "%@ अभी advocate review चाहते हैं.",
            "bn": "%@ এখনও advocate review দরকার.",
            "ta": "%@ இன்னும் advocate review தேவை.",
            "te": "%@ ఇంకా advocate review అవసరం."
        ],
        "review_items_resolve_before_relying": [
            "en": "Resolve %@ before relying on extracted details.",
            "hi": "extracted details पर भरोसा करने से पहले %@ resolve करें.",
            "bn": "extracted details-এ নির্ভর করার আগে %@ resolve করুন.",
            "ta": "extracted details-ஐ நம்புவதற்கு முன் %@ resolve செய்யவும்.",
            "te": "extracted details పై ఆధారపడే ముందు %@ resolve చేయండి."
        ],
        "review_items_need_confirmation_before_file_use": [
            "en": "%@ still need advocate confirmation before relying on this file.",
            "hi": "इस file पर भरोसा करने से पहले %@ advocate confirmation चाहते हैं.",
            "bn": "এই file-এ নির্ভর করার আগে %@ advocate confirmation দরকার.",
            "ta": "இந்த file-ஐ நம்புவதற்கு முன் %@ advocate confirmation தேவை.",
            "te": "ఈ file పై ఆధారపడే ముందు %@ advocate confirmation అవసరం."
        ],
        "matter_memory_review_extracted_legal_issues": [
            "en": "Review extracted legal issues and directions.",
            "hi": "extracted legal issues और directions review करें.",
            "bn": "extracted legal issues এবং directions review করুন.",
            "ta": "extracted legal issues மற்றும் directions review செய்யவும்.",
            "te": "extracted legal issues మరియు directions review చేయండి."
        ],
        "matter_memory_extraction_available": [
            "en": "Extraction from your files is available for this matter.",
            "hi": "इस matter के लिए आपकी files से extraction available है.",
            "bn": "এই matter-এর জন্য আপনার files থেকে extraction available.",
            "ta": "இந்த matter-க்கு உங்கள் files-இலிருந்து extraction available.",
            "te": "ఈ matter కోసం మీ files నుండి extraction available."
        ],
        "matter_memory_review_uncertain_fields": [
            "en": "Review uncertain extracted fields before relying on them.",
            "hi": "इन पर भरोसा करने से पहले uncertain extracted fields review करें.",
            "bn": "এগুলোর ওপর নির্ভর করার আগে uncertain extracted fields review করুন.",
            "ta": "இவற்றை நம்புவதற்கு முன் uncertain extracted fields review செய்யவும்.",
            "te": "వాటిపై ఆధారపడే ముందు uncertain extracted fields review చేయండి."
        ],
        "matter_memory_import_first_document": [
            "en": "Import the first pleading, order, or note for this matter.",
            "hi": "इस matter के लिए पहली pleading, order, या note import करें.",
            "bn": "এই matter-এর জন্য প্রথম pleading, order, বা note import করুন.",
            "ta": "இந்த matter-க்கு முதல் pleading, order, அல்லது note import செய்யவும்.",
            "te": "ఈ matter కోసం మొదటి pleading, order, లేదా note import చేయండి."
        ],
        "matter_memory_open_source_chips": [
            "en": "Open source chips before sharing or filing.",
            "hi": "share या file करने से पहले source chips खोलें.",
            "bn": "share বা file করার আগে source chips খুলুন.",
            "ta": "share அல்லது file செய்வதற்கு முன் source chips திறக்கவும்.",
            "te": "share లేదా file చేయడానికి ముందు source chips తెరవండి."
        ],
        "matter_memory_generate_local_draft": [
            "en": "Generate a local chronology or order summary draft.",
            "hi": "local chronology या order summary draft generate करें.",
            "bn": "local chronology বা order summary draft generate করুন.",
            "ta": "local chronology அல்லது order summary draft generate செய்யவும்.",
            "te": "local chronology లేదా order summary draft generate చేయండి."
        ],
        "document_review_ready_for_matter_chat": [
            "en": "This file is ready to use in the matter chat.",
            "hi": "यह file matter chat में use करने के लिए ready है.",
            "bn": "এই file matter chat-এ use করার জন্য ready.",
            "ta": "இந்த file matter chat-இல் use செய்ய ready.",
            "te": "ఈ file matter chat లో use చేయడానికి ready."
        ],
        "document_review_updated_for_title": [
            "en": "Review updated for %@",
            "hi": "%@ के लिए review updated",
            "bn": "%@-এর review updated",
            "ta": "%@ review updated",
            "te": "%@ review updated"
        ],
        "matter_chat_updated_ready": [
            "en": "Matter chat updated · ready to use",
            "hi": "Matter chat updated · use के लिए ready",
            "bn": "Matter chat updated · use করার জন্য ready",
            "ta": "Matter chat updated · use செய்ய ready",
            "te": "Matter chat updated · use చేయడానికి ready"
        ],
        "matter_chat_updated_needs_review": [
            "en": "Matter chat updated · needs review",
            "hi": "Matter chat updated · review चाहिए",
            "bn": "Matter chat updated · review দরকার",
            "ta": "Matter chat updated · review தேவை",
            "te": "Matter chat updated · review అవసరం"
        ],
        "document_review_next_date_captured": [
            "en": "Next date captured: %@.",
            "hi": "Next date captured: %@.",
            "bn": "Next date captured: %@.",
            "ta": "Next date captured: %@.",
            "te": "Next date captured: %@."
        ],
        "matter_memory_local_notice_next_date": [
            "en": "Case files stay on this device. Next date found: %@",
            "hi": "Case files इसी device पर रहती हैं। Next date मिली: %@",
            "bn": "Case files এই device-এ থাকে। Next date পাওয়া গেছে: %@",
            "ta": "Case files இந்த device-இல் இருக்கும். Next date கண்டது: %@",
            "te": "Case files ఈ device లోనే ఉంటాయి. Next date కనుగొంది: %@"
        ],
        "matter_memory_ready_for_first_document": [
            "en": "Ross is ready to build this matter once the first document is imported on this device.",
            "hi": "इस device पर पहला document import होते ही Ross इस matter को build करने के लिए ready है.",
            "bn": "এই device-এ প্রথম document import হলেই Ross এই matter build করতে ready.",
            "ta": "இந்த device-இல் முதல் document import ஆனதும் Ross இந்த matter build செய்ய ready.",
            "te": "ఈ device లో మొదటి document import అయిన వెంటనే Ross ఈ matter build చేయడానికి ready."
        ],
        "matter_memory_documents_reading_summary": [
            "en": "Ross has %@ in this matter; %d still reading.",
            "hi": "Ross के पास इस matter में %@ हैं; %d अभी reading में हैं.",
            "bn": "Ross-এর কাছে এই matter-এ %@ আছে; %d এখনও reading.",
            "ta": "இந்த matter-இல் Ross-க்கு %@ உள்ளது; %d இன்னும் reading.",
            "te": "ఈ matter లో Ross కు %@ ఉన్నాయి; %d ఇంకా reading లో ఉన్నాయి."
        ],
        "matter_memory_documents_read_summary": [
            "en": "Ross has read %@ in this matter.",
            "hi": "Ross ने इस matter में %@ पढ़े हैं.",
            "bn": "Ross এই matter-এ %@ পড়েছে.",
            "ta": "Ross இந்த matter-இல் %@ வாசித்தது.",
            "te": "Ross ఈ matter లో %@ చదివింది."
        ],
        "matter_memory_ready_documents": [
            "en": "%d ready to use.",
            "hi": "%d use के लिए ready.",
            "bn": "%d use করার জন্য ready.",
            "ta": "%d use செய்ய ready.",
            "te": "%d use చేయడానికి ready."
        ],
        "matter_memory_file_types_seen": [
            "en": "File types seen: %@.",
            "hi": "File types देखे गए: %@.",
            "bn": "File types দেখা গেছে: %@.",
            "ta": "File types கண்டது: %@.",
            "te": "File types కనుగొంది: %@."
        ],
        "matter_memory_next_date_captured": [
            "en": "Next date %@ is already captured.",
            "hi": "Next date %@ already captured है.",
            "bn": "Next date %@ already captured.",
            "ta": "Next date %@ already captured.",
            "te": "Next date %@ already captured."
        ],
        "matter_memory_open_tasks_saved": [
            "en": "%d open task(s) are saved for this matter.",
            "hi": "इस matter के लिए %d open task(s) saved हैं.",
            "bn": "এই matter-এর জন্য %d open task(s) saved আছে.",
            "ta": "இந்த matter-க்கு %d open task(s) saved உள்ளது.",
            "te": "ఈ matter కోసం %d open task(s) saved ఉన్నాయి."
        ],
        "matter_memory_latest_file": [
            "en": "Latest file: %@.",
            "hi": "Latest file: %@.",
            "bn": "Latest file: %@.",
            "ta": "Latest file: %@.",
            "te": "Latest file: %@."
        ],
        "no_matters_match_search": [
            "en": "No matters match this search.",
            "hi": "इस search से कोई मामला नहीं मिला।",
            "bn": "এই search-এ কোনো মামলা মেলেনি।",
            "ta": "இந்த search-க்கு எந்த வழக்கும் பொருந்தவில்லை.",
            "te": "ఈ search కు ఏ కేసులు సరిపోలలేదు."
        ],
        "recent_files": [
            "en": "Recent files",
            "hi": "हाल की files",
            "bn": "সাম্প্রতিক files",
            "ta": "சமீபத்திய files",
            "te": "ఇటీవలి files"
        ],
        "save": [
            "en": "Save",
            "hi": "Save",
            "bn": "Save",
            "ta": "Save",
            "te": "Save"
        ],
        "rename_matter_detail": [
            "en": "Update the matter name on this device.",
            "hi": "इस device पर matter name update करें।",
            "bn": "এই device-এ matter name update করুন।",
            "ta": "இந்த device-இல் matter name update செய்யவும்.",
            "te": "ఈ device లో matter name update చేయండి."
        ],
        "delete_matter_question": [
            "en": "Delete matter?",
            "hi": "मामला delete करें?",
            "bn": "মামলা delete করবেন?",
            "ta": "வழக்கை delete செய்யவா?",
            "te": "కేసును delete చేయాలా?"
        ],
        "delete": [
            "en": "Delete",
            "hi": "Delete",
            "bn": "Delete",
            "ta": "Delete",
            "te": "Delete"
        ],
        "delete_matter_detail": [
            "en": "Deleting %@ removes its files, tasks, chat context, and saved reports from this device.",
            "hi": "%@ delete करने से इसकी files, tasks, chat context और saved reports इस device से हट जाएंगे।",
            "bn": "%@ delete করলে এর files, tasks, chat context, এবং saved reports এই device থেকে মুছে যাবে।",
            "ta": "%@ delete செய்தால் அதன் files, tasks, chat context மற்றும் saved reports இந்த device-இலிருந்து நீக்கப்படும்.",
            "te": "%@ delete చేస్తే దాని files, tasks, chat context మరియు saved reports ఈ device నుండి తొలగించబడతాయి."
        ],
        "matter_search_placeholder": [
            "en": "Search by matter, client, or case number",
            "hi": "matter, client या case number से search करें",
            "bn": "matter, client, বা case number দিয়ে search করুন",
            "ta": "matter, client அல்லது case number மூலம் search செய்யவும்",
            "te": "matter, client లేదా case number తో search చేయండి"
        ],
        "clear_matter_search": [
            "en": "Clear matter search",
            "hi": "matter search साफ़ करें",
            "bn": "matter search পরিষ্কার করুন",
            "ta": "matter search அழிக்கவும்",
            "te": "matter search క్లియర్ చేయండి"
        ],
        "translate_to": [
            "en": "Translate to %@",
            "hi": "%@ में अनुवाद करें",
            "bn": "%@-এ অনুবাদ করুন",
            "ta": "%@ மொழிக்கு மொழிபெயர்க்கவும்",
            "te": "%@ కు అనువదించండి"
        ],
        "translation_ready": [
            "en": "AI translation is available for advocate review.",
            "hi": "AI अनुवाद अधिवक्ता समीक्षा के लिए उपलब्ध है।",
            "bn": "AI অনুবাদ আইনজীবীর পর্যালোচনার জন্য প্রস্তুত।",
            "ta": "AI மொழிபெயர்ப்பு வழக்கறிஞர் மதிப்பாய்வுக்கு கிடைக்கிறது.",
            "te": "AI అనువాదం న్యాయవాది సమీక్ష కోసం అందుబాటులో ఉంది."
        ],
        "translation_needs_assistant": [
            "en": "Set up the private assistant to translate locally.",
            "hi": "स्थानीय अनुवाद के लिए निजी सहायक सेट करें।",
            "bn": "স্থানীয়ভাবে অনুবাদ করতে ব্যক্তিগত সহকারী সেট আপ করুন।",
            "ta": "உள்ளூரில் மொழிபெயர்க்க தனிப்பட்ட உதவியாளரை அமைக்கவும்.",
            "te": "స్థానికంగా అనువదించడానికి ప్రైవేట్ సహాయకుడిని సెటప్ చేయండి."
        ],
        "ask_placeholder_file": [
            "en": "Ask Ross about this file…",
            "hi": "Ross से इस फ़ाइल के बारे में पूछें…",
            "bn": "এই ফাইল সম্পর্কে Ross-কে জিজ্ঞাসা করুন…",
            "ta": "இந்த கோப்பைப் பற்றி Ross-ஐ கேளுங்கள்…",
            "te": "ఈ ఫైల్ గురించి Ross‌ను అడగండి…"
        ],
        "ask_placeholder_matter": [
            "en": "Ask Ross about this matter…",
            "hi": "Ross से इस मामले के बारे में पूछें…",
            "bn": "এই মামলা সম্পর্কে Ross-কে জিজ্ঞাসা করুন…",
            "ta": "இந்த வழக்கைப் பற்றி Ross-ஐ கேளுங்கள்…",
            "te": "ఈ కేసు గురించి Ross‌ను అడగండి…"
        ],
        "ask_placeholder_general": [
            "en": "Ask Ross about today, a matter, or a file…",
            "hi": "Ross से आज, किसी मामले, या किसी फ़ाइल के बारे में पूछें…",
            "bn": "আজ, কোনো মামলা, বা কোনো ফাইল সম্পর্কে Ross-কে জিজ্ঞাসা করুন…",
            "ta": "இன்று, ஒரு வழக்கு, அல்லது ஒரு கோப்பு பற்றி Ross-ஐ கேளுங்கள்…",
            "te": "ఈ రోజు, ఒక కేసు, లేదా ఒక ఫైల్ గురించి Ross‌ను అడగండి…"
        ],
        "ask_collapsed_general": [
            "en": "Ask Ross…",
            "hi": "Ross से पूछें…",
            "bn": "Ross-কে জিজ্ঞাসা করুন…",
            "ta": "Ross-ஐ கேளுங்கள்…",
            "te": "Ross‌ను అడగండి…"
        ],
        "ask_sheet_placeholder": [
            "en": "Ask Ross about this matter, a tagged file, or your next drafting step.",
            "hi": "Ross से इस मामले, टैग की गई फ़ाइल, या अगले ड्राफ्टिंग कदम के बारे में पूछें।",
            "bn": "এই মামলা, ট্যাগ করা ফাইল, বা আপনার পরবর্তী খসড়া ধাপ সম্পর্কে Ross-কে জিজ্ঞাসা করুন।",
            "ta": "இந்த வழக்கு, குறியிட்ட கோப்பு, அல்லது உங்கள் அடுத்த வரைவு படி பற்றி Ross-ஐ கேளுங்கள்.",
            "te": "ఈ కేసు, ట్యాగ్ చేసిన ఫైల్, లేదా మీ తదుపరి డ్రాఫ్టింగ్ అడుగు గురించి Ross‌ను అడగండి."
        ],
        "ask_ross": [
            "en": "Ask Ross",
            "hi": "Ross से पूछें",
            "bn": "Ross-কে জিজ্ঞাসা করুন",
            "ta": "Ross-ஐ கேளுங்கள்",
            "te": "Ross‌ను అడగండి"
        ],
        "send_ask_ross_question": [
            "en": "Send Ask Ross question",
            "hi": "Ask Ross question भेजें",
            "bn": "Ask Ross question পাঠান",
            "ta": "Ask Ross question அனுப்பவும்",
            "te": "Ask Ross question పంపండి"
        ],
        "close_ask_ross": [
            "en": "Close Ask Ross",
            "hi": "Ask Ross बंद करें",
            "bn": "Ask Ross বন্ধ করুন",
            "ta": "Ask Ross மூடவும்",
            "te": "Ask Ross మూసివేయండి"
        ],
        "asking_about_scope": [
            "en": "Asking about %@",
            "hi": "%@ के बारे में पूछ रहे हैं",
            "bn": "%@ সম্পর্কে জিজ্ঞাসা করছেন",
            "ta": "%@ பற்றி கேட்கிறீர்கள்",
            "te": "%@ గురించి అడుగుతున్నారు"
        ],
        "ask_attach_or_command_hint": [
            "en": "Tap + to attach a file, or say \"add task\" or \"save date\".",
            "hi": "file attach करने के लिए + tap करें, या \"add task\" या \"save date\" कहें।",
            "bn": "file attach করতে + tap করুন, বা \"add task\" বা \"save date\" বলুন।",
            "ta": "file attach செய்ய + tap செய்யவும், அல்லது \"add task\" அல்லது \"save date\" சொல்லவும்.",
            "te": "file attach చేయడానికి + tap చేయండి, లేదా \"add task\" లేదా \"save date\" అని చెప్పండి."
        ],
        "ask_choose_matter_first": [
            "en": "Choose a matter first",
            "hi": "पहले matter चुनें",
            "bn": "আগে matter বেছে নিন",
            "ta": "முதலில் matter தேர்வுசெய்யவும்",
            "te": "ముందుగా matter ఎంచుకోండి"
        ],
        "ask_pick_matter_before_draft": [
            "en": "Pick a matter in the bar above before generating a %@ draft.",
            "hi": "%@ draft बनाने से पहले ऊपर की bar में matter चुनें।",
            "bn": "%@ draft তৈরি করার আগে ওপরের bar-এ matter বেছে নিন।",
            "ta": "%@ draft உருவாக்குவதற்கு முன் மேலே உள்ள bar-ல் matter தேர்வுசெய்யவும்.",
            "te": "%@ draft తయారు చేయడానికి ముందు పై bar లో matter ఎంచుకోండి."
        ],
        "ask_no_export_created_yet": [
            "en": "Ross did not create an export yet.",
            "hi": "Ross ने अभी export नहीं बनाया।",
            "bn": "Ross এখনও export তৈরি করেনি।",
            "ta": "Ross இன்னும் export உருவாக்கவில்லை.",
            "te": "Ross ఇంకా export సృష్టించలేదు."
        ],
        "no_change_made": [
            "en": "No change made",
            "hi": "कोई बदलाव नहीं",
            "bn": "কোনো পরিবর্তন হয়নি",
            "ta": "மாற்றம் எதுவும் இல்லை",
            "te": "ఏ మార్పు లేదు"
        ],
        "saved_locally": [
            "en": "Saved locally",
            "hi": "locally saved",
            "bn": "locally saved",
            "ta": "locally saved",
            "te": "locally saved"
        ],
        "task_added_title": [
            "en": "Task added.",
            "hi": "Task added.",
            "bn": "Task added.",
            "ta": "Task added.",
            "te": "Task added."
        ],
        "ask_task_due_on": [
            "en": "Due %@.",
            "hi": "Due %@.",
            "bn": "Due %@.",
            "ta": "Due %@.",
            "te": "Due %@."
        ],
        "ask_open_task_list_any_time": [
            "en": "Open the task list any time to mark it done or snooze it.",
            "hi": "इसे done mark या snooze करने के लिए task list कभी भी खोलें।",
            "bn": "done mark বা snooze করতে task list যে কোনো সময় খুলুন।",
            "ta": "done mark அல்லது snooze செய்ய task list எப்போது வேண்டுமானாலும் திறக்கவும்.",
            "te": "done mark లేదా snooze చేయడానికి task list ఎప్పుడైనా తెరవండి."
        ],
        "ask_task_added_on_device": [
            "en": "%@ was added on this device.",
            "hi": "%@ इस device पर added हुआ।",
            "bn": "%@ এই device-এ added হয়েছে।",
            "ta": "%@ இந்த device-ல் added ஆனது.",
            "te": "%@ ఈ device లో added అయ్యింది."
        ],
        "task_marked_done_title": [
            "en": "Task marked done.",
            "hi": "Task done mark हुआ।",
            "bn": "Task done mark হয়েছে।",
            "ta": "Task done mark ஆனது.",
            "te": "Task done mark అయ్యింది."
        ],
        "task_not_found_title": [
            "en": "Task not found.",
            "hi": "Task नहीं मिला।",
            "bn": "Task পাওয়া যায়নি।",
            "ta": "Task கிடைக்கவில்லை.",
            "te": "Task కనబడలేదు."
        ],
        "ask_matching_task_updated": [
            "en": "Ross updated the matching task on this device.",
            "hi": "Ross ने matching task इस device पर update किया।",
            "bn": "Ross matching task এই device-এ update করেছে।",
            "ta": "Ross matching task-ஐ இந்த device-ல் update செய்தது.",
            "te": "Ross matching task ను ఈ device లో update చేసింది."
        ],
        "ask_no_open_matching_task": [
            "en": "Ross could not find an open matching task in this scope.",
            "hi": "Ross को इस scope में open matching task नहीं मिला।",
            "bn": "Ross এই scope-এ open matching task খুঁজে পায়নি।",
            "ta": "Ross இந்த scope-ல் open matching task கண்டுபிடிக்கவில்லை.",
            "te": "Ross ఈ scope లో open matching task కనుగొనలేదు."
        ],
        "ask_task_text_stayed_on_device": [
            "en": "No case files or task text left this device.",
            "hi": "कोई case file या task text इस device से बाहर नहीं गया।",
            "bn": "কোনো case file বা task text এই device ছাড়েনি।",
            "ta": "எந்த case file அல்லது task text இந்த device-ஐ விட்டு செல்லவில்லை.",
            "te": "ఏ case file లేదా task text ఈ device ను వదిలి వెళ్లలేదు."
        ],
        "ask_ross_answering_pending": [
            "en": "Ross is answering...",
            "hi": "Ross जवाब तैयार कर रहा है...",
            "bn": "Ross উত্তর তৈরি করছে...",
            "ta": "Ross பதில் தயாரிக்கிறது...",
            "te": "Ross సమాధానం సిద్ధం చేస్తోంది..."
        ],
        "ask_pending_private_answer_status": [
            "en": "%@ is preparing a private answer",
            "hi": "%@ private answer तैयार कर रहा है",
            "bn": "%@ private answer তৈরি করছে",
            "ta": "%@ private answer தயாரிக்கிறது",
            "te": "%@ private answer సిద్ధం చేస్తోంది"
        ],
        "ask_pending_private_answer_detail": [
            "en": "%@ is working on this iPhone. Ross will replace this with the private answer as soon as it finishes.",
            "hi": "%@ इस iPhone पर काम कर रहा है। finish होते ही Ross इसे private answer से replace करेगा।",
            "bn": "%@ এই iPhone-এ কাজ করছে। শেষ হলেই Ross এটিকে private answer দিয়ে replace করবে।",
            "ta": "%@ இந்த iPhone-ல் வேலை செய்கிறது. முடிந்ததும் Ross இதை private answer-ஆக replace செய்யும்.",
            "te": "%@ ఈ iPhone లో పని చేస్తోంది. పూర్తయ్యగానే Ross దీన్ని private answer తో replace చేస్తుంది."
        ],
        "ask_local_not_found_title": [
            "en": "I could not find this in your case files.",
            "hi": "यह आपकी case files में नहीं मिला।",
            "bn": "এটি আপনার case files-এ পাওয়া যায়নি।",
            "ta": "இது உங்கள் case files-இல் கிடைக்கவில்லை.",
            "te": "ఇది మీ case files లో కనిపించలేదు."
        ],
        "ask_local_not_found_detail": [
            "en": "I could not find this in your case files.",
            "hi": "यह आपकी case files में नहीं मिला।",
            "bn": "এটি আপনার case files-এ পাওয়া যায়নি।",
            "ta": "இது உங்கள் case files-இல் கிடைக்கவில்லை.",
            "te": "ఇది మీ case files లో కనిపించలేదు."
        ],
        "ask_local_matter_summary_title": [
            "en": "Matter summary",
            "hi": "मामले का सारांश",
            "bn": "মামলার সারাংশ",
            "ta": "வழக்கு சுருக்கம்",
            "te": "కేసు సారాంశం"
        ],
        "ask_local_document_summary_title": [
            "en": "Document summary",
            "hi": "दस्तावेज़ सारांश",
            "bn": "নথির সারাংশ",
            "ta": "ஆவண சுருக்கம்",
            "te": "పత్ర సారాంశం"
        ],
        "ask_local_important_dates_title": [
            "en": "Important dates",
            "hi": "ज़रूरी तारीखें",
            "bn": "গুরুত্বপূর্ণ তারিখ",
            "ta": "முக்கிய தேதிகள்",
            "te": "ముఖ్యమైన తేదీలు"
        ],
        "ask_local_next_actions_title": [
            "en": "Next actions",
            "hi": "अगले कदम",
            "bn": "পরবর্তী পদক্ষেপ",
            "ta": "அடுத்த படிகள்",
            "te": "తదుపరి చర్యలు"
        ],
        "ask_local_tasks_title": [
            "en": "Tasks from your files",
            "hi": "आपकी files से tasks",
            "bn": "আপনার files থেকে tasks",
            "ta": "உங்கள் files-இலிருந்து tasks",
            "te": "మీ files నుండి tasks"
        ],
        "ask_local_review_items_title": [
            "en": "Review items from your files",
            "hi": "आपकी files से review items",
            "bn": "আপনার files থেকে review items",
            "ta": "உங்கள் files-இலிருந்து review items",
            "te": "మీ files నుండి review items"
        ],
        "ask_local_drafted_title": [
            "en": "Ross drafted this from your files",
            "hi": "Ross ने यह आपकी files से draft किया",
            "bn": "Ross এটি আপনার files থেকে draft করেছে",
            "ta": "Ross இதை உங்கள் files-இலிருந்து draft செய்தது",
            "te": "Ross దీన్ని మీ files నుండి draft చేసింది"
        ],
        "ask_local_answered_files_status": [
            "en": "Answered from your files",
            "hi": "आपकी files से जवाब",
            "bn": "আপনার files থেকে উত্তর",
            "ta": "உங்கள் files-இலிருந்து பதில்",
            "te": "మీ files నుండి సమాధానం"
        ],
        "ask_local_answered_selected_files_status": [
            "en": "Answered from selected files",
            "hi": "selected files से जवाब",
            "bn": "selected files থেকে উত্তর",
            "ta": "selected files-இலிருந்து பதில்",
            "te": "selected files నుండి సమాధానం"
        ],
        "ask_local_legal_search_off_status": [
            "en": "Legal Search is off",
            "hi": "Legal Search off है",
            "bn": "Legal Search off",
            "ta": "Legal Search off",
            "te": "Legal Search off"
        ],
        "ask_local_review_items_still_need_review": [
            "en": "%@ still need review.",
            "hi": "%@ को अभी review चाहिए।",
            "bn": "%@ এখনও review দরকার।",
            "ta": "%@ இன்னும் review தேவை.",
            "te": "%@ కు ఇంకా review అవసరం."
        ],
        "ask_pick_matter_before_date": [
            "en": "Pick a matter in the bar above before saving a hearing date, deadline, or reminder.",
            "hi": "hearing date, deadline, या reminder save करने से पहले ऊपर की bar में matter चुनें।",
            "bn": "hearing date, deadline, বা reminder save করার আগে ওপরের bar-এ matter বেছে নিন।",
            "ta": "hearing date, deadline, அல்லது reminder save செய்யும் முன் மேலே உள்ள bar-ல் matter தேர்வுசெய்யவும்.",
            "te": "hearing date, deadline, లేదా reminder save చేయడానికి ముందు పై bar లో matter ఎంచుకోండి."
        ],
        "date_saved_title": [
            "en": "Date saved.",
            "hi": "Date saved.",
            "bn": "Date saved.",
            "ta": "Date saved.",
            "te": "Date saved."
        ],
        "ask_date_saved_for": [
            "en": "%@ is saved for %@.",
            "hi": "%@ %@ के लिए saved है।",
            "bn": "%@ %@-এর জন্য saved হয়েছে।",
            "ta": "%@ %@-க்கு saved ஆனது.",
            "te": "%@ %@ కోసం saved అయ్యింది."
        ],
        "ask_date_manage_from_timeline": [
            "en": "You can mark it done or cancel it from the matter timeline.",
            "hi": "इसे matter timeline से done mark या cancel कर सकते हैं।",
            "bn": "matter timeline থেকে এটি done mark বা cancel করতে পারেন।",
            "ta": "matter timeline-இலிருந்து இதை done mark அல்லது cancel செய்யலாம்.",
            "te": "matter timeline నుండి దీనిని done mark లేదా cancel చేయవచ్చు."
        ],
        "ask_draft_ready_title": [
            "en": "%@ ready",
            "hi": "%@ ready",
            "bn": "%@ ready",
            "ta": "%@ ready",
            "te": "%@ ready"
        ],
        "ask_could_not_create_draft_title": [
            "en": "Could not create %@",
            "hi": "%@ नहीं बन सका",
            "bn": "%@ তৈরি করা যায়নি",
            "ta": "%@ உருவாக்க முடியவில்லை",
            "te": "%@ సృష్టించలేకపోయింది"
        ],
        "ask_local_draft_created": [
            "en": "Ross created a local %@ draft for advocate review.",
            "hi": "Ross ने advocate review के लिए local %@ draft बनाया।",
            "bn": "Ross advocate review-এর জন্য local %@ draft তৈরি করেছে।",
            "ta": "advocate review-க்காக Ross local %@ draft உருவாக்கியது.",
            "te": "advocate review కోసం Ross local %@ draft సృష్టించింది."
        ],
        "ask_open_notes_drafts_to_review_pdf": [
            "en": "Open Notes & Drafts to review or share the PDF.",
            "hi": "PDF review या share करने के लिए Notes & Drafts खोलें।",
            "bn": "PDF review বা share করতে Notes & Drafts খুলুন।",
            "ta": "PDF review அல்லது share செய்ய Notes & Drafts திறக்கவும்.",
            "te": "PDF review లేదా share చేయడానికి Notes & Drafts తెరవండి."
        ],
        "ask_could_not_create_local_draft": [
            "en": "Ross could not create the local draft right now.",
            "hi": "Ross अभी local draft नहीं बना सका।",
            "bn": "Ross এখন local draft তৈরি করতে পারেনি।",
            "ta": "Ross இப்போது local draft உருவாக்க முடியவில்லை.",
            "te": "Ross ప్రస్తుతం local draft సృష్టించలేకపోయింది."
        ],
        "ask_matter_files_stayed_on_device": [
            "en": "Your matter files stayed safe on this device.",
            "hi": "आपकी matter files इस device पर सुरक्षित रहीं।",
            "bn": "আপনার matter files এই device-এ নিরাপদে রইল।",
            "ta": "உங்கள் matter files இந்த device-ல் பாதுகாப்பாக இருந்தன.",
            "te": "మీ matter files ఈ device లో సురక్షితంగా ఉన్నాయి."
        ],
        "draft_ready": [
            "en": "Draft ready",
            "hi": "Draft ready",
            "bn": "Draft ready",
            "ta": "Draft ready",
            "te": "Draft ready"
        ],
        "draft_unavailable": [
            "en": "Draft unavailable",
            "hi": "Draft उपलब्ध नहीं",
            "bn": "Draft পাওয়া যাচ্ছে না",
            "ta": "Draft கிடைக்கவில்லை",
            "te": "Draft అందుబాటులో లేదు"
        ],
        "ask_choose_document_first": [
            "en": "Choose a document first",
            "hi": "पहले document चुनें",
            "bn": "আগে document বেছে নিন",
            "ta": "முதலில் document தேர்வுசெய்யவும்",
            "te": "ముందుగా document ఎంచుకోండి"
        ],
        "ask_tag_file_before_review_again": [
            "en": "Tag a file in Ask Ross or open the document before asking Ross to review it again.",
            "hi": "Ross से फिर review कराने से पहले Ask Ross में file tag करें या document खोलें।",
            "bn": "Ross-কে আবার review করতে বলার আগে Ask Ross-এ file tag করুন বা document খুলুন।",
            "ta": "Ross மீண்டும் review செய்யச் சொல்லும் முன் Ask Ross-ல் file tag செய்யவும் அல்லது document திறக்கவும்.",
            "te": "Ross మళ్లీ review చేయడానికి ముందు Ask Ross లో file tag చేయండి లేదా document తెరవండి."
        ],
        "ask_tag_file_before_create_tasks": [
            "en": "Tag a file in Ask Ross or open the latest document before asking Ross to create tasks from it.",
            "hi": "उससे tasks बनाने को कहने से पहले Ask Ross में file tag करें या latest document खोलें।",
            "bn": "সেখান থেকে tasks তৈরি করতে বলার আগে Ask Ross-এ file tag করুন বা latest document খুলুন।",
            "ta": "அதில் இருந்து tasks உருவாக்கச் சொல்லும் முன் Ask Ross-ல் file tag செய்யவும் அல்லது latest document திறக்கவும்.",
            "te": "దాని నుంచి tasks సృష్టించమని అడగడానికి ముందు Ask Ross లో file tag చేయండి లేదా latest document తెరవండి."
        ],
        "ross_changed_nothing": [
            "en": "Ross did not change anything.",
            "hi": "Ross ने कुछ नहीं बदला।",
            "bn": "Ross কিছু বদলায়নি।",
            "ta": "Ross எதையும் மாற்றவில்லை.",
            "te": "Ross ఏదీ మార్చలేదు."
        ],
        "review_updated_title": [
            "en": "Review updated.",
            "hi": "Review updated.",
            "bn": "Review updated.",
            "ta": "Review updated.",
            "te": "Review updated."
        ],
        "review_updated": [
            "en": "Review updated",
            "hi": "Review updated",
            "bn": "Review updated",
            "ta": "Review updated",
            "te": "Review updated"
        ],
        "ask_reviewed_document_again": [
            "en": "Ross reviewed %@ again on this device.",
            "hi": "Ross ने %@ को इस device पर फिर review किया।",
            "bn": "Ross এই device-এ %@ আবার review করেছে।",
            "ta": "Ross இந்த device-ல் %@ மீண்டும் review செய்தது.",
            "te": "Ross ఈ device లో %@ ను మళ్లీ review చేసింది."
        ],
        "ask_open_review_items_to_confirm": [
            "en": "Open the review items to accept, edit, or ignore anything that still needs attention.",
            "hi": "जो items अभी attention चाहते हैं, उन्हें accept, edit, या ignore करने के लिए review items खोलें।",
            "bn": "যেগুলো এখনও attention চায়, সেগুলো accept, edit, বা ignore করতে review items খুলুন।",
            "ta": "இன்னும் attention தேவைப்படுவதை accept, edit, அல்லது ignore செய்ய review items திறக்கவும்.",
            "te": "ఇంకా attention అవసరమైన వాటిని accept, edit, లేదా ignore చేయడానికి review items తెరవండి."
        ],
        "ask_no_new_tasks_needed": [
            "en": "No new tasks needed.",
            "hi": "नए tasks की ज़रूरत नहीं।",
            "bn": "নতুন tasks দরকার নেই।",
            "ta": "புதிய tasks தேவையில்லை.",
            "te": "కొత్త tasks అవసరం లేదు."
        ],
        "tasks_added_title": [
            "en": "Tasks added.",
            "hi": "Tasks added.",
            "bn": "Tasks added.",
            "ta": "Tasks added.",
            "te": "Tasks added."
        ],
        "ask_follow_up_tasks_already_saved": [
            "en": "The likely follow-up tasks were already saved for this matter.",
            "hi": "संभावित follow-up tasks इस matter के लिए पहले से saved हैं।",
            "bn": "সম্ভাব্য follow-up tasks এই matter-এর জন্য আগেই saved আছে।",
            "ta": "சாத்தியமான follow-up tasks இந்த matter-க்கு ஏற்கனவே saved உள்ளன.",
            "te": "సంభావ్య follow-up tasks ఈ matter కోసం ఇప్పటికే saved ఉన్నాయి."
        ],
        "ask_tasks_added_from_document": [
            "en": "%d task(s) were added from %@.",
            "hi": "%d task(s) %@ से added हुए।",
            "bn": "%d task(s) %@ থেকে added হয়েছে।",
            "ta": "%d task(s) %@ இலிருந்து added ஆனது.",
            "te": "%d task(s) %@ నుండి added అయ్యాయి."
        ],
        "ask_open_tasks_to_adjust": [
            "en": "Open Tasks to adjust dates or mark anything done.",
            "hi": "dates adjust करने या कुछ done mark करने के लिए Tasks खोलें।",
            "bn": "dates adjust করতে বা কিছু done mark করতে Tasks খুলুন।",
            "ta": "dates adjust செய்ய அல்லது எதையும் done mark செய்ய Tasks திறக்கவும்.",
            "te": "dates adjust చేయడానికి లేదా ఏదైనా done mark చేయడానికి Tasks తెరవండి."
        ],
        "ask_routine_prepared_title": [
            "en": "%@ prepared",
            "hi": "%@ prepared",
            "bn": "%@ prepared",
            "ta": "%@ prepared",
            "te": "%@ prepared"
        ],
        "ask_public_law_preview_prepared": [
            "en": "Ross prepared a sanitized public-law query preview. No web search has run.",
            "hi": "Ross ने sanitized public-law query preview तैयार किया। अभी web search नहीं चला।",
            "bn": "Ross sanitized public-law query preview তৈরি করেছে। এখনও web search চলেনি।",
            "ta": "Ross sanitized public-law query preview தயாரித்தது. இன்னும் web search இயங்கவில்லை.",
            "te": "Ross sanitized public-law query preview సిద్ధం చేసింది. ఇంకా web search జరగలేదు."
        ],
        "ask_local_matter_state_reviewed": [
            "en": "Ross reviewed saved local matter state and updated prepared work.",
            "hi": "Ross ने saved local matter state review की और prepared work update किया।",
            "bn": "Ross saved local matter state review করে prepared work update করেছে।",
            "ta": "Ross saved local matter state review செய்து prepared work update செய்தது.",
            "te": "Ross saved local matter state review చేసి prepared work update చేసింది."
        ],
        "ask_no_items_need_attention": [
            "en": "No items need advocate attention right now.",
            "hi": "अभी कोई item advocate attention नहीं चाहता।",
            "bn": "এখন কোনো item advocate attention চায় না।",
            "ta": "இப்போது எந்த item-க்கும் advocate attention தேவையில்லை.",
            "te": "ప్రస్తుతం ఏ item కు advocate attention అవసరం లేదు."
        ],
        "ask_prepared_items_need_attention": [
            "en": "%d item(s) need advocate attention.",
            "hi": "%d item(s) advocate attention चाहते हैं।",
            "bn": "%d item(s) advocate attention চায়।",
            "ta": "%d item(s)-க்கு advocate attention தேவை.",
            "te": "%d item(s) కు advocate attention అవసరం."
        ],
        "selected_file_still_being_read": [
            "en": "Selected file is still being read",
            "hi": "Selected file अभी पढ़ी जा रही है",
            "bn": "Selected file এখনও পড়া হচ্ছে",
            "ta": "Selected file இன்னும் படிக்கப்படுகிறது",
            "te": "Selected file ఇంకా చదువుతోంది"
        ],
        "ask_still_reading_file_title": [
            "en": "Ross is still reading this file",
            "hi": "Ross अभी यह file पढ़ रहा है",
            "bn": "Ross এখনও এই file পড়ছে",
            "ta": "Ross இன்னும் இந்த file படிக்கிறது",
            "te": "Ross ఇంకా ఈ file చదువుతోంది"
        ],
        "ask_still_reading_files_title": [
            "en": "Ross is still reading these files",
            "hi": "Ross अभी ये files पढ़ रहा है",
            "bn": "Ross এখনও এই files পড়ছে",
            "ta": "Ross இன்னும் இந்த files படிக்கிறது",
            "te": "Ross ఇంకా ఈ files చదువుతోంది"
        ],
        "ask_still_reading_file_detail": [
            "en": "Ross is still reading %@. Ask again after extraction finishes.",
            "hi": "Ross अभी %@ पढ़ रहा है। extraction finish होने के बाद फिर पूछें।",
            "bn": "Ross এখনও %@ পড়ছে। extraction শেষ হলে আবার জিজ্ঞাসা করুন।",
            "ta": "Ross இன்னும் %@ படிக்கிறது. extraction முடிந்த பிறகு மீண்டும் கேளுங்கள்.",
            "te": "Ross ఇంకా %@ చదువుతోంది. extraction పూర్తయ్యాక మళ్లీ అడగండి."
        ],
        "ask_still_reading_files_detail": [
            "en": "Ross is still reading %@. Ask again after extraction finishes for the tagged files.",
            "hi": "Ross अभी %@ पढ़ रहा है। tagged files की extraction finish होने के बाद फिर पूछें।",
            "bn": "Ross এখনও %@ পড়ছে। tagged files-এর extraction শেষ হলে আবার জিজ্ঞাসা করুন।",
            "ta": "Ross இன்னும் %@ படிக்கிறது. tagged files extraction முடிந்த பிறகு மீண்டும் கேளுங்கள்.",
            "te": "Ross ఇంకా %@ చదువుతోంది. tagged files extraction పూర్తయ్యాక మళ్లీ అడగండి."
        ],
        "ask_wait_file_ready_detail": [
            "en": "Ross will wait until this file is ready instead of guessing from text that is not ready yet.",
            "hi": "Text ready नहीं है, इसलिए Ross guess करने के बजाय इस file के ready होने का इंतज़ार करेगा।",
            "bn": "Text ready নয়, তাই Ross guess না করে এই file ready হওয়ার অপেক্ষা করবে।",
            "ta": "Text ready இல்லை; அதனால் Ross guess செய்யாமல் இந்த file ready ஆகும் வரை காத்திருக்கும்.",
            "te": "Text ready కాదు; అందుకే Ross guess చేయకుండా ఈ file ready అయ్యే వరకు వేచి ఉంటుంది."
        ],
        "ask_wait_files_ready_detail": [
            "en": "Ross will wait until the selected files are ready instead of guessing from text that is not ready yet.",
            "hi": "Text ready नहीं है, इसलिए Ross guess करने के बजाय selected files के ready होने का इंतज़ार करेगा।",
            "bn": "Text ready নয়, তাই Ross guess না করে selected files ready হওয়ার অপেক্ষা করবে।",
            "ta": "Text ready இல்லை; அதனால் Ross guess செய்யாமல் selected files ready ஆகும் வரை காத்திருக்கும்.",
            "te": "Text ready కాదు; అందుకే Ross guess చేయకుండా selected files ready అయ్యే వరకు వేచి ఉంటుంది."
        ],
        "ask_still_reading_summary_detail": [
            "en": "Ross is still reading %@. You can ask about extracted pages after it finishes reading.",
            "hi": "Ross अभी %@ पढ़ रहा है। पढ़ना finish होने के बाद extracted pages के बारे में पूछ सकते हैं।",
            "bn": "Ross এখনও %@ পড়ছে। পড়া শেষ হলে extracted pages সম্পর্কে জিজ্ঞাসা করতে পারেন।",
            "ta": "Ross இன்னும் %@ படிக்கிறது. வாசிப்பு முடிந்த பிறகு extracted pages பற்றி கேட்கலாம்.",
            "te": "Ross ఇంకా %@ చదువుతోంది. చదవడం పూర్తయ్యాక extracted pages గురించి అడగవచ్చు."
        ],
        "ross_extracting_tagged_file_text": [
            "en": "Ross is still extracting readable text from the tagged file.",
            "hi": "Ross tagged file से readable text अभी extract कर रहा है।",
            "bn": "Ross tagged file থেকে readable text এখনও extract করছে।",
            "ta": "Ross tagged file-இலிருந்து readable text இன்னும் extract செய்கிறது.",
            "te": "Ross tagged file నుండి readable text ఇంకా extract చేస్తోంది."
        ],
        "ask_after_file_ready_or_choose_different": [
            "en": "Ask again after the file shows as ready, or choose a different readable file.",
            "hi": "file ready दिखने के बाद फिर पूछें, या कोई दूसरी readable file चुनें।",
            "bn": "file ready দেখানোর পরে আবার জিজ্ঞাসা করুন, বা অন্য readable file বেছে নিন।",
            "ta": "file ready என காட்டிய பிறகு மீண்டும் கேளுங்கள், அல்லது வேறு readable file தேர்வுசெய்யவும்.",
            "te": "file ready గా కనిపించిన తర్వాత మళ్లీ అడగండి, లేదా వేరే readable file ఎంచుకోండి."
        ],
        "file_text_not_ready": [
            "en": "File text not ready",
            "hi": "File text ready नहीं",
            "bn": "File text ready নয়",
            "ta": "File text ready இல்லை",
            "te": "File text ready కాదు"
        ],
        "tagged_file_not_ready_for_assistant": [
            "en": "Tagged file not ready for private assistant.",
            "hi": "Tagged file private assistant के लिए ready नहीं है।",
            "bn": "Tagged file private assistant-এর জন্য ready নয়।",
            "ta": "Tagged file private assistant-க்கு ready இல்லை.",
            "te": "Tagged file private assistant కోసం ready కాదు."
        ],
        "selected_file_no_readable_text": [
            "en": "Selected file has no readable text",
            "hi": "Selected file में readable text नहीं है",
            "bn": "Selected file-এ readable text নেই",
            "ta": "Selected file-ல் readable text இல்லை",
            "te": "Selected file లో readable text లేదు"
        ],
        "ross_could_not_find_tagged_file_text": [
            "en": "Ross could not find readable source text in the tagged file.",
            "hi": "Ross को tagged file में readable source text नहीं मिला।",
            "bn": "Ross tagged file-এ readable source text খুঁজে পায়নি।",
            "ta": "Ross tagged file-ல் readable source text கண்டுபிடிக்கவில்லை.",
            "te": "Ross tagged file లో readable source text కనుగొనలేదు."
        ],
        "reimport_wait_or_choose_another_file": [
            "en": "Re-import the file, wait for text extraction to finish, or choose another file before asking the private assistant.",
            "hi": "private assistant से पूछने से पहले file फिर import करें, text extraction finish होने दें, या दूसरी file चुनें।",
            "bn": "private assistant-কে জিজ্ঞাসা করার আগে file আবার import করুন, text extraction শেষ হতে দিন, বা অন্য file বেছে নিন।",
            "ta": "private assistant-ஐ கேட்பதற்கு முன் file-ஐ மீண்டும் import செய்யவும், text extraction முடியும் வரை காத்திருக்கவும், அல்லது வேறு file தேர்வுசெய்யவும்.",
            "te": "private assistant ను అడగడానికి ముందు file ను మళ్లీ import చేయండి, text extraction పూర్తయ్యే వరకు వేచి ఉండండి, లేదా వేరే file ఎంచుకోండి."
        ],
        "file_text_unavailable": [
            "en": "File text unavailable",
            "hi": "File text उपलब्ध नहीं",
            "bn": "File text পাওয়া যাচ্ছে না",
            "ta": "File text கிடைக்கவில்லை",
            "te": "File text అందుబాటులో లేదు"
        ],
        "tagged_file_no_readable_source_text": [
            "en": "Tagged file has no readable source text.",
            "hi": "Tagged file में readable source text नहीं है।",
            "bn": "Tagged file-এ readable source text নেই।",
            "ta": "Tagged file-ல் readable source text இல்லை.",
            "te": "Tagged file లో readable source text లేదు."
        ],
        "ask_legal_search_clean_query_detail": [
            "en": "Ross will use Legal Search with a cleaned query. Your case files stay on this device.",
            "hi": "Ross cleaned query के साथ Legal Search use करेगा। आपकी case files इस device पर रहती हैं।",
            "bn": "Ross cleaned query দিয়ে Legal Search ব্যবহার করবে। আপনার case files এই device-এই থাকবে।",
            "ta": "Ross cleaned query உடன் Legal Search பயன்படுத்தும். உங்கள் case files இந்த device-இலேயே இருக்கும்.",
            "te": "Ross cleaned query తో Legal Search ఉపయోగిస్తుంది. మీ case files ఈ device లోనే ఉంటాయి."
        ],
        "legal_search": [
            "en": "Legal Search",
            "hi": "Legal Search",
            "bn": "Legal Search",
            "ta": "Legal Search",
            "te": "Legal Search"
        ],
        "what_ross_searched": [
            "en": "What Ross searched",
            "hi": "Ross ने क्या search किया",
            "bn": "Ross কী search করেছে",
            "ta": "Ross search செய்தது",
            "te": "Ross search చేసినది"
        ],
        "awaiting_review_no_web_search": [
            "en": "Awaiting your review. No web search used yet.",
            "hi": "आपके review का इंतज़ार है। अभी web search use नहीं हुआ।",
            "bn": "আপনার review-এর অপেক্ষায়। এখনও web search ব্যবহার হয়নি।",
            "ta": "உங்கள் review காத்திருக்கிறது. இன்னும் web search பயன்படுத்தப்படவில்லை.",
            "te": "మీ review కోసం వేచి ఉంది. ఇంకా web search ఉపయోగించలేదు."
        ],
        "ross_removed_case_details_before_searching": [
            "en": "Ross removed case details before searching.",
            "hi": "search करने से पहले Ross ने case details हटा दिए।",
            "bn": "search করার আগে Ross case details সরিয়েছে।",
            "ta": "search செய்வதற்கு முன் Ross case details நீக்கியது.",
            "te": "search చేయడానికి ముందు Ross case details తొలగించింది."
        ],
        "from_legal_search": [
            "en": "From Legal Search",
            "hi": "Legal Search से",
            "bn": "Legal Search থেকে",
            "ta": "Legal Search-இலிருந்து",
            "te": "Legal Search నుండి"
        ],
        "from_legal_search_detail": [
            "en": "Separate from your case files. Based on a cleaned search query.",
            "hi": "आपकी case files से अलग। cleaned search query पर based।",
            "bn": "আপনার case files থেকে আলাদা। cleaned search query-এর ভিত্তিতে।",
            "ta": "உங்கள் case files-இலிருந்து தனி. cleaned search query அடிப்படையில்.",
            "te": "మీ case files నుండి వేరు. cleaned search query ఆధారంగా."
        ],
        "ross_scope_all": [
            "en": "Ross",
            "hi": "Ross",
            "bn": "Ross",
            "ta": "Ross",
            "te": "Ross"
        ],
        "ross_general_scope": [
            "en": "Ross (General)",
            "hi": "Ross (General)",
            "bn": "Ross (General)",
            "ta": "Ross (General)",
            "te": "Ross (General)"
        ],
        "review_legal_search": [
            "en": "Review Legal Search",
            "hi": "Legal Search review करें",
            "bn": "Legal Search review করুন",
            "ta": "Legal Search review செய்யவும்",
            "te": "Legal Search review చేయండి"
        ],
        "review_legal_search_detail": [
            "en": "Ross will search using only the query below. Your case files, party names, and private details stay on this device.",
            "hi": "Ross सिर्फ नीचे दी query से search करेगा। आपकी case files, party names और private details इस device पर रहती हैं।",
            "bn": "Ross শুধু নিচের query দিয়ে search করবে। আপনার case files, party names, এবং private details এই device-এই থাকবে।",
            "ta": "Ross கீழே உள்ள query-ஐ மட்டும் பயன்படுத்தி search செய்யும். உங்கள் case files, party names மற்றும் private details இந்த device-இலேயே இருக்கும்.",
            "te": "Ross కింద ఉన్న query తో మాత్రమే search చేస్తుంది. మీ case files, party names మరియు private details ఈ device లోనే ఉంటాయి."
        ],
        "query_to_be_sent": [
            "en": "Query to be sent",
            "hi": "भेजी जाने वाली query",
            "bn": "যে query পাঠানো হবে",
            "ta": "அனுப்பப்படும் query",
            "te": "పంపబడే query"
        ],
        "zero_private_case_details_sent": [
            "en": "0 private case details sent",
            "hi": "0 private case details भेजे गए",
            "bn": "0 private case details পাঠানো হয়েছে",
            "ta": "0 private case details அனுப்பப்பட்டன",
            "te": "0 private case details పంపబడ్డాయి"
        ],
        "private_details_removed_zero_sent": [
            "en": "%d private details removed · 0 sent",
            "hi": "%d private details हटाए गए · 0 भेजे गए",
            "bn": "%d private details সরানো হয়েছে · 0 পাঠানো হয়েছে",
            "ta": "%d private details நீக்கப்பட்டன · 0 அனுப்பப்பட்டது",
            "te": "%d private details తొలగించబడ్డాయి · 0 పంపబడ్డాయి"
        ],
        "searching_legal_sources_ellipsis": [
            "en": "Searching legal sources...",
            "hi": "legal sources search हो रहे हैं...",
            "bn": "legal sources search হচ্ছে...",
            "ta": "legal sources search ஆகின்றன...",
            "te": "legal sources search అవుతున్నాయి..."
        ],
        "send": [
            "en": "Send",
            "hi": "भेजें",
            "bn": "পাঠান",
            "ta": "அனுப்பவும்",
            "te": "పంపండి"
        ],
        "type_at_to_add_file": [
            "en": "Type @ to add a file.",
            "hi": "file जोड़ने के लिए @ type करें।",
            "bn": "file যোগ করতে @ type করুন।",
            "ta": "file சேர்க்க @ type செய்யவும்.",
            "te": "file జోడించడానికి @ type చేయండి."
        ],
        "done": [
            "en": "Done",
            "hi": "हो गया",
            "bn": "হয়ে গেছে",
            "ta": "முடிந்தது",
            "te": "పూర్తయింది"
        ],
        "all_work": [
            "en": "All work",
            "hi": "सारा काम",
            "bn": "সব কাজ",
            "ta": "அனைத்து வேலை",
            "te": "అన్ని పని"
        ],
        "legal_search_on": [
            "en": "Legal Search on",
            "hi": "Legal Search on",
            "bn": "Legal Search on",
            "ta": "Legal Search on",
            "te": "Legal Search on"
        ],
        "local_only": [
            "en": "Local only",
            "hi": "सिर्फ local",
            "bn": "শুধু local",
            "ta": "local மட்டும்",
            "te": "local మాత్రమే"
        ],
        "legal_search_sanitized_query_detail": [
            "en": "Legal Search only uses a sanitized legal query. Case files and document text stay on-device.",
            "hi": "Legal Search सिर्फ sanitized legal query use करता है। Case files और document text on-device रहते हैं।",
            "bn": "Legal Search শুধু sanitized legal query ব্যবহার করে। Case files এবং document text on-device থাকে।",
            "ta": "Legal Search sanitized legal query மட்டும் பயன்படுத்தும். Case files மற்றும் document text on-device இருக்கும்.",
            "te": "Legal Search sanitized legal query మాత్రమే ఉపయోగిస్తుంది. Case files మరియు document text on-device ఉంటాయి."
        ],
        "ask_tools_detail": [
            "en": "Choose scope, add a file, or turn on Legal Search.",
            "hi": "scope चुनें, file जोड़ें, या Legal Search on करें।",
            "bn": "scope বেছে নিন, file যোগ করুন, বা Legal Search on করুন।",
            "ta": "scope தேர்வுசெய்க, file சேர்க்கவும் அல்லது Legal Search on செய்யவும்.",
            "te": "scope ఎంచుకోండి, file జోడించండి, లేదా Legal Search on చేయండి."
        ],
        "close_ask_ross_tools": [
            "en": "Close Ask Ross tools",
            "hi": "Ask Ross tools बंद करें",
            "bn": "Ask Ross tools বন্ধ করুন",
            "ta": "Ask Ross tools மூடவும்",
            "te": "Ask Ross tools మూసివేయండి"
        ],
        "add_file": [
            "en": "Add file",
            "hi": "File जोड़ें",
            "bn": "File যোগ করুন",
            "ta": "File சேர்க்கவும்",
            "te": "File జోడించండి"
        ],
        "add_file_shared_detail": [
            "en": "Add a PDF or note to shared files.",
            "hi": "shared files में PDF या note जोड़ें।",
            "bn": "shared files-এ PDF বা note যোগ করুন।",
            "ta": "shared files-இல் PDF அல்லது note சேர்க்கவும்.",
            "te": "shared files కు PDF లేదా note జోడించండి."
        ],
        "add_file_matter_detail": [
            "en": "Add a PDF or note to this matter.",
            "hi": "इस matter में PDF या note जोड़ें।",
            "bn": "এই matter-এ PDF বা note যোগ করুন।",
            "ta": "இந்த matter-க்கு PDF அல்லது note சேர்க்கவும்.",
            "te": "ఈ matter కు PDF లేదా note జోడించండి."
        ],
        "add_image": [
            "en": "Add image",
            "hi": "Image जोड़ें",
            "bn": "Image যোগ করুন",
            "ta": "Image சேர்க்கவும்",
            "te": "Image జోడించండి"
        ],
        "add_image_shared_detail": [
            "en": "Add a photo, scan, or screenshot to shared files.",
            "hi": "shared files में photo, scan, या screenshot जोड़ें।",
            "bn": "shared files-এ photo, scan, বা screenshot যোগ করুন।",
            "ta": "shared files-இல் photo, scan அல்லது screenshot சேர்க்கவும்.",
            "te": "shared files కు photo, scan, లేదా screenshot జోడించండి."
        ],
        "add_image_matter_detail": [
            "en": "Add a photo, scan, or screenshot to this matter.",
            "hi": "इस matter में photo, scan, या screenshot जोड़ें।",
            "bn": "এই matter-এ photo, scan, বা screenshot যোগ করুন।",
            "ta": "இந்த matter-க்கு photo, scan அல்லது screenshot சேர்க்கவும்.",
            "te": "ఈ matter కు photo, scan, లేదా screenshot జోడించండి."
        ],
        "legal_search_on_detail": [
            "en": "On. Ross only sends a sanitized legal query.",
            "hi": "On. Ross सिर्फ sanitized legal query भेजता है।",
            "bn": "On. Ross শুধু sanitized legal query পাঠায়।",
            "ta": "On. Ross sanitized legal query மட்டும் அனுப்பும்.",
            "te": "On. Ross sanitized legal query మాత్రమే పంపుతుంది."
        ],
        "legal_search_off_detail": [
            "en": "Off. Ross stays fully local until you turn it on.",
            "hi": "Off. On करने तक Ross पूरी तरह local रहता है।",
            "bn": "Off. আপনি on না করা পর্যন্ত Ross পুরোপুরি local থাকে।",
            "ta": "Off. நீங்கள் on செய்யும் வரை Ross முழுவதும் local-ஆக இருக்கும்.",
            "te": "Off. మీరు on చేసే వరకు Ross పూర్తిగా local గా ఉంటుంది."
        ],
        "on": [
            "en": "On",
            "hi": "On",
            "bn": "On",
            "ta": "On",
            "te": "On"
        ],
        "off": [
            "en": "Off",
            "hi": "Off",
            "bn": "Off",
            "ta": "Off",
            "te": "Off"
        ],
        "ask_activity_log_detail": [
            "en": "See what stayed local and what, if anything, left the device.",
            "hi": "देखें क्या local रहा और क्या, अगर कुछ, device से बाहर गया।",
            "bn": "দেখুন কী local ছিল এবং কিছু গেলে device থেকে কী বেরিয়েছে।",
            "ta": "எது local-ஆக இருந்தது, ஏதாவது device-ஐ விட்டுச் சென்றதா என்பதைப் பார்க்கவும்.",
            "te": "ఏది local గా ఉండింది, ఏదైనా device బయటకు వెళ్లిందా చూడండి."
        ],
        "this_space": [
            "en": "This space",
            "hi": "यह space",
            "bn": "এই space",
            "ta": "இந்த space",
            "te": "ఈ space"
        ],
        "this_matter": [
            "en": "This matter",
            "hi": "यह matter",
            "bn": "এই matter",
            "ta": "இந்த matter",
            "te": "ఈ matter"
        ],
        "ask_in": [
            "en": "Ask in",
            "hi": "इसमें पूछें",
            "bn": "এখানে জিজ্ঞাসা করুন",
            "ta": "இதில் கேளுங்கள்",
            "te": "ఇందులో అడగండి"
        ],
        "use_uploaded_files": [
            "en": "Use uploaded files",
            "hi": "uploaded files use करें",
            "bn": "uploaded files ব্যবহার করুন",
            "ta": "uploaded files பயன்படுத்தவும்",
            "te": "uploaded files ఉపయోగించండి"
        ],
        "shared_file": [
            "en": "Shared file",
            "hi": "Shared file",
            "bn": "Shared file",
            "ta": "Shared file",
            "te": "Shared file"
        ],
        "ask_empty_files_shared_detail": [
            "en": "Add a PDF, note, photo, or scan. Ross will read it locally before using it in Ask.",
            "hi": "PDF, note, photo, या scan जोड़ें। Ask में use करने से पहले Ross इसे locally पढ़ेगा।",
            "bn": "PDF, note, photo, বা scan যোগ করুন। Ask-এ ব্যবহারের আগে Ross এটি locally পড়বে।",
            "ta": "PDF, note, photo அல்லது scan சேர்க்கவும். Ask-இல் பயன்படுத்துவதற்கு முன் Ross அதை locally படிக்கும்.",
            "te": "PDF, note, photo, లేదా scan జోడించండి. Ask లో ఉపయోగించే ముందు Ross దాన్ని locally చదువుతుంది."
        ],
        "ask_empty_files_matter_detail": [
            "en": "Add a PDF, note, photo, or scan to this matter. Ross will read it locally before using it in Ask.",
            "hi": "इस matter में PDF, note, photo, या scan जोड़ें। Ask में use करने से पहले Ross इसे locally पढ़ेगा।",
            "bn": "এই matter-এ PDF, note, photo, বা scan যোগ করুন। Ask-এ ব্যবহারের আগে Ross এটি locally পড়বে।",
            "ta": "இந்த matter-க்கு PDF, note, photo அல்லது scan சேர்க்கவும். Ask-இல் பயன்படுத்துவதற்கு முன் Ross அதை locally படிக்கும்.",
            "te": "ఈ matter కు PDF, note, photo, లేదా scan జోడించండి. Ask లో ఉపయోగించే ముందు Ross దాన్ని locally చదువుతుంది."
        ],
        "no_ready_files_yet": [
            "en": "No ready files yet",
            "hi": "अभी ready files नहीं",
            "bn": "এখনও ready files নেই",
            "ta": "இன்னும் ready files இல்லை",
            "te": "ఇంకా ready files లేవు"
        ],
        "ask_scoped_to_this_matter": [
            "en": "Ask Ross is scoped to this matter.",
            "hi": "Ask Ross इसी matter तक scoped है।",
            "bn": "Ask Ross এই matter-এ scoped.",
            "ta": "Ask Ross இந்த matter-க்கு scoped ஆக உள்ளது.",
            "te": "Ask Ross ఈ matter కు scoped గా ఉంది."
        ],
        "add_to_ask_ross": [
            "en": "Add to Ask Ross",
            "hi": "Ask Ross में जोड़ें",
            "bn": "Ask Ross-এ যোগ করুন",
            "ta": "Ask Ross-இல் சேர்க்கவும்",
            "te": "Ask Ross కు జోడించండి"
        ],
        "clear_ask_ross_text": [
            "en": "Clear Ask Ross text",
            "hi": "Ask Ross text साफ़ करें",
            "bn": "Ask Ross text পরিষ্কার করুন",
            "ta": "Ask Ross text அழிக்கவும்",
            "te": "Ask Ross text క్లియర్ చేయండి"
        ],
        "view_full_answer": [
            "en": "View full answer",
            "hi": "पूरा answer देखें",
            "bn": "পুরো answer দেখুন",
            "ta": "முழு answer பார்க்கவும்",
            "te": "పూర్తి answer చూడండి"
        ],
        "remove_ask_selection": [
            "en": "Remove %@",
            "hi": "%@ हटाएं",
            "bn": "%@ সরান",
            "ta": "%@ நீக்கவும்",
            "te": "%@ తొలగించండి"
        ],
        "ask_empty_title": [
            "en": "Ask Ross what's next",
            "hi": "Ross से आगे का काम पूछें",
            "bn": "এরপর কী করবেন Ross-কে জিজ্ঞাসা করুন",
            "ta": "அடுத்து என்ன என்பதை Ross-ஐ கேளுங்கள்",
            "te": "తర్వాత ఏమిటో Ross‌ను అడగండి"
        ],
        "ask_empty_detail_general": [
            "en": "Ask from your matters, tag a file with @, or tap + to import a PDF, image, or text file.",
            "hi": "अपने मामलों से पूछें, @ से फ़ाइल टैग करें, या PDF, इमेज, या टेक्स्ट फ़ाइल आयात करने के लिए + टैप करें।",
            "bn": "আপনার মামলাগুলি থেকে জিজ্ঞাসা করুন, @ দিয়ে ফাইল ট্যাগ করুন, অথবা PDF, ছবি, বা টেক্সট ফাইল আমদানি করতে + চাপুন।",
            "ta": "உங்கள் வழக்குகளில் இருந்து கேளுங்கள், @ மூலம் கோப்பை குறிக்கவும், அல்லது PDF, படம், உரை கோப்பை இறக்குமதி செய்ய + தட்டவும்.",
            "te": "మీ కేసుల నుంచి అడగండి, @తో ఫైల్‌ను ట్యాగ్ చేయండి, లేదా PDF, చిత్రం, లేదా టెక్స్ట్ ఫైల్‌ను దిగుమతి చేయడానికి + నొక్కండి."
        ],
        "ask_empty_detail_matter": [
            "en": "Ask about %@, tag a file with @, or tap + to import a PDF, image, or text file.",
            "hi": "%@ के बारे में पूछें, @ से फ़ाइल टैग करें, या PDF, इमेज, या टेक्स्ट फ़ाइल आयात करने के लिए + टैप करें।",
            "bn": "%@ সম্পর্কে জিজ্ঞাসা করুন, @ দিয়ে ফাইল ট্যাগ করুন, অথবা PDF, ছবি, বা টেক্সট ফাইল আমদানি করতে + চাপুন।",
            "ta": "%@ பற்றி கேளுங்கள், @ மூலம் கோப்பை குறிக்கவும், அல்லது PDF, படம், உரை கோப்பை இறக்குமதி செய்ய + தட்டவும்.",
            "te": "%@ గురించి అడగండి, @తో ఫైల్‌ను ట్యాగ్ చేయండి, లేదా PDF, చిత్రం, లేదా టెక్స్ట్ ఫైల్‌ను దిగుమతి చేయడానికి + నొక్కండి."
        ],
        "ask_empty_detail_selected_files": [
            "en": "%d tagged file(s) ready. Ask a question, or tap + to add another PDF, image, or text file.",
            "hi": "%d टैग की गई फ़ाइल तैयार है। सवाल पूछें, या दूसरी PDF, इमेज, या टेक्स्ट फ़ाइल जोड़ने के लिए + टैप करें।",
            "bn": "%dটি ট্যাগ করা ফাইল প্রস্তুত। প্রশ্ন করুন, অথবা আরেকটি PDF, ছবি, বা টেক্সট ফাইল যোগ করতে + চাপুন।",
            "ta": "%d குறியிட்ட கோப்பு தயார். கேள்வி கேளுங்கள், அல்லது மற்றொரு PDF, படம், உரை கோப்பை சேர்க்க + தட்டவும்.",
            "te": "%d ట్యాగ్ చేసిన ఫైల్ సిద్ధంగా ఉంది. ప్రశ్న అడగండి, లేదా మరో PDF, చిత్రం, లేదా టెక్స్ట్ ఫైల్ జోడించడానికి + నొక్కండి."
        ],
        "ask_conversation_placeholder": [
            "en": "Ask Ross... Type @ to tag a file",
            "hi": "Ross से पूछें... फ़ाइल टैग करने के लिए @ लिखें",
            "bn": "Ross-কে জিজ্ঞাসা করুন... ফাইল ট্যাগ করতে @ লিখুন",
            "ta": "Ross-ஐ கேளுங்கள்... கோப்பை குறிக்க @ தட்டச்சு செய்யவும்",
            "te": "Ross‌ను అడగండి... ఫైల్‌ను ట్యాగ్ చేయడానికి @ టైప్ చేయండి"
        ],
        "ask_tag_file_hint": [
            "en": "Tag files with @ or tap + to attach them before asking.",
            "hi": "पूछने से पहले @ से फ़ाइल टैग करें या + टैप करके जोड़ें।",
            "bn": "জিজ্ঞাসা করার আগে @ দিয়ে ফাইল ট্যাগ করুন বা + ট্যাপ করে যুক্ত করুন।",
            "ta": "கேட்பதற்கு முன் @ மூலம் கோப்புகளை குறிக்கவும் அல்லது + தட்டி இணைக்கவும்.",
            "te": "అడగడానికి ముందు @తో ఫైళ్లను ట్యాగ్ చేయండి లేదా + నొక్కి జోడించండి."
        ],
        "ask_workflow_tag_file": [
            "en": "Tag file",
            "hi": "फ़ाइल टैग करें",
            "bn": "ফাইল ট্যাগ করুন",
            "ta": "கோப்பை குறிக்கவும்",
            "te": "ఫైల్ ట్యాగ్ చేయండి"
        ],
        "ask_workflow_import": [
            "en": "Import",
            "hi": "आयात करें",
            "bn": "আমদানি করুন",
            "ta": "இறக்குமதி",
            "te": "దిగుమతి"
        ],
        "ask_workflow_ask": [
            "en": "Ask",
            "hi": "पूछें",
            "bn": "জিজ্ঞাসা করুন",
            "ta": "கேளுங்கள்",
            "te": "అడగండి"
        ]
    ]
    return table[key]?[normalizedCode] ?? table[key]?["en"] ?? key
}

func rossQuickUnlockEnabled() -> Bool {
    UserDefaults.standard.bool(forKey: rossQuickUnlockEnabledKey)
}

func rossSetQuickUnlockEnabled(_ enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: rossQuickUnlockEnabledKey)
}

func rossBackendBaseURLOverride() -> String? {
    let normalized = UserDefaults.standard.string(forKey: rossBackendBaseURLOverrideKey)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return (normalized?.isEmpty == false) ? normalized : nil
}

func rossSetBackendBaseURLOverride(_ rawValue: String?) {
    guard let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !normalized.isEmpty else {
        UserDefaults.standard.removeObject(forKey: rossBackendBaseURLOverrideKey)
        return
    }
    UserDefaults.standard.set(normalized, forKey: rossBackendBaseURLOverrideKey)
}

private func rossAuthTopHeaderPadding(_ safeAreaTop: CGFloat) -> CGFloat {
    max(safeAreaTop - 14, 14)
}

private enum RossEmailAccessWorkspace: Equatable {
    case demo
    case fresh
}

private struct RossEmailAccessProfile: Identifiable {
    var id: String { email }
    let email: String
    let displayName: String
    let subject: String
    let title: String
    let detail: String
    let workspace: RossEmailAccessWorkspace
}

private let rossEmailAccessProfiles: [RossEmailAccessProfile] = [
    RossEmailAccessProfile(
        email: "advocate@ross.ai",
        displayName: "Advocate Ross",
        subject: "local_demo_advocate",
        title: "Try sample matter",
        detail: "Opens one sample case.",
        workspace: .demo
    ),
    RossEmailAccessProfile(
        email: "fresh@ross.ai",
        displayName: "Fresh Ross Account",
        subject: "local_fresh_default",
        title: "Start empty",
        detail: "Creates a clean workspace.",
        workspace: .fresh
    )
]

private func rossEmailAccessProfile(for email: String) -> RossEmailAccessProfile? {
    let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return rossEmailAccessProfiles.first { $0.email == normalized }
}

func rossBackendBaseURL() -> URL {
    let environment = ProcessInfo.processInfo.environment
    let rawURL = rossBackendBaseURLOverride()
        ?? environment["ROSS_BACKEND_BASE_URL"]
        ?? environment["ROSS_BACKEND_URL"]
        ?? "http://127.0.0.1:8080"
    return URL(string: rawURL) ?? URL(string: "http://127.0.0.1:8080")!
}

func rossMobileAuthRedirectURL() -> URL {
    let environment = ProcessInfo.processInfo.environment
    let rawURL = environment["ROSS_AUTH_MOBILE_REDIRECT"] ?? "ross://auth/callback"
    return URL(string: rawURL) ?? URL(string: "ross://auth/callback")!
}

struct RossAuthSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accountToken: String
    let email: String
    let displayName: String?
    let subject: String
    let expiresAt: Date

    var displayLabel: String {
        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? email : trimmedName
    }
}

enum RossAuthPhase: Equatable {
    case loading
    case signedOut
    case unlockRequired(RossAuthSession)
    case signedIn(RossAuthSession)
}

fileprivate enum RossExternalSignInProvider: Equatable {
    case google
    case apple
}

private enum RossUnlockTrigger {
    case automatic
    case manual
}

final class RossAuthSessionSnapshot: @unchecked Sendable {
    static let shared = RossAuthSessionSnapshot()

    private let lock = NSLock()
    private var cachedSession: RossAuthSession?

    private init() {}

    func update(_ session: RossAuthSession?) {
        lock.lock()
        cachedSession = session
        lock.unlock()
    }

    func accountToken(fallback: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        return cachedSession?.accountToken ?? fallback
    }

    func accessToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return cachedSession?.accessToken
    }
}

private final class RossAuthSessionStore {
    private let service = "ross.ios.auth.session"
    private let account = "primary"
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func loadSession() throws -> RossAuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw NSError(domain: "RossAuthSessionStore", code: Int(status), userInfo: nil)
        }

        return try decoder.decode(RossAuthSession.self, from: data)
    }

    func saveSession(_ session: RossAuthSession) throws {
        let data = try encoder.encode(session)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            let addQuery = query.merging(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: "RossAuthSessionStore", code: Int(addStatus), userInfo: nil)
            }
            return
        }

        guard updateStatus == errSecSuccess else {
            throw NSError(domain: "RossAuthSessionStore", code: Int(updateStatus), userInfo: nil)
        }
    }

    func clearSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private struct RossRefreshSessionPayload: Decodable {
    struct Profile: Decodable {
        let email: String?
        let displayName: String?
    }

    let accountToken: String
    let accessToken: String
    let refreshToken: String
    let subject: String
    let expiresAt: Date
    let profile: Profile?

    private enum CodingKeys: String, CodingKey {
        case accountToken
        case accessToken
        case refreshToken
        case subject
        case expiresAt
        case profile
    }
}

@MainActor
@Observable
final class RossAuthController: NSObject, ASWebAuthenticationPresentationContextProviding, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
    @ObservationIgnored private let store = RossAuthSessionStore()
    @ObservationIgnored private var webAuthenticationSession: ASWebAuthenticationSession?
    @ObservationIgnored private var appleAuthorizationController: ASAuthorizationController?
    @ObservationIgnored private let isoFormatter = ISO8601DateFormatter()
    @ObservationIgnored private let canEvaluateDeviceUnlock: () -> Bool
    @ObservationIgnored private let biometryTypeProvider: () -> LABiometryType
    @ObservationIgnored private let evaluateDeviceUnlock: (_ localizedReason: String, _ completion: @escaping @Sendable (Bool, Error?) -> Void) -> Void
    @ObservationIgnored private var pendingQuickRelockSession: RossAuthSession?
    @ObservationIgnored private var pendingAutomaticUnlock = false
    @ObservationIgnored private var didLoad = false

    var phase: RossAuthPhase = .loading
    fileprivate var activeExternalProvider: RossExternalSignInProvider?
    var authErrorMessage: String?
    var hasSelectedLanguage: Bool = rossHasSelectedLanguage()
    var quickUnlockEnabled: Bool = rossQuickUnlockEnabled()
    var privacyShieldVisible = false
    var isUnlocking = false

    override init() {
        self.canEvaluateDeviceUnlock = RossAuthController.defaultCanEvaluateDeviceUnlock
        self.biometryTypeProvider = RossAuthController.defaultBiometryType
        self.evaluateDeviceUnlock = RossAuthController.defaultEvaluateDeviceUnlock
        super.init()
    }

    init(
        canEvaluateDeviceUnlock: @escaping () -> Bool,
        biometryTypeProvider: @escaping () -> LABiometryType,
        evaluateDeviceUnlock: @escaping (_ localizedReason: String, _ completion: @escaping @Sendable (Bool, Error?) -> Void) -> Void
    ) {
        self.canEvaluateDeviceUnlock = canEvaluateDeviceUnlock
        self.biometryTypeProvider = biometryTypeProvider
        self.evaluateDeviceUnlock = evaluateDeviceUnlock
        super.init()
    }

    var isStartingSignIn: Bool {
        activeExternalProvider != nil
    }

    func markLanguageSelected(code: String) {
        rossSaveLanguageSelection(code: code)
        hasSelectedLanguage = true
    }

    var session: RossAuthSession? {
        switch phase {
        case .unlockRequired(let session), .signedIn(let session):
            session
        case .loading, .signedOut:
            nil
        }
    }

    var quickUnlockSummary: String {
        switch currentBiometryType() {
        case .faceID:
            "Face ID or device passcode"
        case .touchID:
            "Touch ID or device passcode"
        default:
            "Device passcode"
        }
    }

    var unlockButtonTitle: String {
        if let biometryLabel = availableBiometryLabel() {
            return "Unlock with \(biometryLabel)"
        }
        return "Unlock"
    }

    var unlockSymbolName: String {
        switch currentBiometryType() {
        case .faceID:
            "faceid"
        case .touchID:
            "touchid"
        default:
            "lock.open.display"
        }
    }

    var canUseQuickUnlock: Bool {
        shouldRequireUnlock()
    }

    private func setSignedIn(_ session: RossAuthSession) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            phase = .signedIn(session)
        }
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true

        do {
            guard let storedSession = try store.loadSession() else {
                RossAuthSessionSnapshot.shared.update(nil)
                phase = .signedOut
                return
            }

            let activeSession = try await refreshedSessionIfNeeded(from: storedSession)
            RossAuthSessionSnapshot.shared.update(activeSession)
            phase = quickUnlockEnabled && shouldRequireUnlock() ? .unlockRequired(activeSession) : .signedIn(activeSession)
            if case .unlockRequired = phase {
                privacyShieldVisible = true
                pendingAutomaticUnlock = true
                attemptAutomaticUnlockIfNeeded()
            } else {
                clearUnlockPresentationState()
            }
        } catch {
            store.clearSession()
            RossAuthSessionSnapshot.shared.update(nil)
            clearUnlockPresentationState()
            phase = .signedOut
            authErrorMessage = nil
        }
    }

    func startGoogleSignIn() {
        guard activeExternalProvider == nil else { return }
        authErrorMessage = nil
        activeExternalProvider = .google

        guard let callbackScheme = rossMobileAuthRedirectURL().scheme else {
            activeExternalProvider = nil
            authErrorMessage = "Could not sign in. Please try again."
            return
        }

        var components = URLComponents(
            url: rossBackendBaseURL().appendingPathComponent("auth/google/start"),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [URLQueryItem(name: "redirectTarget", value: rossMobileAuthRedirectURL().absoluteString)]
        if let email = session?.email {
            queryItems.append(URLQueryItem(name: "loginHint", value: email))
        }
        components?.queryItems = queryItems

        guard let startURL = components?.url else {
            activeExternalProvider = nil
            authErrorMessage = "Could not sign in. Please try again."
            return
        }

        let authenticationSession = ASWebAuthenticationSession(
            url: startURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                self?.finishGoogleSignIn(callbackURL: callbackURL, error: error)
            }
        }
        authenticationSession.prefersEphemeralWebBrowserSession = false
        authenticationSession.presentationContextProvider = self
        webAuthenticationSession = authenticationSession

        if !authenticationSession.start() {
            webAuthenticationSession = nil
            activeExternalProvider = nil
            authErrorMessage = "Could not sign in. Please try again."
        }
    }

    func startAppleSignIn() {
        guard activeExternalProvider == nil else { return }
        authErrorMessage = nil
        activeExternalProvider = .apple

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        appleAuthorizationController = controller
        controller.performRequests()
    }

    func signInWithEmailAccess(_ email: String) {
        authErrorMessage = nil

        guard let profile = rossEmailAccessProfile(for: email) else {
            authErrorMessage = "Use advocate@ross.ai for demo or fresh@ross.ai for a fresh workspace."
            return
        }

        let session = RossAuthSession(
            accessToken: "local_access_\(profile.subject)",
            refreshToken: "local_refresh_\(profile.subject)",
            accountToken: "local_account_\(profile.subject)",
            email: profile.email,
            displayName: profile.displayName,
            subject: profile.subject,
            expiresAt: Date().addingTimeInterval(3600 * 24 * 365)
        )

        try? store.saveSession(session)
        RossAuthSessionSnapshot.shared.update(session)
        clearUnlockPresentationState()
        setSignedIn(session)
    }

    func unlockSession() {
        startUnlock(trigger: .manual)
    }

    func signOut() {
        webAuthenticationSession?.cancel()
        webAuthenticationSession = nil
        appleAuthorizationController = nil
        activeExternalProvider = nil
        store.clearSession()
        RossAuthSessionSnapshot.shared.update(nil)
        clearUnlockPresentationState()
        authErrorMessage = nil
        phase = .signedOut
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            if let pendingQuickRelockSession {
                phase = .unlockRequired(pendingQuickRelockSession)
                self.pendingQuickRelockSession = nil
            }

            if case .unlockRequired = phase {
                privacyShieldVisible = true
                attemptAutomaticUnlockIfNeeded()
            } else {
                privacyShieldVisible = false
            }
        case .inactive:
            guard quickUnlockEnabled, shouldRequireUnlock(), session != nil else { return }
            privacyShieldVisible = true
            authErrorMessage = nil
        case .background:
            guard quickUnlockEnabled, shouldRequireUnlock(), case .signedIn(let session) = phase else { return }
            pendingQuickRelockSession = session
            pendingAutomaticUnlock = true
            privacyShieldVisible = true
            authErrorMessage = nil
        @unknown default:
            break
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        activePresentationAnchor()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        activePresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        defer {
            appleAuthorizationController = nil
            activeExternalProvider = nil
        }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            authErrorMessage = "Could not sign in. Please try again."
            return
        }

        let displayName = PersonNameComponentsFormatter().string(from: credential.fullName ?? PersonNameComponents())
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackAlias = "apple-\(credential.user.prefix(6))@local.ross"

        let session = RossAuthSession(
            accessToken: "apple_local_access_\(credential.user)",
            refreshToken: "apple_local_refresh_\(credential.user)",
            accountToken: "apple_local_account_\(credential.user)",
            email: credential.email ?? fallbackAlias,
            displayName: displayName.isEmpty ? "Apple profile" : displayName,
            subject: "apple_\(credential.user)",
            expiresAt: Date().addingTimeInterval(3600 * 24 * 365)
        )

        do {
            try store.saveSession(session)
            RossAuthSessionSnapshot.shared.update(session)
            clearUnlockPresentationState()
            authErrorMessage = nil
            setSignedIn(session)
        } catch {
            authErrorMessage = "Could not sign in. Please try again."
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        defer {
            appleAuthorizationController = nil
            activeExternalProvider = nil
        }

        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return
        }

        authErrorMessage = "Could not sign in. Please try again."
    }

    private func activePresentationAnchor() -> ASPresentationAnchor {
        #if canImport(UIKit)
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            return window
        }
        return ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }

    private func refreshedSessionIfNeeded(from session: RossAuthSession) async throws -> RossAuthSession {
        let refreshLeadTime: TimeInterval = 5 * 60
        guard session.expiresAt.timeIntervalSinceNow <= refreshLeadTime else {
            return session
        }

        var request = URLRequest(url: rossBackendBaseURL().appendingPathComponent("auth/session/refresh"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refreshToken": session.refreshToken])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return session
            }
            guard 200..<300 ~= httpResponse.statusCode else {
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw NSError(domain: "RossAuthController", code: httpResponse.statusCode, userInfo: nil)
                }
                return session
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(RossRefreshSessionPayload.self, from: data)
            let refreshedSession = RossAuthSession(
                accessToken: payload.accessToken,
                refreshToken: payload.refreshToken,
                accountToken: payload.accountToken,
                email: payload.profile?.email ?? session.email,
                displayName: payload.profile?.displayName ?? session.displayName,
                subject: payload.subject,
                expiresAt: payload.expiresAt
            )
            try store.saveSession(refreshedSession)
            return refreshedSession
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .timedOut,
                 .dnsLookupFailed:
                return session
            default:
                throw error
            }
        }
    }

    private func finishGoogleSignIn(callbackURL: URL?, error: Error?) {
        defer {
            webAuthenticationSession = nil
            activeExternalProvider = nil
        }

        if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
            return
        }

        if error != nil {
            authErrorMessage = "Could not sign in. Please try again."
            return
        }

        guard let callbackURL else {
            authErrorMessage = "Could not sign in. Please try again."
            return
        }

        let callbackItems = parseCallbackItems(from: callbackURL)
        if callbackItems["error"] != nil {
            authErrorMessage = "Could not sign in. Please try again."
            return
        }

        guard
            let accessToken = callbackItems["access_token"],
            let refreshToken = callbackItems["refresh_token"],
            let accountToken = callbackItems["account_token"],
            let email = callbackItems["email"],
            let subject = callbackItems["subject"],
            let expiresAt = parseDate(from: callbackItems["expires_at"])
        else {
            authErrorMessage = "Could not sign in. Please try again."
            return
        }

        let session = RossAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accountToken: accountToken,
            email: email,
            displayName: callbackItems["display_name"],
            subject: subject,
            expiresAt: expiresAt
        )

        do {
            try store.saveSession(session)
            RossAuthSessionSnapshot.shared.update(session)
            setSignedIn(session)
        } catch {
            authErrorMessage = "Could not sign in. Please try again."
        }
    }

    private func parseCallbackItems(from url: URL) -> [String: String] {
        var values: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems?.forEach { item in
                if let value = item.value {
                    values[item.name] = value
                }
            }
        }

        if let fragment = url.fragment,
           let fragmentComponents = URLComponents(string: "ross://fragment?\(fragment)") {
            fragmentComponents.queryItems?.forEach { item in
                if let value = item.value {
                    values[item.name] = value
                }
            }
        }

        return values
    }

    private func parseDate(from value: String?) -> Date? {
        guard let value else { return nil }
        if let date = isoFormatter.date(from: value) {
            return date
        }
        if let seconds = TimeInterval(value) {
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }

    private func shouldRequireUnlock() -> Bool {
        canEvaluateDeviceUnlock()
    }

    func setQuickUnlockEnabled(_ enabled: Bool) {
        quickUnlockEnabled = enabled
        rossSetQuickUnlockEnabled(enabled)
        guard !enabled else { return }
        pendingQuickRelockSession = nil
        pendingAutomaticUnlock = false
        privacyShieldVisible = false
        isUnlocking = false
        authErrorMessage = nil
        if case .unlockRequired(let session) = phase {
            setSignedIn(session)
        }
    }

    private func currentBiometryType() -> LABiometryType {
        biometryTypeProvider()
    }

    private func availableBiometryLabel() -> String? {
        switch currentBiometryType() {
        case .faceID:
            "Face ID"
        case .touchID:
            "Touch ID"
        default:
            nil
        }
    }

    private func attemptAutomaticUnlockIfNeeded() {
        guard pendingAutomaticUnlock else { return }
        guard case .unlockRequired = phase else { return }
        guard !isUnlocking else { return }
        pendingAutomaticUnlock = false
        startUnlock(trigger: .automatic)
    }

    private func startUnlock(trigger: RossUnlockTrigger) {
        guard case .unlockRequired(let pendingSession) = phase else { return }
        guard !isUnlocking else { return }

        authErrorMessage = nil
        privacyShieldVisible = true
        isUnlocking = true

        guard shouldRequireUnlock() else {
            isUnlocking = false
            privacyShieldVisible = false
            authErrorMessage = "Quick unlock is not available on this device."
            return
        }

        evaluateDeviceUnlock(
            "Unlock Ross to access your local matters, files, and chats."
        ) { [weak self] success, evaluationError in
            Task { @MainActor [weak self] in
                self?.finishUnlockAttempt(
                    success: success,
                    evaluationError: evaluationError,
                    session: pendingSession,
                    trigger: trigger
                )
            }
        }
    }

    private func finishUnlockAttempt(
        success: Bool,
        evaluationError: Error?,
        session: RossAuthSession,
        trigger: RossUnlockTrigger
    ) {
        isUnlocking = false

        guard case .unlockRequired = phase else {
            privacyShieldVisible = false
            return
        }

        if success {
            authErrorMessage = nil
            pendingQuickRelockSession = nil
            pendingAutomaticUnlock = false
            privacyShieldVisible = false
            setSignedIn(session)
            return
        }

        let errorCode = localAuthenticationErrorCode(from: evaluationError)
        switch errorCode {
        case .appCancel, .systemCancel, .notInteractive:
            pendingAutomaticUnlock = true
            privacyShieldVisible = true
            authErrorMessage = nil
        case .userCancel, .userFallback:
            privacyShieldVisible = false
            authErrorMessage = nil
        case .authenticationFailed:
            privacyShieldVisible = false
            authErrorMessage = "Could not confirm your identity. Try again."
        case .biometryLockout:
            privacyShieldVisible = false
            authErrorMessage = "Use your device passcode to continue."
        case .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet:
            privacyShieldVisible = false
            authErrorMessage = "Quick unlock is not available on this device."
        default:
            privacyShieldVisible = false
            authErrorMessage = trigger == .manual ? "Could not unlock. Please try again." : nil
        }

        phase = .unlockRequired(session)
    }

    private func clearUnlockPresentationState() {
        pendingQuickRelockSession = nil
        pendingAutomaticUnlock = false
        privacyShieldVisible = false
        isUnlocking = false
    }

    private func localAuthenticationErrorCode(from error: Error?) -> LAError.Code? {
        if let localAuthenticationError = error as? LAError {
            return localAuthenticationError.code
        }

        let nsError = error as NSError?
        guard nsError?.domain == LAError.errorDomain,
              let rawCode = nsError?.code,
              let code = LAError.Code(rawValue: rawCode) else {
            return nil
        }
        return code
    }

    private static func defaultCanEvaluateDeviceUnlock() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    private static func defaultBiometryType() -> LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        return context.biometryType
    }

    private static func defaultEvaluateDeviceUnlock(
        localizedReason: String,
        completion: @escaping @Sendable (Bool, Error?) -> Void
    ) {
        let context = LAContext()
        context.localizedFallbackTitle = "Use device passcode"
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: localizedReason,
            reply: completion
        )
    }
}

private struct RossAuthRootView: View {
    @Bindable var authController: RossAuthController

    var body: some View {
        Group {
            switch authController.phase {
            case .loading:
                RossLaunchSplashView()
            case .signedOut:
                if authController.hasSelectedLanguage {
                    RossSignInScreen(authController: authController)
                        .transition(.opacity)
                } else {
                    RossLanguageSelectionScreen(authController: authController)
                        .transition(.opacity)
                }
            case .unlockRequired, .signedIn:
                RossAuthenticatedShell(authController: authController)
            }
        }
        .transaction { transaction in
            if case .signedIn = authController.phase {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .animation(.easeOut(duration: 0.18), value: authController.hasSelectedLanguage)
        .task {
            await authController.loadIfNeeded()
        }
    }
}

private struct RossAuthenticatedShell: View {
    @Bindable var authController: RossAuthController

    private var lockedSession: RossAuthSession? {
        if case .unlockRequired(let session) = authController.phase {
            return session
        }
        return nil
    }

    private var requiresWorkspaceShield: Bool {
        authController.privacyShieldVisible || authController.isUnlocking || lockedSession != nil
    }

    var body: some View {
        ZStack {
            AlphaRossRootView(authController: authController)
                .allowsHitTesting(!requiresWorkspaceShield)

            if requiresWorkspaceShield {
                RossWorkspacePrivacyShield(isUnlocking: authController.isUnlocking)
            }

            if let lockedSession, !authController.isUnlocking {
                RossQuickUnlockScreen(
                    authController: authController,
                    session: lockedSession
                )
            }
        }
    }
}

private struct RossWorkspacePrivacyShield: View {
    let isUnlocking: Bool

    var body: some View {
        ZStack {
            RossAuthBackdrop()

            VStack(spacing: 12) {
                RossAuthHeroMark(size: 54)

                if isUnlocking {
                    ProgressView()
                        .tint(Color.rossAccent)
                        .scaleEffect(1.02)

                    Text(rossLocalized("unlocking_ross"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                } else {
                    Text(rossLocalized("workspace_locked"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                }
            }
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Language Selection Screen

private struct RossLanguageSelectionScreen: View {
    @Bindable var authController: RossAuthController
    @State private var selectedCode: String? = nil

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            RossAuthHeroMark(size: 62)

                            Text("ROSS")
                                .font(.system(size: 15, weight: .bold))
                                .tracking(3.8)
                                .foregroundStyle(Color.rossAccent)

                            Spacer(minLength: 0)
                        }
                        .padding(.top, rossAuthTopHeaderPadding(proxy.safeAreaInsets.top))

                        RossAuthGlassPanel(cornerRadius: 20, padding: 18) {
                            VStack(alignment: .leading, spacing: 20) {
                                Text(rossLocalized("choose_language_title", languageCode: selectedCode ?? "en"))
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color.rossInk)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(rossLocalized("choose_language_detail", languageCode: selectedCode ?? "en"))
                                    .font(.footnote)
                                    .foregroundStyle(Color.rossInk.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)

                                LazyVGrid(columns: columns, spacing: 18) {
                                    ForEach(rossLanguageOptions) { option in
                                        RossLanguageTile(
                                            option: option,
                                            isSelected: selectedCode == option.id
                                        ) {
                                            withAnimation(.easeOut(duration: 0.14)) {
                                                selectedCode = option.id
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 144)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        Button {
                            guard let code = selectedCode else { return }
                            authController.markLanguageSelected(code: code)
                        } label: {
                            Text(rossLocalized("continue", languageCode: selectedCode ?? "en"))
                        }
                        .rossPrimaryButtonStyle()
                        .disabled(selectedCode == nil)
                        .opacity(selectedCode == nil ? 0.48 : 1)
                        .animation(.easeOut(duration: 0.18), value: selectedCode == nil)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
                }
            }
            .background {
                RossAuthBackdrop()
            }
        }
    }
}

private struct RossLanguageTile: View {
    let option: RossLanguageOption
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(option.nativeName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.rossInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(option.englishName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(
                        isSelected
                            ? Color.white.opacity(0.82)
                            : Color.rossInk.opacity(0.7)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
            .rossGlassSurface(
                tint: isSelected ? Color.rossAccent : Color.rossHighlight,
                cornerRadius: 16,
                interactive: true,
                shadowOpacity: isSelected ? 0.24 : 0.10,
                shadowRadius: isSelected ? 12 : 8,
                shadowY: isSelected ? 8 : 4,
                fillOpacity: isSelected ? 0.88 : 0.90,
                strokeOpacity: isSelected ? 0.46 : 0.62
            )
            .background {
                if isSelected {
                    shape.fill(Color.rossPillGradient)
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            isSelected
                                ? Color.white.opacity(0.32)
                                : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.38),
                            isSelected
                                ? Color.white.opacity(0.12)
                                : Color.rossGlassStroke.opacity(colorScheme == .dark ? 0.34 : 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .scaleEffect(isSelected ? 1.01 : 1)
        }
        .buttonStyle(.plain)
    }
}

private struct RossSignInScreen: View {
    @Bindable var authController: RossAuthController
    @State private var emailAccessAddress = "advocate@ross.ai"
    @State private var signInCardExpanded = false
    @State private var emailOptionExpanded = false

    private var reservedSheetHeight: CGFloat {
        if emailOptionExpanded {
            return 398
        }
        return signInCardExpanded ? 258 : 126
    }

    var body: some View {
        GeometryReader { proxy in
            let heroPanelWidth = min(proxy.size.width - 32, 430)
            let signInPanelWidth = min(proxy.size.width - 32, 440)
            ZStack(alignment: .bottom) {
                VStack(alignment: .center, spacing: 24) {
                    HStack(spacing: 14) {
                        RossAuthHeroMark(size: 58)

                        Text("ROSS")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(3.6)
                            .foregroundStyle(Color.rossAccent)

                        Spacer(minLength: 0)
                    }
                    .frame(width: heroPanelWidth, alignment: .leading)
                    .padding(.top, rossAuthTopHeaderPadding(proxy.safeAreaInsets.top))

                    RossAuthGlassPanel(cornerRadius: 24, padding: 22, forcedWidth: heroPanelWidth) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(rossLocalized("private_legal_work"))
                                .font(.system(size: 34, weight: .regular))
                                .foregroundStyle(Color.rossInk.opacity(0.96))
                                .fixedSize(horizontal: false, vertical: true)

                            Text(rossLocalized("matters_private"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.rossInk.opacity(0.78))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 16)
                .padding(.bottom, reservedSheetHeight)

                VStack {
                    Spacer(minLength: 0)

                    HStack(spacing: 0) {
                        Spacer(minLength: 0)

                        RossAuthSignInSheet(
                            authController: authController,
                            emailAddress: $emailAccessAddress,
                            isExpanded: $signInCardExpanded,
                            isEmailExpanded: $emailOptionExpanded,
                            panelWidth: signInPanelWidth,
                            bottomInset: proxy.safeAreaInsets.bottom
                        )

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .background {
                RossAuthBackdrop()
            }
        }
        .onChange(of: authController.authErrorMessage) { _, newValue in
            guard let newValue, !newValue.isEmpty else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                signInCardExpanded = true
            }
        }
    }
}

private struct RossAuthSignInSheet: View {
    @Bindable var authController: RossAuthController
    @Binding var emailAddress: String
    @Binding var isExpanded: Bool
    @Binding var isEmailExpanded: Bool
    let panelWidth: CGFloat
    let bottomInset: CGFloat

    private var externalSignInDisabled: Bool {
        authController.isStartingSignIn
    }

    private var selectedEmailProfile: RossEmailAccessProfile? {
        rossEmailAccessProfile(for: emailAddress)
    }

    var body: some View {
        RossAuthGlassPanel(cornerRadius: 24, padding: 18, forcedWidth: panelWidth) {
            VStack(alignment: .leading, spacing: isExpanded ? 12 : 10) {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    VStack(alignment: .center, spacing: 8) {
                        RossAuthSheetCue(isExpanded: isExpanded)

                        VStack(spacing: 4) {
                            Text(rossLocalized("get_started"))
                                .font(.system(size: isExpanded ? 19 : 24, weight: isExpanded ? .semibold : .semibold))
                                .foregroundStyle(Color.rossInk)
                                .multilineTextAlignment(.center)

                            Text(isExpanded ? rossLocalized("choose_workspace") : rossLocalized("tap_to_sign_in"))
                                .font(.system(size: isExpanded ? 13 : 14, weight: .regular))
                                .foregroundStyle(Color.rossInk.opacity(0.62))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        if isEmailExpanded {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(rossLocalized("email_access"))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.rossInk)

                                    Spacer(minLength: 10)

                                    Button {
                                        withAnimation(.easeOut(duration: 0.16)) {
                                            isEmailExpanded = false
                                        }
                                    } label: {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color.rossInk.opacity(0.72))
                                            .frame(width: 30, height: 30)
                                            .rossNativeGlassSurface(
                                                tint: Color.rossInk.opacity(0.14),
                                                shape: Circle(),
                                                interactive: true,
                                                fallbackFillOpacity: 0.72,
                                                fallbackStrokeOpacity: 0.18
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(rossLocalized("back"))
                                }

                                VStack(spacing: 8) {
                                    ForEach(rossEmailAccessProfiles) { profile in
                                        RossEmailAccessPresetRow(
                                            profile: profile,
                                            isSelected: selectedEmailProfile?.id == profile.id
                                        ) {
                                            emailAddress = profile.email
                                        }
                                    }
                                }

                                RossAuthInputField(
                                    title: "Email",
                                    text: $emailAddress,
                                    placeholder: "advocate@ross.ai",
                                    iconSystemName: "envelope.fill",
                                    onSubmit: {
                                        authController.signInWithEmailAccess(emailAddress)
                                    }
                                )

                                Button {
                                    authController.signInWithEmailAccess(emailAddress)
                                } label: {
                                    RossAuthActionLabel(
                                        title: rossLocalized("continue"),
                                        tone: .secondary
                                    ) {
                                        RossGlassIconView(.userMsg, variant: .neutral, size: 17, fallbackSystemImage: "envelope.fill")
                                    }
                                }
                                .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 20)
                            }
                            .transition(.opacity)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Button {
                                    authController.startGoogleSignIn()
                                } label: {
                                    RossAuthActionLabel(
                                        title: authController.activeExternalProvider == .google ? rossLocalized("connecting_to_google") : rossLocalized("continue_with_google"),
                                        tone: .secondary
                                    ) {
                                        RossGoogleMark(size: 17)
                                    }
                                }
                                .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 20)
                                .disabled(externalSignInDisabled)
                                .opacity(externalSignInDisabled && authController.activeExternalProvider != .google ? 0.78 : 1)

                                Button {
                                    authController.startAppleSignIn()
                                } label: {
                                    RossAuthActionLabel(
                                        title: authController.activeExternalProvider == .apple ? rossLocalized("connecting_to_apple") : rossLocalized("continue_with_apple"),
                                        tone: .secondary
                                    ) {
                                        Image(systemName: "applelogo")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .rossGlassButtonStyle(cornerRadius: 20)
                                .disabled(externalSignInDisabled)
                                .opacity(externalSignInDisabled && authController.activeExternalProvider != .apple ? 0.78 : 1)

                                Button {
                                    authController.authErrorMessage = nil
                                    withAnimation(.easeOut(duration: 0.16)) {
                                        isEmailExpanded = true
                                    }
                                } label: {
                                    RossAuthActionLabel(
                                        title: rossLocalized("continue_email"),
                                        subtitle: rossLocalized("email_subtitle"),
                                        tone: .secondary
                                    ) {
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                }
                                .rossGlassButtonStyle(cornerRadius: 20)

                                Text(rossLocalized("demo_data_sample_only"))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.rossInk.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    if let errorMessage = authController.authErrorMessage, !errorMessage.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            RossGlassIconView(
                                .triangleWarning,
                                variant: .highlight,
                                size: 16,
                                fallbackSystemImage: "exclamationmark.triangle.fill"
                            )

                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(red: 0.63, green: 0.37, blue: 0.17))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(red: 0.96, green: 0.67, blue: 0.38).opacity(0.14))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(red: 0.84, green: 0.55, blue: 0.28).opacity(0.34), lineWidth: 1)
                        }
                    }
                }
            }
            .padding(.bottom, max(bottomInset - 2, 12))
            .animation(.easeOut(duration: 0.16), value: isExpanded)
            .animation(.easeOut(duration: 0.16), value: isEmailExpanded)
        }
    }
}

private struct RossAuthSheetCue: View {
    let isExpanded: Bool
    @State private var pulse = false

    var body: some View {
        Image(systemName: isExpanded ? "chevron.down" : "arrow.up")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.rossInk.opacity(isExpanded ? 0.46 : (pulse ? 0.76 : 0.32)))
            .frame(width: 28, height: 18)
            .onAppear {
                guard !isExpanded else { return }
                withAnimation(.easeInOut(duration: 0.74).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .onChange(of: isExpanded) { _, expanded in
                pulse = false
                guard !expanded else { return }
                withAnimation(.easeInOut(duration: 0.74).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}

private enum RossAuthActionTone {
    case primary
    case secondary
}

private struct RossEmailAccessPresetRow: View {
    let profile: RossEmailAccessProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: profile.workspace == .demo ? "briefcase.fill" : "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.rossAccent : Color.rossInk.opacity(0.44))
                    .frame(width: 24, height: 24)
                    .background(
                        (isSelected ? Color.rossAccent.opacity(0.12) : Color.white.opacity(0.12)),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.rossInk)

                    Text(profile.detail)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(Color.rossInk.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.rossAccent : Color.rossInk.opacity(0.26))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                (isSelected ? Color.rossAccent.opacity(0.08) : Color.white.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.rossAccent.opacity(0.2) : Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RossAuthActionLabel<Icon: View>: View {
    let title: String
    let subtitle: String?
    let tone: RossAuthActionTone
    let icon: Icon

    init(
        title: String,
        subtitle: String? = nil,
        tone: RossAuthActionTone,
        @ViewBuilder icon: () -> Icon
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.icon = icon()
    }

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tone == .primary ? Color.white : Color.rossInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(
                            tone == .primary
                                ? Color.white.opacity(0.76)
                                : Color.rossInk.opacity(0.58)
                        )
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RossAuthNotice: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.rossInk.opacity(0.62))
                .frame(width: 18, height: 18)

            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.rossInk.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .rossGlassSurface(tint: Color.orange, cornerRadius: 14, shadowOpacity: 0.06, shadowRadius: 6, shadowY: 2, fillOpacity: 0.76, strokeOpacity: 0.44)
    }
}

private struct RossGoogleMark: View {
    let size: CGFloat

    init(size: CGFloat = 18) {
        self.size = size
    }

    var body: some View {
        Text("G")
            .font(.system(size: size * 1.02, weight: .bold, design: .rounded))
            .foregroundStyle(
                AngularGradient(
                    colors: [
                        Color(red: 0.26, green: 0.52, blue: 0.96),
                        Color(red: 0.20, green: 0.66, blue: 0.33),
                        Color(red: 0.98, green: 0.74, blue: 0.18),
                        Color(red: 0.92, green: 0.26, blue: 0.21),
                        Color(red: 0.26, green: 0.52, blue: 0.96)
                    ],
                    center: .center
                )
            )
            .frame(width: size, height: size)
            .rossNativeGlassSurface(
                tint: Color.white.opacity(0.20),
                shape: Circle(),
                interactive: false,
                fallbackFillOpacity: 0.88,
                fallbackStrokeOpacity: 0.56
            )
    }
}

private struct RossQuickUnlockScreen: View {
    @Bindable var authController: RossAuthController
    let session: RossAuthSession
    @State private var showingSignOutConfirmation = false

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = min(proxy.size.width - 32, 390)

            VStack(spacing: 22) {
                Spacer(minLength: max(proxy.safeAreaInsets.top + 18, 48))

                RossAuthHeroMark(size: 72)

                RossAuthGlassPanel(cornerRadius: 20, padding: 18, forcedWidth: panelWidth) {
                    VStack(alignment: .center, spacing: 16) {
                        VStack(spacing: 6) {
                            Text(rossLocalized("ross_is_locked"))
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(Color.rossInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            Text(rossUnlockContinueLabel(authController.quickUnlockSummary))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.68))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(session.displayLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossInk.opacity(0.68))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .rossNativeGlassSurface(
                                tint: Color.rossAccent,
                                shape: Capsule(),
                                fallbackFillOpacity: 0.82,
                                fallbackStrokeOpacity: 0.44
                            )

                        if let errorMessage = authController.authErrorMessage, !errorMessage.isEmpty {
                            RossAuthNotice(text: errorMessage)
                        }

                        Button {
                            authController.unlockSession()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: authController.unlockSymbolName)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(authController.unlockButtonTitle)
                            }
                        }
                        .rossPrimaryButtonStyle()

                        Button(rossLocalized("sign_out")) {
                            showingSignOutConfirmation = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.58))
                    }
                }

                Spacer(minLength: max(proxy.safeAreaInsets.bottom + 18, 48))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
        }
        .alert(rossLocalized("sign_out_of_ross_question"), isPresented: $showingSignOutConfirmation) {
            Button(rossLocalized("sign_out_destructive"), role: .destructive) {
                authController.signOut()
            }
            Button(rossLocalized("cancel"), role: .cancel) {}
        } message: {
            Text(rossLocalized("sign_out_local_detail"))
        }
    }
}

func rossUnlockContinueLabel(_ unlockSummary: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("use_unlock_to_continue", languageCode: languageCode), unlockSummary)
}

struct RossAuthHeroMark: View {
    var size: CGFloat = 132

    var body: some View {
        Image("RossLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: Color.rossBackdropGlow.opacity(0.18), radius: 12, y: -2)
            .shadow(color: Color.rossShadow.opacity(0.2), radius: 24, y: 16)
    }
}

struct RossAuthBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.rossGroupedBackground,
                    Color.rossSecondaryGroupedBackground,
                    Color.rossGroupedBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.rossBackdropGlow.opacity(colorScheme == .dark ? 0.36 : 0.48),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 620, height: 320)
                .rotationEffect(.degrees(-18))
                .blur(radius: 34)
                .offset(x: -40, y: -260)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.rossHighlight.opacity(colorScheme == .dark ? 0.16 : 0.14),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 420, height: 420)
                .blur(radius: 48)
                .offset(x: 170, y: 250)

            Circle()
                .fill(Color.rossGlassStroke.opacity(colorScheme == .dark ? 0.12 : 0.28))
                .frame(width: 320, height: 320)
                .blur(radius: 76)
                .offset(x: 148, y: -210)
        }
        .ignoresSafeArea()
    }
}

private struct RossAuthGlassPanel<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let forcedWidth: CGFloat?
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = 30,
        padding: CGFloat = 24,
        forcedWidth: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.forcedWidth = forcedWidth
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(width: forcedWidth, alignment: .leading)
            .rossGlassSurface(
                tint: Color.rossHighlight,
                cornerRadius: cornerRadius,
                shadowOpacity: colorScheme == .dark ? 0.24 : 0.16,
                shadowRadius: colorScheme == .dark ? 18 : 24,
                shadowY: colorScheme == .dark ? 10 : 14,
                fillOpacity: colorScheme == .dark ? 0.86 : 0.92,
                strokeOpacity: colorScheme == .dark ? 0.30 : 0.66
            )
            .shadow(
                color: Color.rossBackdropGlow.opacity(colorScheme == .dark ? 0.08 : 0.10),
                radius: colorScheme == .dark ? 22 : 30,
                y: colorScheme == .dark ? 8 : 12
            )
    }
}

private struct RossAuthInputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let iconSystemName: String
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.rossInk.opacity(0.6))

            HStack(spacing: 12) {
                Image(systemName: iconSystemName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.rossInk.opacity(0.44))
                    .frame(width: 18, height: 18)

                TextField(placeholder, text: $text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.rossInk)
                    .rossEmailFieldInputBehavior()
                    .focused($isFocused)
                    .onSubmit(onSubmit)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .rossGlassSurface(cornerRadius: 14, interactive: true, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 2, fillOpacity: 0.74, strokeOpacity: isFocused ? 0.72 : 0.48)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isFocused
                            ? Color.white.opacity(0.42)
                            : Color.white.opacity(0.18),
                        lineWidth: 1
                    )
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func rossEmailFieldInputBehavior() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)
            .submitLabel(.done)
        #else
        self
        #endif
    }
}

@MainActor
@main
struct RossApp: App {
    private let launchMode = RossLaunchMode.current
    @Environment(\.scenePhase) private var scenePhase
    @State private var authController = RossAuthController()
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(RossAppDelegate.self) private var appDelegate
    #endif

    init() {
        if RossLaunchMode.current == .localModelSmoke {
            setvbuf(stdout, nil, _IONBF, 0)
            setvbuf(stderr, nil, _IONBF, 0)
        }
        alphaSweepTemporaryAssistantDownloadsAtLaunch()
    }

    var body: some Scene {
        WindowGroup {
            switch launchMode {
            case .interactive:
                RossAuthRootView(authController: authController)
                    .onChange(of: scenePhase) { _, newPhase in
                        var transaction = Transaction(animation: nil)
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            authController.handleScenePhase(newPhase)
                        }
                    }
            case .screenshotExport:
                ScreenshotExportView()
            case .localModelSmoke:
                RossLocalModelSmokeView()
            }
        }
    }
}
