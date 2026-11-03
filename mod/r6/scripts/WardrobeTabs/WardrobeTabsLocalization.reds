// The mod's texts in every language.
module EquipmentEx
import Codeware.Localization.*
//
// ============================================================================================
// TRANSLATING THE MOD OR CHANGING ITS TEXTS (no programming needed; requires TweakXL)
// ============================================================================================
// You never edit the mod's files. You add one text file of your own, and the mod uses your texts
// in place of its own:
//
// 1. Create a folder and a file in the game directory, for example
//        Cyberpunk 2077/r6/tweaks/WUI_MyTranslation/de-de.yaml
//    (any folder name and file name ending in .yaml works). Save it as UTF-8, without tabs.
//
// 2. Put one line per text in it:
//        WUI_Loc.<language>.<Name>: "your text"
//    for example, for German:
//        WUI_Loc.de-de.Bar-Revert: "ZURÜCK"
//        WUI_Loc.de-de.Area-Feet: "SCHUHE"
//    <language> is the game's language code (the language you set in the game's settings):
//        ar-ar  Arabic           es-mx  Spanish (Latin America)   pl-pl  Polish
//        cz-cz  Czech            fr-fr  French                     pt-br  Portuguese (Brazil)
//        de-de  German           hu-hu  Hungarian                  ru-ru  Russian
//        en-us  English          it-it  Italian                    th-th  Thai
//        es-es  Spanish (Spain)  jp-jp  Japanese                   tr-tr  Turkish
//        kr-kr  Korean           ua-ua  Ukrainian                  zh-cn  Chinese (Simplified)
//                                                                   zh-tw  Chinese (Traditional)
//    <Name> is the text's name: every label, button and message of the mod is listed, with its
//    English, in WardrobeTabsLocalizationTexts.reds next to this file. Each line there reads
//        this.Text("WUI-<Name>", "English text");
//    and your line uses that <Name> without "WUI-". Lines you leave out keep the mod's own text
//    (or English), so a file can change a single label or translate everything.
//    Some texts hold {0}, {1}...: the mod fills those in (a number, a name). Keep them all in your
//    text, in any order your language needs.
//    To change the mod's English, use en-us, e.g. WUI_Loc.en-us.Area-Feet: "SHOES".
//
// 3. Restart the game (TweakXL reads the file when the game starts).
//
// Good to know:
//  - The mod ships its own translation of every language the game offers (machine translations, so
//    far): your file changes any of its lines, for your language only.
//  - The wardrobe shows your texts the next time it opens. The Mod Settings menu shows them only
//    after you switch the game's language once in its settings (any language and back); until then
//    it shows the mod's own translation, or English. That is a limit of when the game loads texts.
//  - Slot names (Head, Outer Torso...), item names and outfit names come from the game,
//    Equipment-EX or the mod that adds them, so they follow those.
//  - A mistake in the file (e.g. a missing closing quote) makes TweakXL skip that one file; the
//    game and other mods are fine. The error and its line number are in
//    red4ext/plugins/TweakXL/TweakXL-<date>.log.
//  - The game draws each language's own alphabet only while it runs in that language: a Cyrillic
//    text shows as blanks with the game in English, for example.
//  - If two files set the same line, the last one TweakXL reads (alphabetical) wins. Use one file
//    per language.
//  - Want your translation shipped with the mod? Send the file to the mod author: it's already in
//    the format the mod's own translations use.
//
// ============================================================================================
// HOW IT WORKS (for modders)
// ============================================================================================
// The mod's own texts (localization/<lang>.yaml in the mod's source, same line format as above)
// are generated into WardrobeTabsLocalizationTexts.reds by tools/gen_localization.py. They go into
// the game's own text table through one Codeware localization provider
// (WardrobeTabsLocalization below), which Codeware asks for texts when the game loads its
// language files; Mod Settings reads that table. Players' lines are TweakXL flats. At launch
// Codeware builds the table before TweakDB can be read, so those reach the table only after an
// in-game language switch; WardrobeTabsText (the wardrobe's lookup) reads them itself, so the
// wardrobe always shows them.
// Order, last wins: English < the shipped language < the player's line.

// A player's line for a language and a text name (WUI_Loc.<lang>.<Name> in TweakDB), "" when
// there is none (or TweakDB isn't readable yet).
public func WardrobeTabsLocFlat(lang: String, name: String) -> String {
    if StrLen(lang) == 0 {
        return "";
    }
    return TweakDBInterface.GetString(TDBID.Create("WUI_Loc." + lang + "." + name), "");
}

// Codeware finds this class by itself and asks it for the texts of the game's language (and of
// English, the fallback, for any text that language doesn't have).
public class WardrobeTabsLocalization extends ModLocalizationProvider {
    public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
        let package = new WardrobeTabsLocPackage();
        package.m_lang = NameToString(language);
        return package;
    }

    public func GetFallback() -> CName {
        return n"en-us";
    }
}

// One language's texts. The generated WardrobeTabsLocPackage (WardrobeTabsLocalizationTexts.reds)
// extends this with the names and shipped texts; m_lang is the language code, e.g. "de-de".
public abstract class WardrobeTabsLocPackageBase extends ModLocalizationPackage {
    public let m_lang: String;

    public func Names() -> array<String> {
        let none: array<String>;
        return none;
    }

    protected func DefineEnUs() {}

    protected func DefineShipped(lang: String) {}

    // English, then the shipped language over it, then the player's overrides for it.
    protected func DefineTexts() {
        this.DefineEnUs();
        if NotEquals(this.m_lang, "en-us") {
            this.DefineShipped(this.m_lang);
        }
        let names: array<String> = this.Names();
        for name in names {
            let override = WardrobeTabsLocFlat(this.m_lang, name);
            if StrLen(override) > 0 {
                this.Text("WUI-" + name, override);
            }
        }
    }

    // A text of this package, "" when it has none.
    public func Lookup(key: String) -> String {
        let entry = this.GetEntries(EntryType.Interface).Get(LocalizationEntry.Hash(key)) as LocalizationEntry;
        return IsDefined(entry) ? entry.GetVariant(PlayerGender.Default) : "";
    }
}

public class WardrobeTabsLocText {
    public let text: String;
}

// The wardrobe's lookup: the override for the game's language, else the table's text, else
// English, else the key. Cached per key; the language is read and the cache emptied each time
// the wardrobe opens (the language can't change while it's open).
public class WardrobeTabsLocService extends ScriptableService {
    private let m_lang: String;
    private let m_cache: ref<inkHashMap>;
    private let m_english: ref<WardrobeTabsLocPackage>;

    public static func Get() -> ref<WardrobeTabsLocService> {
        return GameInstance.GetScriptableServiceContainer()
            .GetService(n"EquipmentEx.WardrobeTabsLocService") as WardrobeTabsLocService;
    }

    // From the wardrobe's opening (WardrobeTabsBuild).
    public func Refresh() {
        let language = GameInstance.GetSettingsSystem(GetGameInstance()).GetVar(n"/language", n"OnScreen") as ConfigVarListName;
        this.m_lang = IsDefined(language) ? NameToString(language.GetValue()) : "";
        this.m_cache = new inkHashMap();
    }

    public func Text(key: CName) -> String {
        if !IsDefined(this.m_cache) {
            this.m_cache = new inkHashMap();
        }
        let keyString = NameToString(key);
        let hash = LocalizationEntry.Hash(keyString);
        if this.m_cache.KeyExist(hash) {
            return (this.m_cache.Get(hash) as WardrobeTabsLocText).text;
        }
        let text = this.Resolve(key, keyString);
        // The key itself means nothing was found (yet): not cached, so a later call can find it.
        if NotEquals(text, keyString) {
            let cached = new WardrobeTabsLocText();
            cached.text = text;
            this.m_cache.Insert(hash, cached);
        }
        return text;
    }

    private func Resolve(key: CName, keyString: String) -> String {
        if StrBeginsWith(keyString, "WUI-") {
            let override = WardrobeTabsLocFlat(this.m_lang, StrRight(keyString, StrLen(keyString) - 4));
            if StrLen(override) > 0 {
                return override;
            }
        }
        let text = GetLocalizedTextByKey(key);
        if StrLen(text) > 0 {
            return text;
        }
        // Only when the game's table lacks the key. This English package also carries the
        // player's en-us lines (it is built like any other), which is what an English player wants.
        if !IsDefined(this.m_english) {
            this.m_english = new WardrobeTabsLocPackage();
            this.m_english.m_lang = "en-us";
        }
        text = this.m_english.Lookup(keyString);
        return StrLen(text) > 0 ? text : keyString;
    }
}

// A text of the mod by key (n"WUI-<Name>", listed in localization/en-us.yaml). Never blank:
// without the service it falls back to the table, then to the key itself.
public func WardrobeTabsText(key: CName) -> String {
    let loc = WardrobeTabsLocService.Get();
    if !IsDefined(loc) {
        let text = GetLocalizedTextByKey(key);
        return StrLen(text) > 0 ? text : NameToString(key);
    }
    return loc.Text(key);
}

// Fills {0}, {1}... in text with args, in one pass, so an argument that itself holds "{1}" stays
// as it is. Unknown or malformed braces ("{5}" with two args, "{x}", "{") stay in the text.
public func WardrobeTabsLocFormat(text: String, args: array<String>) -> String {
    let out = "";
    let rest = text;
    let open = StrFindFirst(rest, "{");
    while open >= 0 {
        let after = StrRight(rest, StrLen(rest) - open - 1);
        let close = StrFindFirst(after, "}");
        if close < 0 {
            break;
        }
        let digits = StrLeft(after, close);
        let index = StringToInt(digits, -1);
        if close > 0 && index >= 0 && index < ArraySize(args) && Equals(IntToString(index), digits) {
            out = out + StrLeft(rest, open) + args[index];
            rest = StrRight(after, StrLen(after) - close - 1);
        } else {
            out = out + StrLeft(rest, open + 1);
            rest = after;
        }
        open = StrFindFirst(rest, "{");
    }
    return out + rest;
}

// WardrobeTabsText with {0}, {1}... replaced by args, so a translation can put them in any order.
public func WardrobeTabsTextF(key: CName, args: array<String>) -> String {
    return WardrobeTabsLocFormat(WardrobeTabsText(key), args);
}

// A count with its singular or plural text ("<key>-One" / "<key>-Many"), e.g. "1 ITEM", "3 ITEMS".
public func WardrobeTabsCount(key: String, count: Int32) -> String {
    return WardrobeTabsTextF(StringToName(key + (count == 1 ? "-One" : "-Many")), [ToString(count)]);
}
