# Molnfiskarna — första fiskeprototypen

En liten Roblox-prototyp med serverstyrt fiske, en molnö, en brygga och Puffis.
Gränssnittet skapas automatiskt och har inmatning för mus, E-tangenten och touch.
Varje spelare har egna fiskeförsök och en egen fångsträknare.

**Fångster gäller bara den aktuella sessionen.** Valuta, akvarium, uppgraderingar,
sparande och poängtavla kommer i senare steg.

## Öppna i Roblox Studio på Windows

1. Ladda ned `Molnfiskarna-Prototype.zip` och välj **Extrahera alla** i Windows.
2. Öppna `Molnfiskarna-Prototype.rbxlx` i Roblox Studio, exempelvis via funktionen
   för att öppna en plats från fil i File-menyn.
3. Starta **Play**, så att din avatar visas. Använd inte enbart Run: klientkoden
   och gränssnittet behöver en spelare.
4. Gå till den blå rutan längst ut på bryggan.
5. Klicka/tryck på **FISKA** eller tryck E och släpp.
6. Efter napp: håll inne knappen eller E. Släpp när den vita markören är i
   fångstområdet. Guld ger kvaliteten Strålande, blått Fin och grönt Normal.
7. Resultatet och antalet fångster visas. Försök igen och förbättra kvaliteten.

Ön skapas av servern när Play startar. I redigeringsläget ser platsen därför
tom ut. Om du vill spara projektet på Roblox, spara det som en separat privat
testplats och ge din medutvecklare redigeringsbehörighet.

Du behöver inga API-nycklar, externa grafikpaket, betalda plugins eller
DataStore-inställningar för denna prototyp.

Om chatten visar "Det gick inte att ladda ner artefakten" finns även en offline-
överföring för Windows. `python tools/build_windows_transfer.py` skapar ett
självförsörjande PowerShell-block i `artifacts/Skapa-Molnfiskarna.ps1` som kan
klistras in som text från chatten. Det packar upp samma platsfil lokalt, verifierar
SHA-256 och sparar den med ett nytt namn på skrivbordet. Det hämtar inget från
nätet och kör inte spelfilens Luau-kod. Användaren öppnar filen i Studio efteråt.

## Testa två spelare och touch

- Använd Studios lokala server-/klienttest med två spelare. Båda ska kunna
  fånga fisk samtidigt utan att räknarna påverkar varandra.
- Prova olika telefon- och surfplatteformat i Studios enhetsemulator.
- Prova även riktig telefon/iPad före godkännande av touchkänsla och prestanda.
  Ett lokalt servertest är inte samma sak som att två Windows-datorer spelar
  tillsammans. För gemensamt spel mellan enheter behövs en privat publicerad
  testupplevelse och lämplig åtkomst för testkontona.
- Följ [Studio-testlistan](docs/studio-testlista.md), inklusive avbrott och felvägar.

## Filer och ansvar

| Fil | Ansvar |
| --- | --- |
| `src/shared/FishingConfig.luau` | Tider, avstånd och prototypläge |
| `src/shared/FishingRules.luau` | Kvalitetsnivåer; samma zoner visas i UI |
| `src/server/FishingEngine.luau` | Testbar tillståndsmaskin, begränsning av anrop, fångster |
| `src/server/FishingService.luau` | Roblox-spelare, avstånd, RemoteEvents och serverklocka |
| `src/server/PrototypeWorld.luau` | Enkel ö, brygga och spawn |
| `src/server/FishingServer.server.luau` | Startar serverdelen |
| `src/client/FishingClient.client.luau` | Gränssnitt, mätare, mus/tangent/touch |

Skripten i Git är källan för den genererade platsfilen. För bestående ändringar:
ändra `.luau`-filerna och bygg en ny platsfil. Förändringar gjorda inne i Studio
skrivs inte tillbaka till Git automatiskt. Bestäm en gemensam version innan ni
båda ändrar samma skript. Rojo-synk är ännu inte konfigurerad.

För att koppla in en egen värld senare: sätt `CreatePrototypeWorld = false` i
FishingConfig och skapa `Workspace.World.FishingSpot` som en förankrad Part.
En egen värld och spawn måste då sparas i Studio. Python-byggaren återskapar
bara skriptplatsen; den läser inte tillbaka egna banbyggen från Studio.

## Bygga från källkod, valfritt

Python 3.10+ räcker. Inga Python-paket behöver installeras.

```powershell
python tools/build_place.py
python tools/package_release.py
```

Resultaten finns i `artifacts`. Python behövs inte för att öppna den redan
byggda `.rbxlx`-filen. Sluta inte redigera en sparad egen värld för att öppna en
ny genererad version utan att först spara ditt arbete.

## Automatiska kontroller

Med officiella Luau-kommandoradsverktyg installerade:

```powershell
luau tests/fishing_engine.spec.luau
python -m unittest discover -s tests -p "test_*.py" -v
```

Luau-testsviten kör produktionskoden för regler och tillståndsmaskin, utan
Roblox-mockar. Byggtesterna kontrollerar skriptinnehåll, placering, instanstyper
och att upprepade byggen ger samma fil. Detta ersätter inte Play-tester i Studio.

## Verifiering och begränsningar

Kontroller som har körts i molnmiljön redovisas i
[testprotokollet](docs/studio-testlista.md). Roblox Studio kan inte köras här.
Världen, UI, faktisk nätverkskörning och enhetskontroller behöver därför provas
i Studio innan prototypen kallas speltestad.

Servern avgör kvalitet från tiden då släppmeddelandet tas emot. Det gör att
nätfördröjning kan förskjuta upplevelsen av mätaren. Zonerna är breda för den
första prototypen; testa med fördröjning före tävlings- eller ekonomifunktioner.
Serverkontrollerna begränsar ogiltiga anrop men bevisar inte mänsklig inmatning
eller stoppar alla rörelseexploits. Inga beständiga belöningar införs här.

Design och arbetssätt finns i [speldesignen](docs/molnfiskarna-gdd.md) och
[första veckoplanen](docs/forsta-veckan.md).
