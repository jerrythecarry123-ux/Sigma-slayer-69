# Cloud Anglers v0.2 — testprotokoll

## Automatiskt verifierat i molnmiljön

- 19 Luau-tester av de riktiga reglerna och serverns tillståndsmaskin passerade.
- 2 Python-tester för korrekt inbäddade källfiler och repeterbar platsbyggnad
  passerade.
- Alla 10 Luau-produktionsfiler samt Luau-testfilen accepterades av den
  officiella Luau-kompilatorn. Detta är en syntaxkontroll, inte ett Roblox-typbevis.
- Typkontrollen passerade för FishingConfig, FishingRules, FishingEngine och
  Luau-testsviten. Roblox-beroende filer behöver fortfarande kontrolleras i Studio.
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
- [ ] Försök fiska direkt vid spawn: ingen fångst, instruktion om blå rutan.
- [ ] Gå till blå rutan, fiska och upprepa minst tio gånger.
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
