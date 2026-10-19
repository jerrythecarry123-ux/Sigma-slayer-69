# Cloud Anglers v0.4 — testprotokoll

## Automatiskt verifierat i molnmiljön

- 19 tester av fiskets tillståndsmaskin och 18 tester av progression/sparregler passerade.
- 4 layoutkontroller för porträttmobil, liggande mobil, surfplatta och dator passerade.
- 2 Python-tester för korrekt inbäddade källfiler och repeterbar platsbyggnad
  passerade.
- Alla 17 Luau-produktionsfiler samt de tre Luau-testfilerna accepterades av den
  officiella Luau-kompilatorn. Detta är en syntaxkontroll, inte ett Roblox-typbevis.
- Typkontrollen passerade för konfiguration, fiskeregler, katalog, motor,
  progression, sparregler, layoutberäkning och de tre Luau-testsviterna. Roblox-beroende filer behöver fortfarande kontrolleras i Studio.
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
