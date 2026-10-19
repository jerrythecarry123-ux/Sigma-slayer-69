# Cloud Anglers v0.5 — testprotokoll

## Automatiskt verifierat i molnmiljön

- 19 tester av fiskets tillståndsmaskin, 12 tester av fiskeplatser och 18 tester av progression/sparregler passerade.
- 8 tester av kartans kustlinjer, vägar, broar, kajer och kastmål passerade.
- 4 layoutkontroller för porträttmobil, liggande mobil, surfplatta och dator passerade.
- 3 Python-tester för korrekt inbäddade källfiler, sparade ljus/streaming-inställningar och repeterbar platsbyggnad
  passerade.
- Alla 23 Luau-produktionsfiler samt de fem Luau-testfilerna accepterades av den
  officiella Luau-kompilatorn. Detta är en syntaxkontroll, inte ett Roblox-typbevis.
- Typkontrollen passerade för konfiguration, fiskeregler, katalog, motor,
  progression, sparregler, fiskeplatser, världsdata, layoutberäkning och de fem Luau-testsviterna. Roblox-beroende filer behöver fortfarande kontrolleras i Studio.
- `.rbxlx`-filen har byggts med de aktuella källfilerna.

Luau-verktygen byggdes från den officiella källan `luau-lang/luau`, commit
`9d7748a4f324213a18cb8283fa2a77c330225fa0`. Inga externa körbara verktyg eller
grafikresurser behövs i själva Roblox-prototypen.

Regeltesterna täcker kvalitet, exakt en belöning per försök, platskontroll,
dubbla starter, för tidigt Hold, Release utan Hold, missade tidsfönster,
förfalskade ID:n, avbrott, timeout, gamla meddelanden, cooldown, anropsbegränsning,
separata spelare, frånkoppling, avatarbyte före nästa tick och att en snapshot
inte ändrar serverns data.

## Återstår att köra i Roblox Studio

Alla rutor nedan är **okörda**. Markera dem först när någon faktiskt genomfört
testet och anteckna enhet, resultat och eventuella Output-fel.

- [ ] Öppna den levererade rbxlx-filen utan importfel.
- [ ] Starta Play. Se ön, bryggan, avataren och gränssnittet.
- [ ] Försök fiska direkt vid spawn: ingen fångst, instruktion om bryggan.
- [ ] Gå till bryggans markerade fiskeplats, fiska och upprepa minst tio gånger.
- [ ] Träffa områdena Normal, Fine och Brilliant. Kontrollera fångsträknaren.
- [ ] Släpp för tidigt och för sent: ingen fångst; nästa försök fungerar.
- [ ] Vänta för länge på napp respektive släpp: återgå till redo utan låsning.
- [ ] Släpp utanför knappen; fångstförsöket ska ändå avslutas.
- [ ] Växla bort från Studio mitt i ett försök. Återvänd och fiska igen.
- [ ] Öppna en textruta/chatten mitt i ett försök; E ska inte fortsätta styra fisket.
- [ ] Gå från bryggan eller återställ avataren mitt i ett försök. Ingen belöning.
- [ ] Klicka snabbt upprepade gånger. Högst ett försök per spelare åt gången.
- [ ] Starta lokal server med två klienter. Fånga samtidigt, med olika resultat.
- [ ] Avsluta en klient mitt i fisket. Den andra kan fortsätta.
- [ ] Prova musknapp och E separat.
- [ ] Prova emulerad touch: håll, släpp utanför knappen och avbruten beröring.
- [ ] Kontrollera smal mobilvy och liggande surfplattevy: läsbara texter,
  tryckbar knapp och åtkomliga rörelse-/kamerakontroller.
- [ ] Prova med simulerad nätfördröjning och notera skillnaden mellan synlig
  mätarposition och serverns kvalitet. Justera innan tävlingspoäng införs.
- [ ] Prova riktig telefon och iPad; emulering verifierar inte enhetsprestanda.
- [ ] Stoppa och starta Play: fångsträknaren börjar om, som prototypen anger.
- [ ] Inga återkommande fel visas i Output under normal spelgång.

Testanteckningar:

| Testare / enhet | Datum | Resultat | Fel / nästa åtgärd |
| --- | --- | --- | --- |
| Ej testat ännu | — | — | — |

## Nya kontroller för v0.2 — ännu inte körda i Studio

- [ ] All egen UI, skyltar och resultat visas på engelska.
- [ ] Spöet följer handen och kastet har en tydlig bakåt-/framåtrörelse.
- [ ] Flötet följer en båge, landar och ger ringar samt plaskljud.
- [ ] Napp visar ett utropstecken och ger en ljudsignal.
- [ ] Armen och spöet rör sig vid invevning; ljudloopen slutar vid resultat/avbrott.
- [ ] En godkänd fisk flyger upp från dammen och ger gnistor och fångstljud.
- [ ] Fångstkortets 3D-fisk rör sig; kortet går att stänga med x och E.
- [ ] Misslyckat fiske visar inget framgångskort och ökar inte räknaren.
- [ ] SFX OFF tystar både loopar och engångsljud, SFX ON återställer ljudet.
- [ ] Två klienter ser varandras kast och fångster utan dubbla effekter.
- [ ] En sent ansluten klient ser ett redan pågående fiskeförsök.
- [ ] Död/frånkoppling tar bort flöte, lina, fisk och poser för rätt spelare.
- [ ] Prova både R15 och R6; inga uppladdade animationer behövs.
- [ ] Prova mobil i liggande läge: resultatkort, ljudknapp och rörelsekontroller är användbara.

Ljudreferenser för kast, plask, invevning och miss utgår från Roblox klientljud
som också används i Roblox officiella Core-Scripts. Napp/fångst använder den
inbyggda electronicpingshort-signalen. Ljuduppspelning är inte verifierad i
molnmiljön; lyssna på varje effekt i Studio innan den markeras godkänd.

## v0.3 — nya manuella kontroller, ännu okörda

- [ ] Se mål, mynt, spönivå och journal på dator, mobil och iPad.
- [ ] De tre första godkända fångsterna är olika arter.
- [ ] Fångster ger rätt mynt; målbonus betalas en gång.
- [ ] Journalen visar 6 arter, bästa kvalitet, låsta arter och nästa uppgradering.
- [ ] Köp ett spö med rätt saldo; försök utan tillräckliga mynt och under ett kast.
- [ ] Två upprepade köpanrop för samma nivå köper inte nästa nivå av misstag.
- [ ] Breeze Rod låser upp 2 arter och Nimbus Rod låser upp Aurorafin.
- [ ] Verkstadens prompt öppnar journalen utan att starta ett fiskekast.
- [ ] Ljud för UI, mynt, mål, uppgradering och nya arter hörs och går att tysta.
- [ ] Alla 6 fiskars 3D-modeller syns korrekt och fenorna rör sig.
- [ ] Collection-topplistan visar rätt poäng och myntsaldon skickas inte till andra.
- [ ] Publicera separat privat testupplevelse och följ återkomsttestet i discovery-and-return-play.md.
- [ ] Verifiera faktiskt sparande av saldo, uppgraderingar, kvaliteter och mål.
- [ ] Återkomst efter 5 minuter ger korrekt offlinebelopp; direkt återanslutning ger ingen dubbelbonus.
- [ ] Samtidiga sessioner, DataStore-fel och serverstängning hanteras utan ny tom profil.
- [ ] Studio utan publicering fungerar med tillfällig profil och tydlig information om att inget sparas.


## v0.4 — grafisk ombyggnad och ljudmix, ännu okörda i Studio

43 automatiska kontroller passerar (19 fiske, 18 progression/sparande,
4 layout, 2 platsbyggnad). Layoutkontrollerna verifierar beräknade gränser,
inte Roblox textmått, faktisk touch eller skärmarnas utseende.
Världsgeometrin har dessutom inspekterats via en separat Blender-rendering av
produktionskodens utdata. Det är ingen skärmbild från Roblox Studio.

- [ ] Öppna **Cloud-Anglers-v0.4.rbxlx**, tryck Play och kontrollera Output.
- [ ] Se mjuka klippkanter, lagun, repbrygga, verkstad, distansöar och luftskepp.
- [ ] Vattenfall rör sig och luftskeppet svävar långsamt utan återkommande fel.
- [ ] Gå från spawn till fiskeplatsen utan hinder. Flötet landar på vattenytan.
- [ ] Gräsklippkanter, blommor och moln blockerar inte spelaren eller kameran.
- [ ] Kontrollera skyltarnas framsidor och att verkstadens text går att läsa.
- [ ] COLLECTION visar sex separata 3D-porträtt och artens tips när ett kort väljs.
- [ ] Upptäckta fiskar har färg och bästa kvalitet, andra har mörkare porträtt.
- [ ] Rod workshop har läsbara uppgifter, 3D-spö och en minst 44 px tryckyta.
- [ ] Verkstadens prompt öppnar direkt rätt flik. Köp och stäng; fiska igen.
- [ ] Prova 320 px bred porträttvy, 568×320 landskap, iPad och dator.
- [ ] Scrolla båda menyflikarna; även sista fiskkortet och köpraden är åtkomliga.
- [ ] Inget menyhuvud, fångstkort, saldo eller kontrollkort skärs av av skärmens insets.
- [ ] Porträttlägets fiskekort sitter ovanför joystick/hopp. Landskapskortet sitter mellan dem.
- [ ] Stäng fångstkort och meny via touch; inga osynliga paneler blockerar efteråt.
- [ ] Lyssna i hörlurar och på telefonhögtalare: napp är tydligt, utan vasst pip.
- [ ] Kast/plask har rimlig nivå, reel-loop tonar in/ut även vid avbrott och död.
- [ ] Mål spelar inte ovanpå fångstsignalen; mätaren har inga extra pip.
- [ ] SFX/OFF tystar allt, även vid pågående belöningsfras. Återaktivering fungerar.
- [ ] Två samtidiga fiskare låter lagom och avlägsna kast hörs svagare.
- [ ] Mät faktisk FPS/minne på telefon/iPad med lägsta och högre Roblox-grafik.
- [ ] Återanslut med v0.3-profil: befintliga mynt, arter och spön finns kvar.

De sex ljudfilerna är samma som i v0.3. Denna version ändrar tonhöjd, EQ,
komprimering, volymer och frasernas tajming. Ljudkvalitet kan först bedömas
slutligt genom att faktiskt lyssna i Roblox.


## v0.5 — stor övärld, ännu okörda kontroller i Studio

64 automatiska tester passerar. Dessutom kontrollerades 3 639 provpunkter mot
produktionskodens faktiska genererade kollisionsgeometri, inklusive osynliga
golv/räcken och orienterade kilformer. Korridoren är 2,6 studs bred med minst
6 studs fri höjd och kontinuerligt stöd. Detta är analytisk geometri, inte ett
kört Roblox-fysiktest. Några broar behövde plana landningar för att inte gå in
under den högre öns golv; dessa anslutningar är rättade.

Mätning av generatorns utdata: 9 655 förankrade delar, varav 941 kolliderbara,
samt fem områden med native Terrain-vatten. Små träd/byggnader/brodelar strömmas
atomiskt. Hela öar är inte atomiska eller beständigt tvångsladdade.

- [ ] Öppna **Cloud-Anglers-v0.5.rbxlx** och tryck Play. Kontrollera Output vid start.
- [ ] Spelaren börjar på hamnens säkra spawn och faller inte medan kartan byggs.
- [ ] Se alla fem områden och följ skyltade vägar/broar från hamnen.
- [ ] Gå över varje bro åt båda håll, nära mitt och kanter, utan hopp eller glapp.
- [ ] Ingen stig går genom vägg, trädstam, mark, rekvisita eller låg takbalk.
- [ ] Hitta fiskeplatser i Harbor, Grove, Reach, Cove och Lookout. Fånga på alla fem.
- [ ] Flötenas fyra kastbanor landar i respektive laguns vattenyta.
- [ ] Flytta ifrån aktivt kast: rätt kast avbryts och flyttas inte till en annan kaj.
- [ ] Två klienter på olika öar ser kast på rätt vattenplats när de kommer inom synhåll.
- [ ] Vattnet har Roblox vågor/reflektioner; inga torra hål vid kastmålen.
- [ ] Vattenfallen rör sig, kvarnens segel roterar runt rätt nav och luftskeppet driver lugnt.
- [ ] Besök tillbaka efter att en ö strömmats ut: animationer startar igen utan dubbletter.
- [ ] Gå in i husen. Verkstadens prompt öppnar den befintliga uppgraderingsmenyn.
- [ ] Klättra upp och ned i fyren med standard-R15 och R6. Huvudet slår inte i trappan.
- [ ] Fyrbalkongens och broarnas synliga räcken motsvarar deras skyddande kollision.
- [ ] Besök grottan och observatoriet; fria öppningar och tydliga landmärken.
- [ ] Markera Lighting: Realistic, PrioritizeLightingQuality och GlobalShadows är sparade.
- [ ] Se träd-, tak- och klippskuggor. Prova Roblox grafiknivå låg, medel och hög.
- [ ] Inga stigar, golv eller strandpartier flimrar av överlappande ytor.
- [ ] Se material/text på nära håll: takpannor, timmer, fönster, rep, skyltar och rabatter.
- [ ] Ladda kartans områden via promenad på riktig telefon/iPad. Mät FPS/minne och laddpauser.
- [ ] Prova dåligt nätverk: strömning pausar säkert, utan att spelaren faller genom oladdat golv.
- [ ] Återanslut med tidigare profil: mynt, arter, spön och offlineinkomst bevaras.
- [ ] Bekräfta att ingen ny ljudtyp lagts till och att UI fungerar som i v0.4.

Realistic/PrioritizeLightingQuality och streaming sparas av byggverktyget eftersom
vissa av dessa inställningar inte får ändras av vanliga serverskript. Alla angivna
värden kontrollerades mot aktuell Roblox API-dump; faktisk Studio-import återstår.
