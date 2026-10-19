# Molnfiskarna — första speldesignen

Status: designmål för spelet. En första fiskeprototyp finns nu i `src` och kan
byggas till en Studio-fil. Reglerna har automatiska tester; Roblox-körning
och enhetstester återstår. Se [startguiden](../README.md) för den aktuella leveransen.

## 1. Beslut och mål

Molnfiskarna är ett socialt fiskespel på svävande öar. Spelaren fångar fantasifiskar,
upptäcker arter och bygger ett eget molnakvarium som andra kan besöka.
Tävlingen handlar om att utveckla sin samling och förbättra sina fångster.

Utgångspunkter från teamet:

- Två utvecklare med mycket liten erfarenhet av Roblox Studio och Luau.
- Teamet har cirka 30 timmar per vecka tillsammans och Roblox Studio på två
  Windows-datorer. Tillgänglighet fördelas efter behov; cirka 15 timmar var är
  planeringsantagandet.
- Dator, mobiltelefon och iPad ska stödjas från början.
- Målgruppen är barn som redan spelar Roblox. Exakt åldersspann är inte bestämt.
- Multiplayer ska främst ge progressiv tävling, utan strid mellan spelare.
- Design före implementation; en fungerande liten version före expansion.

Designhypotes: ett lättlärt fiskemoment, en synlig personlig samling och tydliga
nästa mål kan skapa en rolig helhet. Det är inte ett påstående om uppmätt retention
eller aktuell marknadsefterfrågan. Prototypen ska pröva hypotesen.

## 2. Spelarlöfte och särdrag

"Fånga märkliga fiskar ur molnen och visa upp din egen levande himmelsvärld."

Molnakvariet ska synligt förändras när samlingen växer. Fiskarna svävar i ett
avgränsat molnlandskap med växter, ljus och enkla rörelser. Det är spelets visuella
signatur. Första versionen använder fasta visningsplatser, utan fri byggfunktion.

Fisket behöver vara roligt innan en stor ekonomi eller många arter byggs.
Fler belöningar löser inte ett fiskemoment som känns tråkigt.

## 3. Grundloop och första spelminuterna

1. Gå till en markerad plats vid en molnbrygga.
2. Tryck på Fiska för att kasta ut automatiskt.
3. Läs en kort, tydlig signal när fisken nappar.
4. Håll inne och släpp när en mätare ligger i ett brett markerat område.
5. Se fångsten, kvaliteten och intjänade mynt.
6. Upptäckta arter registreras i samlingen; välj vilka som visas i akvariet.
7. Köp en begriplig uppgradering och försök förbättra nästa fångst.

Första försöket ska vara hjälpsamt och förklaras med kort text och bild.
Misslyckanden förbrukar ingen köpt utrustning och förstör inga framsteg.
En normal lyckad fångst behöver vara tillgänglig även för ovana spelare.

Mål att testa, inte färdiga löften:

- Första fångsten inom ungefär en minut utan muntlig handledning.
- Första meningsfulla uppgraderingen inom ungefär fem minuter.
- Spelaren kan efter några fångster förklara sitt nästa mål.

Fisket sker från fasta platser. Fri flygning, båtar, simning och kast med fri
fysik ingår inte i första versionen.

## 4. Fiskemekanik

Samma handling används på alla plattformar: tryck, håll, släpp.
På dator kan mus och en tydligt visad tangent användas. Touch kräver ingen hover,
liten träffyta eller snabb växling mellan flera knappar.

Mätaren har ett brett område för normal fångst och ett mindre bonusområde.
Kvalitetsnivåerna är Normal, Fin och Strålande. Kvalitet förklaras med ord och
symboler, inte bara färg. Bonusområdet är ett skicklighetsmål; vanlig progression
ska fungera utan perfekta träffar. Exakt hastighet och tolerans avgörs i tester.

Ingen lång serie snabba tryck, inget obligatoriskt ljud och ingen smal
reaktionströskel ska krävas för grundläggande framsteg.

## 5. Arter och progression

Första innehållsmålet är sex arter och två fiskeplatser på en gemensam ö.
Arbetsnamn: Puffis, Solfenan, Regndroppen, Vindvingen, Ålsken och Stjärtsvansen.
Namn och utseenden kan ändras efter visuella tester.

De första tre arterna finns vid startbryggan. Den andra platsen låses upp genom
en tydligt angiven verkstadsuppgradering och introducerar de övriga tre.
Platsen får en annan utsikt och ett något annorlunda tempo, men samma kontroller.

Samlingen visar var en art kan hittas. Upptäckter kommer från fiskeplatsens
fångsttabell; kvalitet påverkas av fiskemomentet. Slump ska inte beskrivas som
skicklighet. Den sista arten får inte kräva orimligt många upprepningar.
En regel för att begränsa långa serier av dubletter kan läggas till om tester
visar behov; första versionen ska börja med enkla, synliga regler.

Spara högsta kvalitet per art. Spelaren behöver inte hantera ett stort lager av
individuella dubletter. Upptäckta arter kan väljas för akvariets visningsplatser.

Ingen rebirth i första versionen. Spelarens samling ska kännas beständig.

## 6. Ekonomi och uppgraderingar

En valuta: molnmynt. Varje godkänd fångst ger mynt automatiskt.
Första upptäckten av en art kan ge en tydlig engångsbonus.
Ingen manuell försäljning krävs och samlingsregistreringen försvinner inte.

Tre uppgraderingssteg räcker i första versionen:

1. Stabilare spö: något större område för en normal fångst.
2. Ny brygglicens: låser upp andra fiskeplatsen och fler arter.
3. Större molnakvarium: fler fasta visningsplatser och en synlig miljöförändring.

Visa kostnad och faktisk effekt före köp. Slutliga priser, utbetalningar och
fångsttider bestäms först efter att fiskeloopen har testats. Det behövs inga
exakta stora siffertabeller innan vi vet vad som känns bra.

Akvariet ger ingen passiv valuta i första versionen. Spelandet ska bära ekonomin;
akvariet ger ägande, uttryck och ett synligt mål.

## 7. Progressiv tävling utan PvP

Första versionen använder Upptäckarpoäng:

- Varje art ger 1, 2 eller 3 poäng utifrån spelarens bästa fångstkvalitet.
- Bara bästa kvalitet per art räknas; samma vanliga fångst kan inte farmas för
  obegränsat antal tävlingspoäng.
- Med sex arter är första versionens maxpoäng 18.
- Bästa resultat sparas och kan förbättras, utan poängförlust.
- En tavla visar spelarna på den aktuella servern. Lika poäng ger delad placering.

Tavlan mäter samlingsframsteg, inte en match med lika startvillkor. En äldre
spelare kan ligga före en ny. Det ska framgå tydligt. Visa också egna saknade
arter och nästa kvalitetsmål, så att nya spelare har något uppnåeligt att sikta på.

Spelare delar inte en ändlig fiskpopulation. Ingen kan stjäla fångster,
blockera andras framsteg eller skada deras akvarium. Separera fiskeplatsernas
interaktioner och undvik att spelarkollisioner gör bryggan oanvändbar.

Akvariebesök och synliga fångster ger social närvaro. Handel, gåvor,
globala topplistor och turneringar ingår inte i första versionen.

Testa om tavlan faktiskt motiverar förbättring och besök. En poängtavla ensam
garanterar inte intressant multiplayer. Rättvisa gemensamma fiskeutmaningar kan
utvärderas senare om grundsystemet behöver mer social aktivitet.

## 8. UI och plattformar

Grundvyn behöver bara visa mynt, aktuell handling samt knappar för Samling,
Akvarium och Uppgraderingar. Resultatet av en fångst får en kort presentation
som kan stängas snabbt.

- Stora tryckytor som inte täcker Roblox egna rörelse- och kamerakontroller.
- Gränssnitt som anpassas till skärmstorlek och säkra skärmområden.
- Läsbar text på liten mobilskärm; korta instruktioner med symboler.
- Viktig information förmedlas också visuellt när ljudet är avstängt.
- Enkel grafik, begränsade effekter och få rörliga akvariefiskar samtidigt.

Roblox stöder dator, telefon och surfplatta, men bra stöd måste verifieras i
Studio och på riktiga enheter. En skrivbordskontroll verifierar inte touch.
Första layouten planeras för liggande skärm; faktiskt beteende på telefon och
iPad kontrolleras innan vi fastställer enhetskraven.

## 9. Visuell identitet och ljud

Ljusa molnlandskap, mjuka silhuetter och starka men lugna färggrupper.
Fiskarna ska kännas olika genom form även utan detaljerade texturer.
Prioritera en läsbar silhuett före sällsynthetseffekter.

Första grafiken kan bestå av enkla former i Studio. Bygg en brygga, ett akvarium
och två provfiskar innan sex färdiga arter produceras. Använd bara tillgångar
som teamet har rätt att använda och granska externa modellers medföljande skript.

Higgsfield kan få en brief för konceptbilder eller andra faktiskt stödda format:

"Färgstarkt Roblox-vänligt fiskespel på svävande molnöar. En liten träbrygga,
vänliga fantasifiskar som simmar genom moln och ett personligt molnakvarium.
Stora tydliga former, låg detaljtäthet, pastellblått med varma gula accenter.
Visa startmiljön och en uppgraderad version med samma kamera. Ingen text."

Detta är en visuell referens, inte ett löfte om Roblox-kompatibla 3D-modeller.
Ingen direkt Higgsfield-integration har verifierats i den här sessionen.

## 10. Monetisering och återkomst

Inga köp behövs i prototypen. Senare kandidater är rent kosmetiska spöutseenden,
akvarieteman och visuella fångsteffekter. Köpta utseenden påverkar inte poäng,
artchanser eller fångstförmåga. Läsbarheten måste bevaras även med effekter.

Inga betalda slumpbelöningar planeras. Undvik dagliga sviter med förluststraff.
Återkomst ska främst drivas av saknade arter, personliga förbättringar och
lusten att utveckla akvariet. Första innehållet har ett naturligt slut;
vi ska inte förväxla sex arter med en färdig långsiktig innehållsplan.

## 11. MVP och senare innehåll

MVP:

- En ö, två fiskeplatser och upp till fyra samtidiga spelare som första testmål.
- Ett fiskemoment, sex arter och tre kvalitetsnivåer.
- Ett akvarium per spelare med fasta visningsplatser.
- Molnmynt och tre uppgraderingssteg.
- Samlingsbok, uppgraderingselement och serverns poängtavla.
- Sparad progression och grundläggande skydd mot dubbla belöningar.
- Fungerande dator- och touchkontroller.

Senare kandidater: nya öar, fler arter, kosmetisk möblering och gemensamma
utmaningar. Fri flygning, avel, handel, avancerad byggfunktion och globala ligor
kräver separata designbeslut. De är inte förutsättningar för MVP:n.

## 12. Teknisk inriktning inför nästa fas

Servern bestämmer fångst, belöning, valuta, upplåsningar och sparad progression.
Klienten sköter inmatning, UI och presentation. Servern kontrollerar bland annat
giltig fiskeplats, avstånd, aktivt fiskeförsök, tidsgränser och att ett försök
bara ger belöning en gång. Klienten får inte ange sin egen art eller utbetalning.

Sparad profil behöver mynt, köpta uppgraderingar, bästa kvalitet per art och
akvariets valda arter. Valutaköp och samtidiga sessioner behöver genomtänkta
regler. Ett läsfel får aldrig behandlas som en ny tom profil som skrivs över.

Exakt projektstruktur, kommunikation och datalagringslösning tas fram i den
tekniska designen. Roblox Studio behövs för faktisk spel- och enhetsvalidering;
det finns ännu inga verifierade Roblox-körningar från molnmiljön.

## 13. Arbetsordning för två nybörjare

Gör först en gemensam genomgång av Explorer, Properties, Play och skillnaden
mellan server- och klientkod. Använd befintlig checkout; skapa inte en extra
Git-worktree utan ett uttryckligt behov från teamet.

### A. Spelbar fiskeprototyp

- Mål: testa om en fångst är rolig med ett provisoriskt utseende.
- Ansvar: utvecklare A arbetar med fiskebeteende; B bygger brygga och UI-utkast.
- Platser: Workspace för testmiljö, StarterGui för UI, ServerScriptService för
  regler och StarterPlayerScripts för lokal inmatning. Filnamn fastställs i
  den tekniska designen före kodning.
- Beroenden: Studio tillgängligt för båda och en gemensamt dokumenterad version.
- Test: nya spelare provar på dator och touch utan muntlig vägledning.
- Godkänt: starta, fånga, se resultat och försöka igen; inget låst tillstånd.

### B. En komplett framstegsloop

- Mål: koppla fångst till mynt, en uppgradering och en synlig akvariefisk.
- Ansvar: A äger serverregler och ekonomi; B äger akvarium och presentation.
- Platser: servermoduler, gemensamma artdefinitioner, Workspace och StarterGui.
- Beroenden: A fungerar; gränser mellan moduler bestäms gemensamt först.
- Test: fånga, uppgradera och välj visningsfisk. Prova otillräcklig valuta och
  upprepade knapptryckningar.
- Godkänt: korrekt saldo, tydlig uppgradering och ingen dubbelutbetalning.

### C. Sparande och multiplayer

- Mål: bevara framsteg och visa trovärdig tävling mellan flera spelare.
- Ansvar: A äger sparande och servervalidering; B äger poängtavla och besök.
- Platser: serverns datamoduler, profilstruktur och UI för poäng och laddstatus.
- Beroenden: B fungerar och profilens schema är bestämt.
- Test: återanslutning, avbruten anslutning, simulerade dataläsfel, två samtidiga
  spelare samt försök att återanvända ett fångstmeddelande.
- Godkänt: rätt data återställs, fel skriver inte över profiler och spelare
  påverkar inte varandras saldon eller fångstresultat.

### D. Liten innehållsversion och enhetstest

- Mål: färdigställa MVP:ns sex arter, två platser och tre uppgraderingar.
- Ansvar: A kontrollerar progression och fel; B kontrollerar läsbarhet och grafik.
- Platser: art- och uppgraderingsdefinitioner, värld, UI och fiskmodeller.
- Beroenden: C fungerar.
- Test: hela loopen på dator, telefon och iPad; flera klienter i samma server.
- Godkänt: begriplig introduktion, användbar touch, korrekt poäng och sparande,
  samt inga återkommande fel i normal spelgång. Mät prestanda på en svagare
  faktisk testenhet innan grafiken byggs ut.

Gör en fas i taget. Undvik att båda samtidigt redigerar samma platsfil eller
UI-hierarki. Bestäm Git/Studio-synk och ägarskap innan parallell implementation.
Teamets budget är cirka 30 persontimmar per vecka. En första veckoplan och
projektstruktur finns i [Första veckan](forsta-veckan.md). Den tidigare
generella uppskattningen för ett annat koncept ska inte återanvändas.

## 14. Beslutspunkter

Koncept, plattformsmål, erfarenhetsnivå och tävlingens inriktning är valda av
teamet. Fiskemomentet, poängreglerna och MVP-avgränsningen ovan är rekommendationer
som ska prövas innan stora system byggs.

Den första tekniska strukturen och Studio-stegen för fas A finns i
[Första veckan](forsta-veckan.md). Nästa implementationssteg är en fristående
fiskeprototyp enligt dessa gränser. Tillgång till riktiga telefoner och iPad
är ännu inte bekräftad; datorerna räcker för att börja och emulera skärmformat.
