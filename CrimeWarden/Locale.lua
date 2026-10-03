local _, ns = ...

-- Deutsch ist Standard. Fehlt ein englischer Text, wird der deutsche angezeigt.
local deDE = {
    TITLE = "CrimeWarden",
    TITLE_COUNT = "CrimeWarden (%d)",
    LOADED = "Version %s geladen. /warden zeigt das Fenster, /warden hilfe die Befehle.",

    EMPTY = "Niemand in Sichtweite.",
    EMPTY_HINT = "Hier erscheint jeder Spieler, dessen Namensplakette gerade sichtbar ist.",
    PLATES_OFF = "Freundliche Namensplaketten sind aus oder nur im Kampf sichtbar. "
        .. "Ohne sie kann das Addon niemanden sehen.",
    BTN_PLATES_ON = "Namensplaketten einschalten",
    PLATES_ENABLED = "Freundliche Namensplaketten sind jetzt immer sichtbar.",
    PLATES_COMBAT = "Im Kampf lassen sich die Namensplaketten nicht umstellen. Bitte danach nochmal.",

    DIST_UPTO = "bis %d m",
    DIST_BEYOND = "über %d m",
    DIST_UNKNOWN = "?",

    DIST_EXACT = "%d m",
    DIST_APPROX = "~%d m",
    DIST_EARSHOT = "in Hörweite",
    DIST_NEARBY = "in der Nähe",

    WARN_TEXT = "%s ist näher als %d m!",
    WARN_YARDS_SET = "Annäherungswarnung jetzt ab %d m.",

    MODE_UNJUST = "Unjust",
    MODE_JUST = "Just",
    MODE_UNJUST_SET = "Modus Unjust: Warnung, sobald jemand näher als %d m kommt.",
    MODE_JUST_SET = "Modus Just: keine Warnungen.",
    TIP_MODE_UNJUST = "Warnt, sobald jemand näher als %d m kommt.",
    TIP_MODE_JUST = "Keine Warnungen. Die Liste läuft weiter.",
    TIP_MODE_ACTIVE = "|cff60e060Aktiv|r",
    TIP_MODE_ACTIVATE = "Klicken, um diesen Modus zu aktivieren.",
    OPT_MODE_LABEL = "Modus:",

    SRC_GROUP = "Gruppe",
    SRC_LOCATOR = "TRP3-Ortung",
    SRC_SENSES = "Spürsinn",
    SOURCE_STATE = "%s: %s",
    LOCATOR_INTERVAL_SET = "TRP3-Ortung jetzt alle %d s.",
    NOTE_GROUP = "Gruppe",
    NOTE_LOCATOR = "geortet vor %d s",
    NOTE_SENSES = "gespürt vor %d s (%s)",
    SENSE_SAY = "spricht",
    SENSE_EMOTE = "emotet",
    SENSE_COMBAT = "kämpft oder zaubert",
    RADIUS_SET = "Die Liste zeigt Spieler im Umkreis von %d m.",
    STATE_ON = "an",
    STATE_OFF = "aus",
    LEVEL = "Stufe %s",
    HOSTILE = "feindlich",
    IC = "IC",
    OOC = "OOC",

    TIP_IC = "Im Charakter (Total RP 3)",
    TIP_OOC = "Nicht im Charakter (Total RP 3)",
    TIP_CHARNAME = "Charakter: %s",
    TIP_CLICK_PROFILE = "Linksklick: Total-RP-3-Profil öffnen",
    TIP_CLICK_WHISPER = "Rechtsklick: anflüstern",
    TIP_CLICK_LINK = "Umschalt+Linksklick: Name in den Chat",
    NO_PROFILE = "Von %s ist noch kein Total-RP-3-Profil bekannt.",
    TRP3_MISSING = "Total RP 3 ist nicht geladen, deshalb gibt es kein Profil zu %s.",

    WINDOW_RESET = "Fensterposition und -größe zurückgesetzt.",
    OPTIONS_FAILED = "Die Einstellungen findest du unter Interface > AddOns > CrimeWarden.",

    -- Einstellungen
    OPT_DESC = "Zeigt alle Spieler in deiner Nähe, deren Namensplakette sichtbar ist.",
    OPT_LOCK = "Fenster sperren",
    OPT_HIDE_HOSTILE = "Feindliche Spieler ausblenden",
    OPT_MINIMAP = "Minimap-Button anzeigen",
    OPT_SORT = "Sortierung: %s",
    SORT_DISTANCE = "nach Entfernung",
    SORT_NAME = "nach Name",
    OPT_RADIUS = "Umkreis: %d m",
    SECTION_LIST = "Liste",
    SECTION_WARN = "Warnung",
    OPT_WARN_YARDS = "Warnen ab: %d m",
    OPT_WARN_BANNER = "Banner in der Bildschirmmitte",
    OPT_WARN_SOUND = "Warnton",
    OPT_WARN_CHAT = "Chatzeile",
    OPT_WARN_GROUP = "Gruppenmitglieder ignorieren",
    SECTION_SOURCES = "Quellen",
    OPT_SRC_GROUP = "Gruppe auch hinter der Kamera",
    OPT_SRC_LOCATOR = "TRP3-Ortung (auch hinter der Kamera)",
    OPT_LOCATOR_INTERVAL = "Ortung alle %d s",
    OPT_SRC_SENSES = "Spürsinn: wer spricht, emotet, kämpft",
    BTN_RESET = "Fenster zurücksetzen",
    OPT_PLATES = "Namensplaketten: %s",
    PLATES_STATE_ON = "freundliche immer sichtbar",
    PLATES_STATE_OFF = "|cffff6060aus oder nur im Kampf|r",
    OPT_PLATES_HINT = "Das Addon sieht nur Spieler mit sichtbarer Namensplakette. Das Spiel erzeugt "
        .. "Plaketten nur für Spieler im Kamerabild: Wer hinter dir steht, erscheint erst, wenn die Kamera "
        .. "ihn erfasst. Eine weit herausgezoomte, steil von oben blickende Kamera deckt mehr Umgebung ab.",

    MINIMAP_TIP_LEFT = "Linksklick: Fenster ein- oder ausblenden",
    MINIMAP_TIP_RIGHT = "Rechtsklick: Einstellungen",
    MINIMAP_TIP_DRAG = "Ziehen: Button verschieben",

    -- Knöpfe und Erklärungen (Tooltips)
    BTN_GROUP = "Gruppe",
    BTN_LOCATOR = "Ortung",
    BTN_SENSES = "Spürsinn",
    BTN_OPTIONS = "Optionen",
    BTN_TOGGLE = "Umschalten",
    BTN_WINDOW_SHOW = "Fenster zeigen",
    BTN_WINDOW_HIDE = "Fenster verbergen",
    BTN_TEST_WARNING = "Testwarnung",
    TEST_NAME = "Testperson",
    SECTION_PLATES = "Namensplaketten",
    TIP_STATE_ON = "|cff60e060Eingeschaltet|r",
    TIP_STATE_OFF = "|cff909090Ausgeschaltet|r",
    TIP_CLICK_TOGGLE = "Klicken zum Ein- oder Ausschalten.",
    TIP_SRC_GROUP = "Zeigt deine Gruppenmitglieder mit genauer Entfernung in Metern, auch wenn sie hinter dir "
        .. "oder außerhalb des Kamerabilds stehen. In Dungeons nur ungefähr.",
    TIP_SRC_LOCATOR = "Fragt regelmäßig über Total RP 3 nach, wer auf deiner Karte ist (wie der Ortungsknopf "
        .. "der TRP3-Karte). Wer die TRP3-Ortung erlaubt, erscheint mit Entfernung ('~30 m'), auch hinter der "
        .. "Kamera, und kann eine Warnung auslösen. Die Position ist einige Sekunden alt; deine eigene Bewegung "
        .. "wird live eingerechnet. Wer die Ortung abgeschaltet hat oder kein TRP3 nutzt, fehlt hier.",
    TIP_SRC_SENSES = "Bemerkt, wer in der Nähe /sagt, emotet, kämpft oder zaubert, auch außer Sicht. Diese "
        .. "Spieler stehen blass in der Liste ('in Hörweite' oder 'in der Nähe', 'gespürt vor 12 s') und "
        .. "verschwinden nach 60 Sekunden. Ohne Entfernung, daher keine Warnung.",
    TIP_OPTIONS = "Öffnet die Einstellungen von CrimeWarden (Interface > AddOns > CrimeWarden).",
    HELP_TITLE = "CrimeWarden - Hilfe",
    HELP_BODY = "Zeigt, wer in deiner Nähe ist und mithören könnte.\n\n"
        .. "|cffffd100Liste:|r die Nächsten oben. Rot mit '!' = näher als die Warngrenze. '~' = per TRP3-Ortung, "
        .. "blass = gerade nicht zu sehen. Sprechblase = kann dich per /sagen hören. Würfel = Wahrnehmungswurf, "
        .. "ob dein Charakter die Person bemerkt (nur für dich sichtbar).\n\n"
        .. "|cffffd100Quellen:|r Namensplaketten (nur Spieler im Kamerabild) sowie Gruppe, Ortung und "
        .. "Spürsinn, oben in der Leiste ein- und ausschaltbar.\n\n"
        .. "|cffffd100Modus (Titelleiste):|r Just = keine Warnungen, Unjust = Warnung, sobald jemand zu "
        .. "nahe kommt.\n\n"
        .. "|cffffd100Zeile anklicken:|r links = TRP3-Profil, rechts = anflüstern, Umschalt+links = Name in den "
        .. "Chat.\n\n"
        .. "Alles Weitere unter 'Optionen'. Jeder Knopf erklärt sich, wenn du mit der Maus darauf zeigst.",
    TIP_CLOSE_TITLE = "Fenster schließen",
    TIP_CLOSE = "Blendet das Fenster aus. Warnungen laufen im Modus Unjust weiter. Wieder öffnen mit dem "
        .. "Minimap-Button, /warden oder 'Fenster zeigen' in den Optionen.",
    TIP_RESIZE_TITLE = "Größe ändern",
    TIP_RESIZE = "Ziehen, um das Fenster zu vergrößern oder zu verkleinern.",
    TIP_PLATES = "Schaltet die freundlichen Namensplaketten dauerhaft ein (auch außerhalb des Kampfes) und "
        .. "stellt ihre Sichtweite so weit wie nötig (Umkreis der Liste; bei 50 m Warngrenze 60 m, damit "
        .. "die Warnung wieder scharf werden kann). Ohne sie sieht CrimeWarden niemanden im "
        .. "Kamerabild. Geht nicht im Kampf. Ausgegraut = schon richtig eingestellt.",
    TIP_LOCK = "Das Fenster lässt sich nicht mehr verschieben oder in der Größe ändern.",
    TIP_HIDE_HOSTILE = "Spieler der feindlichen Fraktion erscheinen nicht in der Liste. Warnungen für sie "
        .. "gibt es weiterhin.",
    TIP_MINIMAP = "Zeigt den Knopf am Rand der Minimap: Linksklick öffnet das Fenster, Rechtsklick die "
        .. "Einstellungen.",
    TIP_SORT_TITLE = "Sortierung",
    TIP_SORT = "Wechselt zwischen 'nach Entfernung' (die Nächsten oben) und 'nach Name' (alphabetisch, "
        .. "RP-Name zuerst).",
    TIP_RADIUS_TITLE = "Umkreis der Liste",
    TIP_RADIUS = "Nur Spieler bis zu dieser Entfernung stehen in der Liste (10 bis 60 m). Spieler ohne "
        .. "bekannte Entfernung (Spürsinn) bleiben sichtbar.",
    TIP_RESET = "Setzt Position, Größe und Sperre des Fensters auf die Standardwerte zurück.",
    TIP_WINDOW = "Blendet das CrimeWarden-Fenster ein oder aus (wie /warden oder Linksklick auf den "
        .. "Minimap-Button).",
    TIP_WARN_YARDS_TITLE = "Warngrenze",
    TIP_WARN_YARDS = "Ab dieser Entfernung warnt der Modus Unjust (5 bis 50 m, Standard 50 m). Die Warnung "
        .. "kommt jedes Mal, wenn jemand von außen über die Grenze tritt; erneut erst, wenn er eine Stufe weiter "
        .. "weg war (bei 50 m: über 55 m). Beim Einschalten von Unjust oder einer neuen Grenze wird nicht "
        .. "jeder, der schon nah ist, auf einmal gemeldet.",
    OPT_SAY_RANGE = "Hörweite: %d m",
    TIP_SAY_RANGE_TITLE = "Hörweite (/sagen)",
    TIP_SAY_RANGE = "So weit reicht /sagen auf diesem Server (laut Spielerschaft 30 m). Spieler innerhalb "
        .. "dieser Entfernung bekommen in der Liste eine Sprechblase: Sie können dich hören. Wer etwas "
        .. "gesagt oder emotet hat, gilt ebenfalls als in Hörweite. Folgt die Hörweite dem Server-"
        .. "Regler 'Chat-Reichweite', sind diese Knöpfe gesperrt.",
    TIP_EARSHOT = "Kann dich per /sagen hören (bis %d m).",
    DICE_TITLE = "Wahrnehmungswurf",
    DICE_RULE = "Würfelt einen W20: Bemerkt dein Charakter diese Person? Je näher, desto leichter: bis 10 m ab 6, "
        .. "bis 30 m ab 11, darüber ab 16 (Entfernung unbekannt: ab 11). Hier: ab %d.",
    DICE_CLICK = "Klicken zum Würfeln.",
    DICE_PRIVATE = "Nur du siehst das Ergebnis. Pro Person ein Wurf alle 5 Minuten; so lange bleibt das Ergebnis "
        .. "stehen.",
    DICE_RESULT = "Gewürfelt: %d (ab %d): %s",
    DICE_NOTICED = "|cff60e060bemerkt|r",
    DICE_MISSED = "|cffff6060nicht bemerkt|r",
    DICE_SHORT_NOTICED = "|cff60e060bemerkt (%d)|r",
    DICE_SHORT_MISSED = "|cffff6060unbemerkt (%d)|r",
    DICE_LOCKED = "Nächster Wurf auf diese Person in %d s.",
    DICE_CHAT = "Wahrnehmungswurf auf %s: %s",
    DICE_CHAT_LOCKED = "Auf %s hast du schon gewürfelt. Nächster Wurf in %d s.",
    SAY_RANGE_SET = "Hörweite (/sagen) jetzt %d m.",
    OPT_SAY_RANGE_FOLLOW = "Hörweite: %d m (Regler)",
    SAY_RANGE_FOLLOWING = "Die Hörweite folgt gerade dem Server-Regler (%d m). Eingestellt sind %d m; die "
        .. "gelten, sobald du das abschaltest (/warden regler aus).",
    SECTION_CHATRANGE = "Chat-Reichweite (Server)",
    OPT_CHATRANGE_FOLLOW = "Hörweite vom Regler übernehmen",
    TIP_CHATRANGE_FOLLOW = "Der Server hat einen eigenen Regler 'Chat-Reichweite' (Niedrig bis Normal). Ist "
        .. "das an, liest CrimeWarden ihn aus und stellt die Hörweite passend ein. Umrechnung geschätzt: ganz "
        .. "rechts ('Normal') = 30 m, darunter anteilig. CrimeWarden liest nur, es verstellt den Regler nicht. "
        .. "Ist der Regler noch nicht gefunden (erst einmal öffnen), gilt die eingestellte Hörweite.",
    CHATRANGE_NOT_FOUND = "Regler noch nicht gefunden. Öffne ihn einmal im Spiel; bis dahin gilt die "
        .. "eingestellte Hörweite.",
    CHATRANGE_STATUS = "Regler steht auf %s (Bereich %s bis %s), geschätzt %d m.",
    CHATRANGE_STATE = "Hörweite vom Regler übernehmen: %s. %s",
    TIP_WARN_BANNER = "Zeigt die Warnung groß in der Bildschirmmitte, wie eine Schlachtzugswarnung.",
    TIP_WARN_SOUND = "Spielt bei jeder Warnung den Schlachtzugswarnungs-Ton.",
    TIP_WARN_CHAT = "Schreibt jede Warnung zusätzlich in den Chat.",
    TIP_WARN_GROUP = "Mitglieder deiner Gruppe lösen keine Warnung aus, damit Begleiter nicht ständig melden.",
    TIP_TEST_WARNING = "Zeigt eine Probewarnung mit den aktuellen Einstellungen (Banner, Ton, Chat).",
    TIP_INTERVAL_TITLE = "Abstand der Ortung",
    TIP_INTERVAL = "So oft fragt CrimeWarden über TRP3 nach (5 bis 60 s). Kürzer = aktueller, aber mehr "
        .. "Nachrichten an alle TRP3-Nutzer.",

    HELP_HEADER = "Befehle:",
    HELP_TOGGLE = "/warden - Fenster ein- oder ausblenden",
    HELP_OPTIONS = "/warden optionen - Einstellungen öffnen",
    HELP_MODE = "/warden just | /warden unjust - Modus mit oder ohne Warnungen",
    HELP_WARN_YARDS = "/warden warnung <Meter> - Warngrenze setzen (5 bis 50)",
    HELP_RADIUS = "/warden umkreis <Meter> - Umkreis der Liste (10 bis 60)",
    HELP_SAY_RANGE = "/warden hörweite <Meter> - /sagen-Hörweite für die Sprechblase (10 bis 60)",
    HELP_CHATRANGE = "/warden regler an|aus - Hörweite vom Server-Regler 'Chat-Reichweite' übernehmen",
    HELP_GROUP = "/warden gruppe an|aus - Gruppe auch hinter der Kamera",
    HELP_LOCATOR = "/warden ortung an|aus|<Sekunden> - TRP3-Ortung (5 bis 60 s)",
    HELP_SENSES = "/warden spürsinn an|aus - Spürsinn",
    HELP_PLATES = "/warden plaketten - freundliche Namensplaketten dauerhaft einschalten",
    HELP_RESET = "/warden reset - Fensterposition und -größe zurücksetzen",
    HELP_HELP = "/warden hilfe - diese Hilfe",
    UNKNOWN_CMD = "Unbekannter Befehl.",
}

local enUS = {
    TITLE = "CrimeWarden",
    TITLE_COUNT = "CrimeWarden (%d)",
    LOADED = "Version %s loaded. /warden shows the window, /warden help lists commands.",

    EMPTY = "Nobody in sight.",
    EMPTY_HINT = "Every player whose nameplate is currently visible appears here.",
    PLATES_OFF = "Friendly nameplates are off or only shown in combat. Without them the addon cannot see anyone.",
    BTN_PLATES_ON = "Enable nameplates",
    PLATES_ENABLED = "Friendly nameplates are now always visible.",
    PLATES_COMBAT = "Nameplate settings cannot be changed in combat. Please try again afterwards.",

    DIST_UPTO = "within %d yd",
    DIST_BEYOND = "beyond %d yd",

    DIST_EXACT = "%d yd",
    DIST_APPROX = "~%d yd",
    DIST_EARSHOT = "within earshot",
    DIST_NEARBY = "nearby",

    WARN_TEXT = "%s is closer than %d yd!",
    WARN_YARDS_SET = "Proximity warning now from %d yd.",

    MODE_UNJUST_SET = "Unjust mode: warning as soon as someone comes closer than %d yd.",
    MODE_JUST_SET = "Just mode: no warnings.",
    TIP_MODE_UNJUST = "Warns as soon as someone comes closer than %d yd.",
    TIP_MODE_JUST = "No warnings. The list keeps running.",
    TIP_MODE_ACTIVE = "|cff60e060Active|r",
    TIP_MODE_ACTIVATE = "Click to activate this mode.",
    OPT_MODE_LABEL = "Mode:",

    SRC_GROUP = "Group",
    SRC_LOCATOR = "TRP3 locating",
    SRC_SENSES = "Keen senses",
    LOCATOR_INTERVAL_SET = "TRP3 locating now every %d s.",
    NOTE_GROUP = "group",
    NOTE_LOCATOR = "located %d s ago",
    NOTE_SENSES = "sensed %d s ago (%s)",
    SENSE_SAY = "speaking",
    SENSE_EMOTE = "emoting",
    SENSE_COMBAT = "fighting or casting",
    RADIUS_SET = "The list shows players within %d yd.",
    STATE_ON = "on",
    STATE_OFF = "off",
    LEVEL = "Level %s",
    HOSTILE = "hostile",

    TIP_IC = "In character (Total RP 3)",
    TIP_OOC = "Out of character (Total RP 3)",
    TIP_CHARNAME = "Character: %s",
    TIP_CLICK_PROFILE = "Left-click: open Total RP 3 profile",
    TIP_CLICK_WHISPER = "Right-click: whisper",
    TIP_CLICK_LINK = "Shift+left-click: put name into chat",
    NO_PROFILE = "No Total RP 3 profile known for %s yet.",
    TRP3_MISSING = "Total RP 3 is not loaded, so there is no profile for %s.",

    WINDOW_RESET = "Window position and size reset.",
    OPTIONS_FAILED = "You can find the settings under Interface > AddOns > CrimeWarden.",

    OPT_DESC = "Shows every player near you whose nameplate is visible.",
    OPT_LOCK = "Lock window",
    OPT_HIDE_HOSTILE = "Hide hostile players",
    OPT_MINIMAP = "Show minimap button",
    OPT_SORT = "Sorting: %s",
    SORT_DISTANCE = "by distance",
    SORT_NAME = "by name",
    OPT_RADIUS = "Radius: %d yd",
    SECTION_LIST = "List",
    SECTION_WARN = "Warning",
    OPT_WARN_YARDS = "Warn from: %d yd",
    OPT_WARN_BANNER = "Banner in the middle of the screen",
    OPT_WARN_SOUND = "Warning sound",
    OPT_WARN_CHAT = "Chat line",
    OPT_WARN_GROUP = "Ignore group members",
    SECTION_SOURCES = "Sources",
    OPT_SRC_GROUP = "Group, also behind the camera",
    OPT_SRC_LOCATOR = "TRP3 locating (also behind the camera)",
    OPT_LOCATOR_INTERVAL = "Locate every %d s",
    OPT_SRC_SENSES = "Keen senses: who speaks, emotes, fights",
    BTN_RESET = "Reset window",
    OPT_PLATES = "Nameplates: %s",
    PLATES_STATE_ON = "friendly always visible",
    PLATES_STATE_OFF = "|cffff6060off or combat only|r",
    OPT_PLATES_HINT = "The addon only sees players with a visible nameplate. The game only creates "
        .. "nameplates for players in the camera view: someone behind you appears once the camera sees them. "
        .. "A camera zoomed far out and looking down steeply covers more of your surroundings.",

    MINIMAP_TIP_LEFT = "Left-click: show or hide window",
    MINIMAP_TIP_RIGHT = "Right-click: settings",
    MINIMAP_TIP_DRAG = "Drag: move button",

    BTN_GROUP = "Group",
    BTN_LOCATOR = "Locate",
    BTN_SENSES = "Senses",
    BTN_OPTIONS = "Options",
    BTN_TOGGLE = "Toggle",
    BTN_WINDOW_SHOW = "Show window",
    BTN_WINDOW_HIDE = "Hide window",
    BTN_TEST_WARNING = "Test warning",
    TEST_NAME = "Test person",
    SECTION_PLATES = "Nameplates",
    TIP_STATE_ON = "|cff60e060On|r",
    TIP_STATE_OFF = "|cff909090Off|r",
    TIP_CLICK_TOGGLE = "Click to turn on or off.",
    TIP_SRC_GROUP = "Shows your group members with exact distance in yards, even behind you or outside the "
        .. "camera view. Only approximate in dungeons.",
    TIP_SRC_LOCATOR = "Regularly asks via Total RP 3 who is on your map (like the locate button of the TRP3 "
        .. "map). Everyone who allows TRP3 locating appears with a distance ('~30 yd'), even behind the camera, "
        .. "and can trigger a warning. The position is a few seconds old; your own movement is applied live. "
        .. "Players who disabled locating or do not use TRP3 are missing here.",
    TIP_SRC_SENSES = "Notices who says, emotes, fights or casts nearby, even out of sight. These players are "
        .. "shown faded ('within earshot' or 'nearby', 'sensed 12 s ago') and disappear after 60 seconds. "
        .. "No distance, so no warning.",
    TIP_OPTIONS = "Opens the CrimeWarden settings (Interface > AddOns > CrimeWarden).",
    HELP_TITLE = "CrimeWarden - Help",
    HELP_BODY = "Shows who is near you and might overhear.\n\n"
        .. "|cffffd100List:|r closest on top. Red with '!' = closer than the warning distance. '~' = via TRP3 "
        .. "locating, faded = not currently visible. Speech bubble = can hear your /say. Dice = perception roll "
        .. "whether your character notices the person (only visible to you).\n\n"
        .. "|cffffd100Sources:|r nameplates (only players in the camera view) plus group, locating and senses, "
        .. "switchable in the bar at the top.\n\n"
        .. "|cffffd100Mode (title bar):|r Just = no warnings, Unjust = warning as soon as someone gets too "
        .. "close.\n\n"
        .. "|cffffd100Click a row:|r left = TRP3 profile, right = whisper, shift+left = name into chat.\n\n"
        .. "Everything else under 'Options'. Every button explains itself when you point at it.",
    TIP_CLOSE_TITLE = "Close window",
    TIP_CLOSE = "Hides the window. Warnings keep running in Unjust mode. Reopen with the minimap button, /warden "
        .. "or 'Show window' in the options.",
    TIP_RESIZE_TITLE = "Resize",
    TIP_RESIZE = "Drag to make the window larger or smaller.",
    TIP_PLATES = "Turns friendly nameplates on permanently (also out of combat) and sets their range as far "
        .. "as needed (list radius; 60 yd at a 50 yd warning distance so the warning can re-arm). "
        .. "Without them CrimeWarden sees nobody in the camera view. Not possible in combat. "
        .. "Greyed out = already set up correctly.",
    TIP_LOCK = "The window can no longer be moved or resized.",
    TIP_HIDE_HOSTILE = "Players of the hostile faction are not listed. Warnings for them still happen.",
    TIP_MINIMAP = "Shows the button at the edge of the minimap: left-click opens the window, right-click the "
        .. "settings.",
    TIP_SORT_TITLE = "Sorting",
    TIP_SORT = "Switches between 'by distance' (closest on top) and 'by name' (alphabetical, RP name first).",
    TIP_RADIUS_TITLE = "List radius",
    TIP_RADIUS = "Only players up to this distance are listed (10 to 60 yd). Players without a known distance "
        .. "(senses) stay visible.",
    TIP_RESET = "Resets position, size and lock of the window to the defaults.",
    TIP_WINDOW = "Shows or hides the CrimeWarden window (like /warden or left-clicking the minimap button).",
    TIP_WARN_YARDS_TITLE = "Warning distance",
    TIP_WARN_YARDS = "Unjust mode warns from this distance (5 to 50 yd, default 50 yd). It warns every time "
        .. "someone crosses the line from outside; again only after they were one step further away (at 50 yd: "
        .. "beyond 55 yd). Turning on Unjust or changing the distance does not report everyone who is "
        .. "already close all at once.",
    OPT_SAY_RANGE = "Earshot: %d yd",
    TIP_SAY_RANGE_TITLE = "Earshot (/say)",
    TIP_SAY_RANGE = "How far /say reaches on this server (30 yd according to the players). Players within this "
        .. "distance get a speech bubble in the list: they can hear you. Anyone who just said or emoted "
        .. "something also counts as within earshot. While earshot follows the server's chat range "
        .. "slider, these buttons are locked.",
    TIP_EARSHOT = "Can hear your /say (up to %d yd).",
    DICE_TITLE = "Perception roll",
    DICE_RULE = "Rolls a d20: does your character notice this person? The closer, the easier: up to 10 yd from 6, "
        .. "up to 30 yd from 11, beyond from 16 (unknown distance: from 11). Here: from %d.",
    DICE_CLICK = "Click to roll.",
    DICE_PRIVATE = "Only you see the result. One roll per person every 5 minutes; the result stays until then.",
    DICE_RESULT = "Rolled: %d (needs %d): %s",
    DICE_NOTICED = "|cff60e060noticed|r",
    DICE_MISSED = "|cffff6060not noticed|r",
    DICE_SHORT_NOTICED = "|cff60e060noticed (%d)|r",
    DICE_SHORT_MISSED = "|cffff6060unnoticed (%d)|r",
    DICE_LOCKED = "Next roll on this person in %d s.",
    DICE_CHAT = "Perception roll on %s: %s",
    DICE_CHAT_LOCKED = "You already rolled on %s. Next roll in %d s.",
    SAY_RANGE_SET = "Earshot (/say) now %d yd.",
    OPT_SAY_RANGE_FOLLOW = "Earshot: %d yd (slider)",
    SAY_RANGE_FOLLOWING = "Earshot currently follows the server's slider (%d yd). Set value is %d yd; it applies "
        .. "once you turn this off (/warden slider off).",
    SECTION_CHATRANGE = "Chat range (server)",
    OPT_CHATRANGE_FOLLOW = "Take earshot from the slider",
    TIP_CHATRANGE_FOLLOW = "The server has its own 'chat range' slider (low to normal). When on, CrimeWarden reads "
        .. "it and sets the earshot accordingly. Conversion is an estimate: far right ('normal') = 30 yd, "
        .. "proportional below. CrimeWarden only reads, it never moves the slider. Until the slider has been "
        .. "found (open it once), the set earshot applies.",
    CHATRANGE_NOT_FOUND = "Slider not found yet. Open it once in game; until then the set earshot applies.",
    CHATRANGE_STATUS = "Slider is at %s (range %s to %s), estimated %d yd.",
    CHATRANGE_STATE = "Take earshot from the slider: %s. %s",
    TIP_WARN_BANNER = "Shows the warning large in the middle of the screen, like a raid warning.",
    TIP_WARN_SOUND = "Plays the raid warning sound for every warning.",
    TIP_WARN_CHAT = "Also writes every warning into the chat.",
    TIP_WARN_GROUP = "Members of your group do not trigger warnings, so companions do not keep alerting.",
    TIP_TEST_WARNING = "Shows a sample warning with the current settings (banner, sound, chat).",
    TIP_INTERVAL_TITLE = "Locating interval",
    TIP_INTERVAL = "How often CrimeWarden asks via TRP3 (5 to 60 s). Shorter = more current, but more "
        .. "messages to all TRP3 users.",

    HELP_HEADER = "Commands:",
    HELP_TOGGLE = "/warden - show or hide the window",
    HELP_OPTIONS = "/warden options - open settings",
    HELP_MODE = "/warden just | /warden unjust - mode with or without warnings",
    HELP_WARN_YARDS = "/warden warn <yards> - set the warning distance (5 to 50)",
    HELP_RADIUS = "/warden radius <yards> - list radius (10 to 60)",
    HELP_SAY_RANGE = "/warden earshot <yards> - /say earshot for the speech bubble (10 to 60)",
    HELP_CHATRANGE = "/warden slider on|off - take earshot from the server's 'chat range' slider",
    HELP_GROUP = "/warden group on|off - group, also behind the camera",
    HELP_LOCATOR = "/warden locate on|off|<seconds> - TRP3 locating (5 to 60 s)",
    HELP_SENSES = "/warden senses on|off - keen senses",
    HELP_PLATES = "/warden plates - always show friendly nameplates",
    HELP_RESET = "/warden reset - reset window position and size",
    HELP_HELP = "/warden help - this help",
    UNKNOWN_CMD = "Unknown command.",
}

local L = deDE
if GetLocale and GetLocale() ~= "deDE" then
    L = setmetatable(enUS, { __index = deDE })
end
ns.L = L
