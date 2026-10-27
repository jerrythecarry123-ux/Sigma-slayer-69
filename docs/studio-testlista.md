# Cloud Anglers — testprotokoll

## Automatiskt verifierat i molnmiljön

- 167 grundtester: 5 katalog, 48 fiske, 14 fiskeplatser, 10 inställningar,
  40 progression/sparande, 9 slutskrivningar, 8 layout, 15 reseregler,
  14 världsdata och 4 Python-tester för platsbyggnad/material.
- Alla 36 produktionsfiler och de nio Luau-sviterna accepteras av den officiella
  Luau-kompilatorn. Detta är en syntaxkontroll, inte ett Roblox-typbevis.
- Separata kontroller kör produktionskod med geometri-/händelsedubblar för
  uppstart, resor, gränssnitt, fiskmodeller, akvarier, invånare och miljörörelser.
- Gångvägar, spawn, portalankomster och synliga stigar kontrolleras analytiskt.
  Dessa kontroller ersätter inte Roblox fysik, rendering eller enhetsprestanda.
- `.rbxlx`-filen byggs från de aktuella källfilerna och kontrolleras mot dem.

Luau-verktygen byggdes från den officiella källan `luau-lang/luau`, commit
`9d7748a4f324213a18cb8283fa2a77c330225fa0`. Inga externa körbara verktyg eller
grafikresurser behövs i själva Roblox-prototypen.

Regeltesterna täcker kvalitet, exakt en belöning per försök, platskontroll,
dubbla starter, för tidigt Hold, Release utan Hold, missade tidsfönster,
förfalskade ID:n, avbrott, timeout, gamla meddelanden, cooldown, anropsbegränsning,
separata spelare, frånkoppling, avatarbyte före nästa tick och att en snapshot
inte ändrar serverns data.

## v1.8 — aktuell acceptans, ännu okörd i Roblox

Kör först `python tools/check_project.py --luau /sökväg/till/luau` för de
tillgängliga molnkontrollerna. Ett godkänt resultat fyller inte i rutorna nedan.
Kontrollera den levererade **Cloud-Anglers-v1.8.rbxlx** i en separat privat
testupplevelse. Anteckna build, enhet, grafiknivå och nätfördröjning.

- [ ] Ladda ned via GitHubs **Download raw file**, öppna filen och starta Play.
  Tom redigeringsvy före Play är väntad; världen ska byggas när spelet startar.
- [ ] Tryck snabbt: vanligt kast fungerar med mus, E, touch och gamepad RT.
  Håll/släpp på guld: separat kastmätare följs av kastbåge, napp och invevning.
  Den gamla kasttryckningen får inte räknas som ett automatiskt invevningstryck.
- [ ] Träffa Clean/Precise/Perfect vid 50, 100 och 200 ms simulerad fördröjning;
  jämför synlig position och serverns bedömning. Upprepa Normal/Fine/Brilliant
  vid invevning. Serverns mottagningstid styr båda momenten.
- [ ] Håll kvar ett kast till timeout, släpp utanför knappen, växla fokus, dö,
  öppna meny och res med portal. Fiske fungerar igen; avsiktliga avbrott ger
  ingen missignal, fångst eller gammal resultatvisning.
- [ ] Prova lägsta och högsta kaststyrka vid alla fem dammar med flera spelare.
  Flöten landar i synligt vatten utan dold väg, stolpe eller kant genom linan.
- [ ] Tjäna och köp varje spö. Kontrollera att spönas material/finish skiljer
  sig, att guldzonen blir bredare och att pris/låsningar stämmer med verkstaden.
  Första tre lyckade fångsterna behåller introduktionens förlåtande zon.
- [ ] Behåll en Fine/Brilliant-kedja tills ett spö går att köpa. Nästa steg ska
  visa uppgraderingen. En färdig journal ska föreslå att visa upp favoritfiskar.
- [ ] Granska alla 17 arter från flera håll vid normal/maxvikt och i Normal,
  Golden och Prismatic. Fenrötter, gaffelstjärtar, morrhår, lure, bläckfiskarmar
  och Cloudmoths bakvingefläckar sitter ihop genom hela rörelsen.
- [ ] Fiskarna ryms i journal, fångstkort, specialvisning och alla akvarieplatser.
  Prova kort landskap, porträtt, rotation, större Roblox-text och verklig iPad.
- [ ] Journalens kompakta rader och fångstkort är hela och läsbara. Alla knappar
  går att träffa; akvariets laddning/val/fokus uppdateras även utan storleksbyte.
- [ ] Stäng akvariet, rotera enheten och öppna igen. Layouten är rätt direkt.
  Kompakt läge visar inga onödigt animerade dolda porträtt; normal rörelse kommer
  tillbaka när porträtten visas och reducerad rörelse stängs av.
- [ ] Ändra ljud och reducerade effekter snabbt flera gånger med fördröjda svar.
  Senaste lokala valet gäller direkt och kan inte ersättas av en äldre kvittens.
  Fisket går att starta medan ett tidigare inställningssvar är på väg.
- [ ] I publicerad privat klient: spara tyst/reducerat, lämna och återanslut.
  Valen återställs från profilen. Ingen startvind hörs medan profilen laddas.
  Roblox Reduce Motion gäller även om det lokala rörelsevalet är av.
- [ ] I vanlig Studio Play: inställningstexten förklarar att profilen är tillfällig.
  En accepterad inställning får inte påstå att en separat beständig skrivning
  redan slutförts. Testa riktigt sparande i den privata publicerade upplevelsen.
- [ ] Lyssna på kast/plask/napp/invevning/fångst och upprepade sällsynta visningar.
  Reel-pitchen följer motstånd lugnt, volymen staplas inte och tysta/slå på spelar
  inte upp gamla toner. Biblioteket har fortfarande sex klipp.
- [ ] Lämna under autosparande, återanslut, prova två samtidiga sessioner och
  stäng testservern. Senaste bekräftade profil behålls; ingen tom profil eller
  dubbel offlinebelöning ersätter den vid ett fel. Logga verkliga DataStore-fel.
- [ ] Granska vattenkant/repstolpar, synliga trädstammar, tunna ormbunkar och
  hyllkrukor i låg/hög grafik. Kontrollera skuggor, materialkartor och att färger
  är behagliga i den riktiga renderingen.
- [ ] Mät klientens CPU/GPU-tid, minne och streaming på vald bastelefon med
  flera samtidiga fiskare och fyllda akvarier. Dokumentera faktisk enhet.

Alla rutor är okörda. Tidigare versionslistor nedan bevarar historiska krav;
versionsnamn, artantal och sessionsinställningar där beskriver respektive build.
Använd v1.8-reglerna ovan för den aktuella leveransen.

## v1.7 — prioriterad acceptans, ännu okörd i Roblox

De automatiska kontrollerna omfattar även den faktiska serveradaptern,
16 klientprotokollfall, nio ljudhändelsefall och produktionskod för fångstscener.
De körs med dubblar och kan inte bevisa spelkänsla eller faktisk rendering.

- [ ] Första tre lyckade fångsterna har stilla guldzon; senare fiskar ger lugnt,
  glidande eller snabbare motstånd utan att ett nytt barn behöver fler knappar.
- [ ] Kastbågen landar före hugget; varierande väntetid visar tydlig visuell nappsignal.
- [ ] Träffa Normal/Fine/Brilliant på dator, gamepad, riktig telefon och iPad.
  Upprepa med 50, 100 och 200 ms simulerad nätfördröjning. Notera serverns kvalitet
  jämfört med det synliga släppet; scoring använder mottagningstid på servern.
- [ ] Avbryt/missa kast, gå till en annan damm och tillbaka: samma privata val
  ligger kvar per damm tills en lyckad fångst. Återanslutning får en ny session.
- [ ] Alla 17 arter syns i journalen. Veilfin och Eclipse kräver Aurora Rod och
  utlovas inte av skyddet mot dubbletter; de sju rariteterna har läsbara namn/rang.
- [ ] Första Epic/Legendary/Mythical/Secret visas kort; upprepade arter snabbare.
  CONTINUE, Escape och gamepad B/A avslutar en gång och belöningen ändras inte.
- [ ] Dö under visningen, innan CharacterRemoving. Ingen gammal visning eller
  fångstsammanfattning öppnas efter död, ny avatar, resa eller menybyte.
- [ ] Spelarens vanliga kamera, zoom, rörelse och andra spelares vy påverkas inte.
- [ ] Ny fiskmodell och dess fulla animation ryms i 3D-visningen vid porträtt,
  kort landskap och iPad. Kontrollera även Golden/Prismatic och maxvikt.
- [ ] Veilfins segment och Eclipse-svansen sitter ihop genom rörelsen; alla tre
  akvarieplatser håller fenor/svans innanför glaset, även vid högsta vikt.
- [ ] SETTINGS visar sessionens ljud/rörelseval. Roblox Reduce Motion gäller även
  när det lokala rörelsevalet är av; timing och nappinformation finns kvar.
- [ ] Tysta mitt i en melodi och slå på igen: inga gamla toner spelas upp.
  Bedöm faktiskt ljud, volym och repetition i klienten.
- [ ] Journal, verkstad, inställningar och fångstkort fungerar med gamepadfokus,
  Escape/B och touch. Byt aktiv inmatning på en mobil med ansluten gamepad.
- [ ] Kort landskap använder horisontellt fångstkort med läsbara texter och
  tryckytor. Kontrollera större Roblox-text, skärmkanter och enhetsrotation.
- [ ] Gammal profil med 15 arter behåller saldo/mål. Det nya 17-artsmålet ger
  sin bonus en gång utan att betala gamla milstolpar igen.
- [ ] Mät CPU/GPU-tid, minne och streaming på vald bastelefon under flera
  samtidiga kast och när akvarierna är fulla. Dokumentera enhet/grafiknivå.

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
- [ ] Stoppa och starta vanlig Studio Play: den tillfälliga profilen börjar om.
  För publicerad klient respektive aktiverad Studio-testsparning ska rätt sparad
  profil i stället läsas tillbaka enligt respektive lagringsutrymme.
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


## v1.0 — samlarspelet och formgivningen, ännu okört i Roblox

Produktionskod och rena regler kontrolleras i molnmiljön; verklig rendering,
ljuduppspelning, streaming, fysik och enhetsprestanda måste kontrolleras här.

- [ ] Öppna Cloud-Anglers-v1.0.rbxlx och tryck Play; inga återkommande Output-fel.
- [ ] Första kastet fungerar med touch, E och RT. Håll vid napp och släpp i färgzonen.
- [ ] Guldzonen flyttar sig mellan kast; visad kvalitet matchar resultatet.
- [ ] Första tre fångsterna ger olika startarter och fyller akvariet automatiskt.
- [ ] HUD visar begripligt nästa mål: fånga, uppgradera spö, upptäck nästa damm.
- [ ] Fem öar har tre egna arter var. Varje ö ger fisk med startspöt.
- [ ] Spöuppgraderingar öppnar angivna arter; Crownwhale kräver Aurora Rod.
- [ ] Fångstkort visar rätt vikt, utseende, rekord och mynt utan dubbel kedjebonus.
- [ ] Cast Again återgår snabbt till fisket; journal/akvarium stoppar väntande fångstkort.
- [ ] Journalen visar 15 arter, habitat, spökrav, fångstgrad och viktutveckling.
- [ ] MY AQUARIUM visar tre platser. Bara ägda arter kan väljas; inga dubbletter.
- [ ] Teman kostar rätt antal spelmynt. Redan köpta teman kostar inget vid nytt byte.
- [ ] VISIT MY TANK använder mörk övergång och landar framför ditt eget akvarium.
- [ ] Två eller fler klienter ser olika ägares tankar och rätt arter/teman/namn.
- [ ] En spelare lämnar och en annan återanvänder tom plats utan kvarvarande fiskar.
- [ ] Tio spelare kan få egna platser; nya rader har golv och fri gångväg.
- [ ] Alla arter, särskilt Moonray/Crownwhale, ryms vid glaset under simanimationen.
- [ ] Strömma ut/in galleriet; fiskar återupptar rörelse utan dubbla animationer.
- [ ] Träd har sammanhängande spetsiga kronor; tallarnas stammar sticker inte upp ur toppen.
- [ ] Palmlöv, stenar, blommor, trädgårdshäckar och sjöväggar känns formade, inte staplade klossar.
- [ ] Öarnas undersidor smalnar av; gångytorna ovanpå är fortsatt fria och säkra.
- [ ] Granska husens gavlar, fönster, markiser och planteringar på nära håll.
- [ ] Fiskars fenor, stjärtar, ögon och gälmarkeringar syns i porträtt och i världen.
- [ ] Ljuset är fortsatt dämpat och skuggorna läsbara på låg/medel/hög grafik.
- [ ] Inga nya ljud har tillkommit; befintlig ljudknapp och mix fungerar.
- [ ] Avbryt resor/kast med död, respawn och tappat fokus; kontroller återkommer.
- [ ] Öppna en äldre testprofil: mynt, spön, arter och mål återställs utan nollning.
- [ ] Nya akvarieval, teman, rekord och utseenden finns kvar efter återinträde.
- [ ] Testa offlinegåvan i publicerad privat testversion med riktiga Roblox-klienten.
- [ ] Kontrollera UI i 320 px porträtt, kort landskap, iPad och dator.
- [ ] Mät faktisk FPS/minne och inläsning på riktig telefon/iPad före publik release.


## v1.1 — material och vardagsliv, ännu okört i Roblox

Molnkontrollerna mäter exporterad geometri och kör produktionskod med dubblar.
De visar inte hur Roblox materialtexturer och normal maps faktiskt återges.

- [ ] Öppna Cloud-Anglers-v1.1.rbxlx, tryck Play och kontrollera Output.
- [ ] Granska träådring på bryggor, stolpar, bänkar, lådor och stammar nära kameran.
- [ ] Husens puts, takens skiffer och stenarnas struktur känns sammanhängande i skala.
- [ ] Gräs/sand skiljer sig tydligt från trä/sten utan skarpa, slumpmässiga färgfläckar.
- [ ] Markiser, vimplar, rep och invånarnas kläder har tygstruktur; fiskar/löv hålls lugnare.
- [ ] Inga gamla knoppar täcker trä, puts, skiffer eller portalgolv.
- [ ] Jämför material på låg, medel och hög grafik på dator, telefon och iPad.
- [ ] Ljuset är fortsatt dämpat; metall/glasyta bländar inte. Inga nya ljud.
- [ ] Gå fram till en invånare: kort blick/hälsning följs av återgång till sysslan.
- [ ] Kamerarörelse utan närliggande avatar får inte invånaren att hälsa på tom luft.
- [ ] Cafévärden står på verandan, med fri kropp och vågrät bricka.
- [ ] Reparationen sker över arbetsbänken och vattenkannan vattnar sin riktiga plantering.
- [ ] Captain Pips lina slutar vid flötet på vattenytan när handen rör sig.
- [ ] Gång, blinkningar och fåglars svängar känns lugna och varierade.
- [ ] Dammarnas silhuetter skiljer sig åt och låter blicken se bortom vattnet.
- [ ] Vattenfall har stöd under källan, faller framför berget och når vattenytan över hela bredden.
- [ ] Vattenränder tonar mjukt vid omlopp; inget hoppar ovanför/bredvid gardinen.
- [ ] Båten gungar men förtöjningens bryggände sitter fast; repet hänger ned mellan ändarna.
- [ ] Luftskeppet, väderkvarnen och portalrunorna återkommer med rätt pivot efter streaming.
- [ ] Parasollets tyg rör sig svagt medan stolpar, bord och stolar står stilla.
- [ ] Livbojen sitter på räcket; böcker, musselskal, krukor och bänkar har synligt stöd.
- [ ] Akvariepromenaden känns som en sammanhängande träbrygga, inte svävande plattor.
- [ ] Inget träd skymmer den normala kameravyn framför första akvariet.
- [ ] Ingen stor prototypfisk svävar längre ovanför hamnens damm.
- [ ] Samma fiske, spön, sparning, akvarier och resor fungerar efter ändringarna.
- [ ] Mät FPS/minne och kontrollera att rörelser återupptas efter avståndsstopp/streaming.


## v1.2 — befintlig terräng och modeller, ännu okörda i Studio

- [ ] Öppna **Cloud-Anglers-v1.2.rbxlx**, tryck Play och kontrollera Output.
- [ ] Följ de befintliga stigarna: rundade hörn ska vara sammanhängande och
  ligga mot marken utan flimmer, hål eller hinder för avataren.
- [ ] Titta på gräskullarna och öarnas sidor från broarna: rundade axlar,
  sammanhängande klippytor och en lugn jordkant under gräset.
- [ ] Titta upp genom lövträd och granar: sammanhängande kronor, naturlig
  volym och fortsatt mjuk vajning. Grenar ska möta kronan.
- [ ] Kontrollera mossan på stenarna och dammarnas klippavsatser: inga svävande
  partier eller övre klippdelar som hänger fritt. Vattenfallen når vattnet.
- [ ] Se taken från nära håll: tät anslutning mot gavlar, raka takpannskanter,
  genomtänkt färgskillnad mellan kafé, verkstad och stugor.
- [ ] Kontrollera de omformade tunnorna nära bryggan: stavar och band möts.
- [ ] Prova låg/hög grafikkvalitet och riktig mobil/iPad. Notera texturutseende,
  skuggor, minne och bildfrekvens; molnkontrollerna mäter inte detta.
- [ ] Fiska och använd varje portal; jämför befintlig progression och sparning.


## v1.3 — osynliga hinder och felplacerade delar, ännu okörda i Studio

- [ ] Öppna **Cloud-Anglers-v1.3.rbxlx**, tryck Play och kontrollera Output.
- [ ] Gå över hela startområdet: fötterna ska följa bryggan utan ett upphöjt
  osynligt steg. Respawn fungerar även när den tillfälliga byggplattan saknar kollision.
- [ ] Besök alla fem portaler. Vid långsam laddning ska själva gångdäcket vara
  synligt och bära spelaren även om portalens dekoration inte är laddad.
- [ ] Gå akvariepromenaden med flera spelare och fler rader. Samma synliga
  brädor ska bära spelaren även när fiskar, glas och dekor laddas ur.
- [ ] Titta under/utmed bryggorna och broarna: synligt trä under plankornas
  springor, inga osynliga gångytor som sticker ut över det fria vattnet.
- [ ] Gå runt och hoppa intill de stora stenarna. Ingen kollision i tom luft
  utanför de synliga sluttande stenytorna. Kontrollera kameran vid stenarna.
- [ ] Se båten från vattenhöjd under hela gungningen: skrovet möter vattnet,
  den torra durken och den triangulära fören håller sig innanför skrovet.
- [ ] Fiska i samtliga fem dammar; flötena ska hamna i fritt vatten.
- [ ] Prova riktig mobil/iPad och klientens streaming. Molnkontrollerna kör
  inte Roblox fysik eller nätverksladdning på en verklig enhet.


## v1.4 — fisk-, mås- och stranddetaljer, ännu okörda i Studio

- [ ] Öppna **Cloud-Anglers-v1.4.rbxlx**, tryck Play och kontrollera Output.
- [ ] Jämför alla 15 arter i journal, fångst och akvarier. Konturer och mönster
  ska skilja även arter med samma grundform, inte enbart deras färger.
- [ ] Se Normal, Golden och Prismatic. Ögon, mörka markeringar och ljusa detaljer
  ska behålla läsbar kontrast. Upprepade byten får inte flytta eller förstora delarna.
- [ ] Se största registrerade vikten för varje art i alla tre akvarieplatser:
  fenor, spröt och korallkronor hålls innanför glaset under hela simningen.
- [ ] Följ de sex måsarna genom glidflykt och fulla vingslag. Grå täckfjädrar
  och mörka vingpennor ska följa vingen utan glapp. Se ögon, näbb, stjärt och fötter.
- [ ] Kontrollera alla fem lagunernas staket från bryggan och sidostigar.
  Stenfoten möter bassängen, stolparna sitter fast och repen är förankrade.
- [ ] Använd varje portal och fiska. Staketet ska lämna gångvägar, kastmål,
  båtens tillfart och samtliga vattenfallsutlopp fria.
- [ ] Gå till akvarierna: däcket ska möta gräset utan blinkande överlappande ytor.
- [ ] Prova en riktig telefon och iPad. Anteckna bildfrekvens och minne;
  molnkontroller och offlinebilder bevisar inte Roblox-rendering eller prestanda.


## v1.5 — solida vingar och vattenkanter, ännu okörda i Studio

- [ ] Öppna **Cloud-Anglers-v1.5.rbxlx**, tryck Play och kontrollera Output.
- [ ] Se måsarna från bryggan, ovanifrån och underifrån: båda vingarnas vita
  ytor och mörka spetsar syns under glidflykt och hela vingslaget.
- [ ] Res bort och tillbaka så att måsarna laddas ur/in. Båda vingarna rör sig
  fortfarande och fjädrarna följer sina axelleder.
- [ ] Se samtliga fem dammkanter nära vattenhöjd. Stenkrönet döljer terrängens
  cellkanter, hörnen möts och inget torrt hål syns i den öppna vattenytan.
- [ ] Kontrollera stolparnas fötter, repens ändar och öppningarna vid bryggor
  och portaler. Gå genom varje portal och fiska på varje ö.
- [ ] Följ varje vattenfall från källa till nederkant. Inga klippor,
  bassänggolv eller osynliga ytor skär av flödet.
- [ ] Läs små vägskyltar, butiksskyltar och akvarieskyltar från båda håll.
  Prova ett långt spelarnamn; rubrik och underrad håller sig inom skylten.
- [ ] Granska lampor på bryggstolpar, hängande lampor, markisernas stöd,
  observatoriets skylt och planteringar: detaljer sitter fast i sina modeller.
- [ ] Jämför fiskar och mjuka modeller med deras avsedda proportioner. Kontrollera
  särskilt tyg/material på de inbyggda Sphere-mesharna i Roblox-renderingen.
- [ ] Prova faktisk mobil/iPad: bildfrekvens, minne och läsbarhet. Offlinebilder
  och geometrikontroller verifierar inte dessa resultat.


## v1.6 — ytstruktur och modellfinish, ännu okörda i Studio

- [ ] Öppna **Cloud-Anglers-v1.6.rbxlx**, tryck Play och kontrollera Output.
- [ ] Granska trä, tyg, skiffer, puts, kalksten och sand nära och på normalt
  kameraavstånd. Ådring, väv och stenstruktur syns utan störande upprepning.
- [ ] Kontrollera färgerna i sol och skugga: texturerna ska vara läsbara och
  kartan behagligt ljus med den befintliga eftermiddagsbelysningen.
- [ ] Kontrollera att alla sex material laddas utan återkommande texturfel i Output.
  Prova låg och hög grafiknivå samt riktig mobil och iPad; anteckna FPS/minne.
- [ ] Res mellan öarna och tillbaka till akvarierna. Ytmaterial återkommer när
  modeller laddas in igen; rörelser, fiske och gränssnitt fortsätter fungera.
- [ ] Se stenarna runt om, även vid grottan. Slutna sluttningar, markkontakt och
  mossytor ska hålla ihop utan stora utstickande skivor eller dolda hinder.
- [ ] Granska takens skifferlager, tunnornas band och staplade lådor från sidan:
  delarna sitter fast utan blinkande överlapp eller svävande mellanrum.
- [ ] Se fönsterlådorna nära: träändar och jord möts, och blommorna sitter i bladen.
  Kontrollera även bladfästena i stigarnas blomkrukor.
- [ ] Granska bryggbeslag, flöten, musslor, vimplar och picknickdetaljer. Koppar
  har tydliga vita kanter och teytor; kuddarnas tyg och vikningar håller ihop.
- [ ] Se fyrens kupol från utsiktsbalkongen och från marken. Metallribborna följer
  kupolen och ansluter till takkrans och topp utan avbrott.
- [ ] Fiska på alla fem öar och använd samtliga portaler. Befintliga gångvägar,
  kastbanor och ankomster förblir fria efter detaljändringarna.
