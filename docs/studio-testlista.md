# Cloud Anglers v0.8 — testprotokoll

## Automatiskt verifierat i molnmiljön

- 19 tester av fiskets tillståndsmaskin, 12 tester av fiskeplatser och 18 tester av progression/sparregler passerade.
- 9 tester av kartans kustlinjer, vägar, broar, kajer, kastmål och gångavstånd passerade.
- 15 tester av snabbresornas destinationer, avstånd, tidsgränser och samtidiga anrop passerade.
- 4 layoutkontroller för porträttmobil, liggande mobil, surfplatta och dator passerade.
- 3 Python-tester för korrekt inbäddade källfiler, sparade ljus/streaming-inställningar och repeterbar platsbyggnad
  passerade.
- Alla 32 Luau-produktionsfiler samt de sex Luau-testfilerna accepterades av den
  officiella Luau-kompilatorn. Detta är en syntaxkontroll, inte ett Roblox-typbevis.
- Typkontrollen passerade för konfiguration, fiskeregler, katalog, motor,
  progression, sparregler, fiskeplatser, reseregler, världsdata, layoutberäkning och de sex Luau-testsviterna. Roblox-beroende filer behöver fortfarande kontrolleras i Studio.
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
- [ ] Spawna på huvudbryggan och nå första kastområdet på några få steg.
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

## v0.6 — färg, planteringar och liv, ännu okörda kontroller i Studio

De 64 befintliga testerna och kompilering av 31 Luau-filer passerar.
Generatorn skapar 9 850 förankrade delar, varav samma 941 kolliderbara som i v0.5.
3 639 provpunkter mot den faktiska kollisionsgeometrin passerar fortfarande.
En separat kontroll kör produktionskodens invånare och klientanimation med
geometri-/händelsedubblar: 379 delar i 21 aktörer, 1 006 ändliga animationssteg,
stabila leder, begränsad gångrutt, sena attribut, kamerabaserat avståndsstopp och
utströmning/återbindning passerar. Detta verifierar inte Roblox-motorn.

- [ ] Öppna **Cloud-Anglers-v0.6.rbxlx**, tryck Play och kontrollera Output.
- [ ] Se ljusare gräs, turkost vatten, mint-/persikofärgade hus och korall-/turkosa tak.
- [ ] Kontrollera tydliga skuggor under trädkronor, tak och invånare på flera grafiknivåer.
- [ ] Se caféets serveringslucka, verkstadens spöställ och fasadernas fönster/markiser.
- [ ] Gå från spawn genom torget till bryggan; planteringar täcker inte stigar eller entréer.
- [ ] Se sju invånare med olika poser/aktiviteter. Deras ansikten, hattar och rekvisita sitter rätt.
- [ ] Hamnens vandrare följer en jämn slinga ovan mark utan ryckiga vändningar.
- [ ] Fiskarens lina når vattenytan utan att blockera spelarens fiskeplats.
- [ ] Se måsar glidflyga/flaxa, fjärilar fladdra och två fiskstim röra sig i lagunerna.
- [ ] Kronor svajar kring rätt punkt; tallarnas barr flyttas inte ned mot marken vid första uppdatering.
- [ ] Den målade båten guppar försiktigt och stannar förtöjd vid bryggan.
- [ ] Besök blomsterlund, skog, strand och utsiktsplats: se nya rabatter, ormbunkar och picknickdetaljer.
- [ ] Gå långt från aktörer och återvänd: närliggande rörelser återupptas utan dubbla animationer.
- [ ] Strömma ut/in en ö, återställ avataren och prova två klienter; inga återkommande Output-fel.
- [ ] Mät FPS, minne och laddpauser på riktig telefon/iPad, särskilt på hamntorget.
- [ ] Bekräfta att gränssnitt, ljudmix, mynt och tidigare sparad profil fungerar som före världsuppdateringen.

Offline-renderingar används bara för granskning av geometri och placering.
Faktisk ljussättning, material, streaming och prestanda ska bedömas i Roblox.

## v0.7 — kortare resor och ny palett, ännu okörda kontroller i Studio

80 tester passerar. Alla 35 Luau-filer kompilerar. Den faktiska exporterade
geometrin klarar 3 681 vägprovpunkter, 225 provpunkter över hela spawn-ytan och
125 över ankomstytorna. Tolv scenarier med produktionskod och händelsedubblar
kontrollerar resornas auktorisering och fel/förändringar under inläsningsväntan.
Detta är inte ett kört Roblox-test av streaming, fysik eller grafisk kvalitet.

- [ ] Öppna **Cloud-Anglers-v0.7.rbxlx** och tryck Play. Kontrollera Output.
- [ ] Spawn hamnar på bryggan utan att avataren står i lådor, räcken eller invånare.
- [ ] Gå till första fiskemarkeringen på ungefär en sekund; starta ett kast.
- [ ] Kontrollera gånghastigheten 22 på dator, emulerad touch och riktig telefon/iPad.
- [ ] Besök det gula uppgraderingsståndet vid bryggans början. Prompten öppnar spöverkstaden.
- [ ] Fånga → köp uppgradering om saldot räcker → återgå direkt till fisket.
- [ ] Se grönare mark/löv, blått vatten, krämvita hus och mindre rosa/mint/cyan.
- [ ] Kontrollera att nya material och neutralare färgfilter behåller träd- och takskuggor.
- [ ] Det blå reseståndet med gul anka står fritt från Captain Pip och spelarens kastplats.
- [ ] Vid fiskemarkeringen och efter ankomst fungerar E för fiske, utan reseprompt ovanpå.
- [ ] Öppna ISLAND HOP och res till alla fem destinationer, även från varje annan ö.
- [ ] Varje ankomst står på rätt brygga inom kastavstånd. Fiska utan extra promenad.
- [ ] Res innan destinationen har besökts. Ingen faller genom en oladdad brygga.
- [ ] Res från aktivt fiske: försöket avbryts utan dubbel fångst eller kvarvarande flöte/ljudloop.
- [ ] Återställ avataren, lämna servern och gå från ståndet under inläsning. Ingen gammal avatar flyttas.
- [ ] Prova två klienter som reser samtidigt samt upprepade snabba klick.
- [ ] Öppna/stäng resemenyn med touch, stängknapp och bakgrund; collection/resultat ligger inte kvar ovanpå.
- [ ] Prova 320 px porträtt och 568×320 landskap: 56 px destinationsrader går att scrolla och stänga.
- [ ] Efter död/respawn och resa går fiske, rörelse och menyöppning att använda igen.
- [ ] Kontrollera tidigare sparade mynt/spön/arter och att inga nya ljud tillkommit.
- [ ] Mät faktisk FPS/minne och resornas laddtid på telefon och iPad.

## v0.8 — blockstil efter bildreferensen, ännu okörda kontroller i Studio

Färg-/materialriktningen utgår nu från användarens faktiska Duck Pond-skärmbild.
Mark och vegetation är starkt gröna, gångytor blekgula och klippor gråblå.
Roblox inbyggda Studs-ytor används på Plastic; inga individuella knoppdelar,
texturuppladdningar eller externa modellresurser behövs.

Generatorn skapar 7 851 förankrade delar, cirka 21 % färre än v0.7. De ursprungliga
946 kolliderbara formerna har identiska storlekar och transformeringar. Dammarnas
nya bortre terrasser tillför 170 kolliderbara delar. Väg-, spawn- och resornas
ankomstkontroller passerar fortfarande. Alla 38 Luau-filer kompilerar.

Uppstarten körs dessutom med oförändrade produktionskällor och geometri-/händelsedubblar.
Kontrollen bekräftar att FishingService verkligen startar de fem resestånden för
världens Folder, samt att egen karta fungerar utan genererade snabbresor. Den gamla
Model-kontrollen från v0.7 återställs i minnet och måste misslyckas i samma kontroll.

- [ ] Öppna **Cloud-Anglers-v0.8.rbxlx**, starta Play och kontrollera Output.
- [ ] Jämför kartan med referensbilden: starkt grönt, cyanblått vatten, gråblå väggar och blekgula gångar.
- [ ] Se inbyggda knoppar på breda markplattor, bryggor, träd, hus och klippväggar.
- [ ] Granska särskilt gångarnas triangulära ytor: deras lokala vänster-/högersidor pekar uppåt.
- [ ] Inset-plattorna ligger under stigar och golv; inga gröna knoppar/flimrande ytor täcker gångarna.
- [ ] Markera Lighting: **Soft**, PrioritizeLightingQuality och GlobalShadows är sparade.
- [ ] Färgerna är tydliga på låg/medel/hög grafiknivå, utan disig färgton eller för starka reflexer.
- [ ] Se fyrkantiga träd och blockstenar. Trädkronorna svajar kring rätt fästen.
- [ ] Invånarnas ansikten, händer, hattar och gångrörelser fungerar med de nya blockformerna.
- [ ] Alla fem dammar har grå terrassväggar med gröna kanter och två cyanblå vattenfall var.
- [ ] Vattenfallsränderna rör sig inom sina gardiner, utan nya ljud eller återkommande fel.
- [ ] Skummet vid vattenfallen glittrar svagt; små grässpröt sitter ovanpå klippornas hyllor.
- [ ] Se fiskelådor, drag, flöteshinkar, reservspön och förtöjningsdetaljer längs bryggkanterna.
- [ ] Namnplaketter går att läsa från bryggan. Varje ö har en egen liten detaljscen.
- [ ] Fem sittplatser längs stigarna har blomkrukor, tydliga skyltar och små regionala detaljer.
- [ ] Detaljerna skär inte in i spawn, invånare, huvudstigar eller fiskelinor.
- [ ] Fiska på alla fem bryggor. De nya klippväggarna står bakom dammarna och blockerar inte kasten.
- [ ] Start vid bryggan, gånghastighet 22, närverkstad och gratis snabbresor fungerar som i v0.7.
- [ ] Prova två klienter samt strömma ut/in öarna. Väggar och animationer återkommer korrekt.
- [ ] Kontrollera faktisk FPS/minne på telefon/iPad. Färre källdelar verifierar inte prestanda.

Offline-renderingar används för form och placering. De visar inte Roblox inbyggda
Studs-ytor eller den sparade Soft-ljussättningen; dessa kontroller måste köras i Studio.


## v0.9 — dämpat ljus och fysiska portaler, ännu okört i Studio

Världen har 7 971 delar och 1 121 kolliderbara former. Geometrikontrollen täcker
3 681 vägprovpunkter, 225 spawn-prov, 125 ankomst-prov och 429 prov genom
portalernas öppningar i bryggräckena. Produktionskodens server- och klientkontroller
körs med dubblar för geometri, händelser och tweening. Detta verifierar inte
Roblox-rendering, verkliga touchkontroller, streaming eller fysik.

- [ ] Öppna **Cloud-Anglers-v0.9.rbxlx**, tryck Play och kontrollera Output.
- [ ] Lighting har Realistic, GlobalShadows, Brightness 1.9 och ExposureCompensation −0.2.
- [ ] Gräs, bryggor och dammar är behagliga att se på i fullskärm. Vattenfallen bländar inte.
- [ ] Skuggor syns under träd, tak och klipphyllor på flera grafiknivåer. Gångvägar förblir läsbara.
- [ ] Se en portal med långsamt roterande runor vid varje brygga. Ingen ny ljus- eller ljudeffekt.
- [ ] Gå rakt från spawn till fiske; ingen portalmeny öppnas på den vanliga rutten.
- [ ] Gå i sidled genom räckets öppning in i portalen. Menyn öppnas en gång.
- [ ] Stäng menyn medan du står kvar. Den öppnas inte igen förrän du lämnat och gått in på nytt.
- [ ] Välj ö med mus, touch och handkontroll. Testa 320 px porträtt och 568×320 landskap.
- [ ] Bilden tonar ned till mörkt före flytten och tillbaka efter ankomst. Ingen vit blixt eller kameraryck.
- [ ] Du landar nära rätt fiskeplats och vänd mot bryggan. Fiska direkt med E eller knappen.
- [ ] Besök alla fem öar innan de hunnit laddas in. Ingen faller genom portalgolvet.
- [ ] Gå direkt tillbaka genom portalen efter ankomst; menyn öppnas när kort spärrtid löpt ut.
- [ ] Testa snabb stängning före flytt, avvisad resa, tappad anslutning, död och respawn.
- [ ] Rörelsen återkommer efter avslutad/avbruten resa; inget mörkt lager fastnar.
- [ ] Testa två klienter som reser samtidigt, även med olika avatarstorlekar.
- [ ] Efter utströmning/återkomst återkommer portal, runor, prompt och gångöppning korrekt.
- [ ] Fiske avbryts vid resa utan extra belöning eller kvarvarande flöte/ljudloop.
- [ ] Sparade mynt, arter, spön och offlineinkomst fungerar som tidigare.
- [ ] Mät verklig FPS, minne och laddtid på dator, telefon och iPad.
