# CrimeWarden

Addon für Crime-Rollenspiel in World of Warcraft. Es wurde für Retail entworfen und für den älteren Client 9.2.7 (Interface 90207) des RP-Servers Schattenhain verfügbar gemacht. Es beantwortet eine Frage, die im Crime-RP ständig aufkommt: *Wer ist gerade in meiner Nähe und könnte mithören?* So kann man IC entscheiden, wem man etwas verrät und wann man besser schweigt, statt es per OOC-Wissen zu raten.

> **Hinweis zur Entstehung:** Der Autor kann selbst nicht programmieren. CrimeWarden ist in Zusammenarbeit mit Claude, einer KI von Anthropic, entstanden: Claude hat den gesamten Code geschrieben, der Autor hat Wünsche und Vorstellungen eingebracht und im Spiel getestet. Wer technisch etwas findet oder Bedenken hat, meldet sich bitte gern.

## Was es macht

- **Liste** der Spieler im Umkreis (Standard 50 m): RP-Name und IC/OOC aus Total RP 3, ungefähre Entfernung, Klasse, Volk, Stufe, Gilde.
- **Sprechblase** bei allen, die innerhalb der /sagen-Hörweite stehen (Standard 30 m). Die Hörweite folgt auf Wunsch dem Server-Regler „Chat-Reichweite“.
- **Zwei Modi** über einen Schalter in der Titelleiste:
  - **Just:** nur die Liste.
  - **Unjust:** zusätzlich eine Warnung (Banner, Ton, Chatzeile), sobald jemand näher als eine einstellbare Grenze kommt (5–50 m).
- **Wahrnehmungswurf** pro Eintrag (W20, je näher, desto leichter). Das Ergebnis sieht nur, wer würfelt. Pro Person ist nur ein Wurf alle fünf Minuten möglich.
- Jede Funktion ist als Knopf erreichbar und per Tooltip erklärt. Befehle: `/warden hilfe`.

## Woher die Daten kommen

Ausschließlich über die normale Addon-Schnittstelle von WoW. Es gibt kein Speicherauslesen und keine Eingriffe in den Client.

| Quelle | Was | Bemerkung |
|---|---|---|
| Namensplaketten | Spieler im Kamerabild | Entfernung in Stufen über `IsItemInRange` (Gegenstandsliste nach LibRangeCheck-3.0) |
| Gruppe | eigene Gruppenmitglieder | Position über `UnitPosition`, auch hinter der Kamera |
| TRP3-Ortung | TRP3-Nutzer auf derselben Karte | dieselbe Ortungsanfrage wie die TRP3-Karte (`C_SCAN`). Es antworten nur Spieler, die die TRP3-Ortung erlaubt haben. Standard alle 10 s, einstellbar 5–60 s |
| Spürsinn | wer in der Nähe /sagt, emotet oder kämpft | nur, was der eigene Client ohnehin empfängt |

Jede Zusatzquelle lässt sich einzeln abschalten.

## Berührungspunkte mit Server und anderen Spielern

- Verschickt wird nur die TRP3-Ortungsanfrage sowie gedrosselte TRP3-Profilanfragen (höchstens eine alle 2 s, pro Spieler alle 5 Minuten). Beides pausiert bei offener Weltkarte und im Leerlauf (Fenster zu, Modus Just).
- Antworten auf CrimeWardens Ortungsanfragen werden aus der Ergebnisliste der TRP3-Karte herausgefiltert, damit die TRP3-Kartensuche nur die Spieler der gesuchten Karte zeigt.
- Der Server-Regler „Chat-Reichweite“ wird nur **gelesen**, nie verstellt.
- Der Befehl `/warden` kollidiert mit keinem Blizzard-Befehl. Das prüfen die Tests gegen eine Liste aller deutschen und englischen Chatbefehle.

## Fairness

CrimeWarden liefert OOC-Wissen. Wer weiß, dass jemand mithört, ist versucht, anders weiterzuspielen als ohne dieses Wissen, auch wenn der eigene Charakter den Lauscher IC nicht bemerkt hätte. Das wäre Metagaming, und das soll das Addon nicht fördern. Ob ein Charakter jemanden bemerkt, sollte im Spiel entschieden werden, etwa per Emote oder mit dem Wahrnehmungswurf. Fair damit umzugehen, liegt bei jedem, der es benutzt.

## Grenzen

- WoW erzeugt Namensplaketten nur für Spieler im Kamerabild. Wer hinter einem steht, erscheint nur über Gruppe, TRP3-Ortung oder Spürsinn.
- Entfernungen sind Näherungswerte (Stufen von 5 m, TRP3-Ortung einige Sekunden alt).
- Im Kampf misst WoW bei nicht angreifbaren Spielern keine Entfernung; dort gibt es für sie keine Warnung.

## Installation

1. Den Ordner `CrimeWarden` nach `World of Warcraft\…\Interface\AddOns\` kopieren.
2. Im Spiel `/reload`. Im Chat erscheint „CrimeWarden Version … geladen“.
3. `/warden` öffnet das Fenster, `/warden optionen` die Einstellungen.

Total RP 3 ist optional (für RP-Namen, IC/OOC, Ortung und Profile).

## Aufbau des Codes

| Pfad | Inhalt |
|---|---|
| `CrimeWarden/Logic/` | Reine Logik ohne WoW-API: Listen und Zusammenführung, Entfernungsstufen, Warnlogik, Wahrnehmungswurf, Umrechnung der Chat-Reichweite, Anfrage-Drossel |
| `CrimeWarden/Scanner.lua` | Namensplaketten, Sekundentakt für alle Quellen |
| `CrimeWarden/Group.lua`, `Locator.lua`, `Senses.lua` | Quellen Gruppe, TRP3-Ortung, Spürsinn |
| `CrimeWarden/Warden.lua` | Annäherungswarnung (Takt 0,2 s) |
| `CrimeWarden/Distance.lua` | Entfernungsmessung |
| `CrimeWarden/ChatRangeSync.lua` | liest den Server-Regler „Chat-Reichweite“ |
| `CrimeWarden/TRP3.lua` | Anbindung an Total RP 3 2.3 |
| `CrimeWarden/UI.lua`, `Config.lua`, `Minimap.lua` | Fenster, Einstellungsseite, Minimap-Knopf |
| `CrimeWarden/Locale.lua` | alle Texte (Deutsch, Englisch) |
| `tests/` | automatische Tests (siehe unten) |

## Tests

```
luajit tests/crimewarden_run.lua    # Logik-Tests
luajit tests/crimewarden_sim.lua    # lädt das ganze Addon mit nachgebauter WoW- und TRP3-API
luacheck .                          # statische Prüfung
```

Die Simulation spielt rund 230 Abläufe durch, darunter Warnungen, alle Quellen, Einstellungen, Tooltips an jedem Bedienelement und das Zusammenspiel mit der TRP3-Karte. Sie ersetzt keinen Test im Spiel: Ob zum Beispiel alle Messgegenstände im 9.2.7-Client funktionieren, zeigt nur das Spiel selbst.

## Stand

Version 0.7.2, Testphase.

## Ausblick

Ideen für ein mögliches Klassensystem (Berufungen statt Spielklassen, Sinne der Völker, später vielleicht eine Anbindung an Zauberlisten und Profile des Servers) stehen in [ZUKUNFTSPLAENE.md](ZUKUNFTSPLAENE.md).

## Lizenz

Keine Lizenz: Alle Rechte bleiben beim Autor. Ansehen und Prüfen des Codes ist ausdrücklich erwünscht. Für eine Weiterverwendung bitte vorher fragen.
