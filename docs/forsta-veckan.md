# Molnfiskarna — första veckan och projektstruktur

Status: arbetsplan med en nu implementerad första fiskeprototyp. Regler och
platsbyggare har automatiska tester; körning i Roblox Studio återstår.
Börja med [startguiden](../README.md) för att öppna den färdiga filen. De manuella
Studio-övningarna nedan är till för att lära er verktyget, inte ett installationskrav.

## Tid och första milstolpe

Vi planerar för 30 timmar per vecka för hela teamet, ungefär 15 timmar var.
En gemensam session på tre timmar använder sex persontimmar.

Veckans mål är en enkel testplats och en första fiskeprototyp, inte hela spelet.
Om Studio tar mer tid att lära sig får fisket fortsätta nästa vecka.
Lägg inte till fler funktioner för att kompensera för en försenad grundfunktion.

En försiktig första budget för en liten testbar MVP är 6–10 veckor, alltså
180–300 persontimmar. Det är ett planeringsintervall, inte ett leveranslöfte
eller en uppskattning av tid till offentlig release. Efter de första två
veckornas testresultat görs en ny uppskattning.

## En gemensam arbetsplats

Använd ett gemensamt privat Roblox-projekt i Studio. En person äger projektet
och ger den andra redigeringsbehörighet med Robloxs samarbetsfunktioner.
Båda arbetar med egna Roblox-konton. Kontrollera att båda faktiskt kan öppna
och redigera samma plats; ett lokalt filnamn hos var och en räcker inte.

Prototypens källkod finns i Git. En byggare bäddar in den i en separat platsfil
som kan öppnas i Studio. Bestående kodändringar görs i källfilerna och byggs om;
Studio skickar inte ändringar tillbaka till Git. Undvik två manuellt underhållna
versioner av samma skript.

Innan flera kodsystem byggs bör vi införa löpande Git/Studio-synk, lämpligen
med Rojo och en uttrycklig gräns mot värld/UI som redigeras i Studio. Det är
ett eget steg före fas B; ingen sådan synk är konfigurerad eller antagen här.
Den nuvarande platsbyggaren räcker för att öppna och prova fiskeprototypen.

Efter varje gemensam milstolpe sparar projektägaren också en daterad lokal
platskopia utanför Git-repot. En platsfil är inte lämplig för att lösa två
utvecklares samtidiga textkonflikter. Bestäm ägare för varje objektområde.

## Första Studio-sessionen — tre timmar tillsammans

Menynamn och placering kan skilja sig mellan Studio-versioner och språk.
Följ funktionerna nedan; de är inte ett verifierat klicktest av er version.

1. Skapa ett enkelt Baseplate-projekt och spara det med namnet Molnfiskarna
   Prototype. Om projektet sparas till Roblox ska det förbli privat under arbetet.
2. Ge den andra utvecklaren redigeringsbehörighet och öppna samma plats på båda
   datorerna. Prova att en liten ändring syns för den andra.
3. Öppna panelerna Explorer, Properties och Output.
   Explorer visar objekten; Properties ändrar det valda objektet; Output
   visar meddelanden och fel när spelet körs.
4. Skapa en Folder med namnet World i Workspace. Lägg en enkel plattform och
   en brygga där, byggda med Parts. Sätt Anchored på byggdelarna så att de står kvar.
5. Behåll en SpawnLocation ovanför en säker yta. Starta Play, gå från spawn till
   bryggan och stoppa testet. Redigera sedan i vanligt redigeringsläge så att
   ändringarna inte bara gäller den tillfälliga testsessionen.
6. Lägg en mindre förankrad Part vid bryggan, med namnet FishingSpot och
   CanCollide av. Den markerar fiskeplatsen; den har ännu ingen funktion.
7. Skapa en ScreenGui med namnet FishingGui i StarterGui. Lägg dit en stor
   TextButton med namnet ActionButton och texten Fiska samt en TextLabel
   med namnet StatusLabel. Använd panelen för olika enheter för att kontrollera
   placeringen. Knapparna fungerar först när klientkoden byggs.
8. Prova Studios testläge med en lokal server och två klienter. Kontrollera att
   båda kan röra sig och nå bryggan. Det kontrollerar miljön, inte fiskesystemet.
9. Spara arbetet och skriv ned en sak som var oklar för varje utvecklare.

Godkänt efter sessionen: båda kan hitta objekten, köra och stoppa ett test,
förstå vilka ändringar som sparas och nå samma brygga med varsin testspelare.

## Teknisk struktur för första fiskefunktionen

Det här är strukturen i den genererade prototypen. Testvärlden, gränssnittet
och RemoteEvents skapas när Play körs; de övriga skripten är inbäddade i platsfilen.

```text
Workspace
  MolnfiskarnaPrototype          Folder; enkel ö, brygga och spawn
    FishingSpot                 Part; servern kontrollerar avstånd hit

ReplicatedStorage
  FishingShared                 Folder
    FishingConfig               ModuleScript; justerbara tider och avstånd
    FishingRules                ModuleScript; kvalitetsområden
  FishingRemotes                Folder
    FishingAction               RemoteEvent; Start, Hold, Release, Cancel, Sync
    FishingState                RemoteEvent; server skickar tillstånd/resultat

ServerScriptService
  FishingServer                 Script; startar fiskesystemet och kopplar meddelanden
  FishingService                ModuleScript; tillstånd, regler och resultat
  FishingEngine                 ModuleScript; ren, testbar tillståndsmaskin
  PrototypeWorld                ModuleScript; skapar testvärlden

StarterPlayer
  StarterPlayerScripts
    FishingClient               LocalScript; inmatning, UI och visuell mätare

Players/<spelare>/PlayerGui
  MolnfiskarnaFishing            ScreenGui; skapas av klienten
    FishingPanel                Frame
      ActionButton              TextButton
      Status                    TextLabel
      Meter                     Frame; mätare och målområden
```

I första prototypen finns bara en provisorisk fiskart och inget sparande.
FishingEngine äger ett pågående försök per spelare. Klienten visar ett resultat
som servern har beslutat; den skapar inte sin egen belöning.

### Flöde och ansvar

1. Spelaren väljer Fiska. Klienten skickar en begäran utan föreslagen fisk,
   kvalitet eller myntbelöning.
2. Servern kontrollerar plats, avstånd, att spelaren kan fiska och att inget
   annat försök pågår. Servern begränsar också hur ofta begäran får skickas.
3. Servern startar ett försök med ett eget ID, definierade tidsgränser och en
   kort förberedelsetid så att klienten hinner visa fiskemomentet.
4. Vid napp begär klienten Hold. Servern bestämmer mätarens starttid. Klienten
   visar mätaren och skickar sedan Release för det aktuella försöket.
5. Servern beräknar och validerar utfallet enligt sina tidsregler, avslutar
   försöket och skickar resultatet. Dubbla eller gamla meddelanden ignoreras.

Tillstånd: redo → förberedelse → fiskemoment → resultat → redo.
Försök behöver även avslutas vid timeout, död, frånkoppling eller om spelaren
lämnar fiskeplatsen. Ett missat meddelande får inte låsa spelaren för alltid.

Servervalidering bevisar inte att en människa tryckte. Automatiserad inmatning
är fortfarande en risk. Tidsregler och rimlig tolerans för nätfördröjning ska
provas; belöna inte ett klientrapporterat perfekt resultat utan kontroll.

### Inmatning på dator och touch

ActionButton växlar tydligt mellan att starta försöket och att hålla/släppa.
På dator ges motsvarande mus- eller tangentkontroll. På touch följs samma
finger från nedtryckning till släpp, även om fingret hamnar utanför knappen.
Dubbeltryckningar, avbruten beröring och förlorat fönsterfokus måste hanteras.

Alla inmatningssätt använder samma lokala handlingar och samma serverregler.
InputObject-avbrott, släpp utanför knappen och tappat fönsterfokus hanteras i
klientkoden men behöver fortfarande verifieras i faktisk Studio-körning.

## Veckobudget: 30 persontimmar

| Uppgift | Ansvar | Budget | Beroende |
| --- | --- | ---: | --- |
| Gemensam Studio-session ovan | A + B | 6 h totalt | Två fungerande Studio-installationer |
| Enkel testmiljö och statisk UI | B | 6 h | Gemensamt projekt |
| Första server- och klientfunktion, med vägledning | A | 8 h | Fastställda fiskeregler och kodimplementation |
| Koppla UI och justera touchlayout | B | 4 h | Körbar fiskefunktion |
| Gemensamt funktionstest och förenkling | A + B | 6 h totalt | Sammanfogad prototyp |

A får cirka 14 timmar och B cirka 16. Byt roller i nästa fas så att båda lär
sig både Studio och grundläggande kod. Nu när första koden finns kan de avsatta
kodtimmarna användas för genomgång, provspelning och justering tillsammans.

## Test och godkännandekriterier för fas A

Testa både lyckade och avbrutna försök:

- En spelare kan starta, få ett resultat och börja om flera gånger utan fel.
- Normal fångst fungerar utan perfekt timing.
- En spelare utanför fiskeplatsen får inte börja fiska.
- Upprepade tryck startar inte flera samtidiga försök.
- Två lokala testklienter får separata försök och separata resultat.
- Att gå därifrån, dö, släppa utanför knappen eller tappa fokus låser inte systemet.
- Både mus och emulerad touch fungerar. Riktiga enheter behövs för att verifiera
  faktisk touchkänsla och prestanda; emulering räcker inte för det påståendet.
- Output visar inga återkommande fel i normal spelgång.

Låt någon som inte byggt funktionen försöka utan muntliga instruktioner.
Anteckna om personen förstår handlingen, lyckas och vill försöka igen.
Om fisket känns otydligt eller tråkigt justeras det före ekonomi och sparande.

## Efter första prototypen

Nästa fas delar upp ansvaret i små moduler för artdefinitioner, spelarprofil,
ekonomi, uppgraderingar och akvarievisning. En central serverdel ska samordna
belöningar och profiländringar; klienten ska inte kedja egna köp och belöningar.
Exakt profilformat och hantering av samtidiga sessioner beslutas före sparandet.

Inför Git/Studio-synk innan den uppdelningen genomförs. Lägg inte till externa
ramverk, ett stort nätverkslager eller analysverktyg bara för att fylla mappar.
Arkitekturen byggs ut när nästa fungerande spelsteg behöver den.
