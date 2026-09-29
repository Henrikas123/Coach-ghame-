# Coach Academy: UI dokumentacija

Visas žaidimas angliškas: HUD, panelės, serverio žinutės, pavadinimai ir užrašai pasaulyje. Roblox automatinis vertimas veikia nuo anglų kalbos, todėl žaidėjai kitose šalyse matys savo kalbą.

Žaidėjo kelias: **krovimo ekranas → titulinis ekranas (PLAY) → HUD ir panelės**.

## 1. Krovimo ekranas (`ReplicatedFirst/LoadingScreen`)
„Fight Night“ stilius:
- judantys prožektoriai;
- minia su fotoaparatų blykstėmis;
- ringo virvės;
- čempiono diržas, kuris pildosi auksu nuo centro;
- patarimai;
- „A GAME BY HENYTE“.

**Progresas tikras:** žaidimo įkėlimas → ikonų ir garsų įkrovimas → žaidėjo profilis iš DataStore. Dirbtinio laukimo nėra, tik 2,4 s logotipo animacijai. Po 5 s atsiranda **SKIP**.

**Pabaiga:** „INTRODUCING …“ su žaidėjo akademijos pavadinimu ir reputacija. Naujam žaidėjui rodoma „THE NEXT CHAMPION COACH“.

## 2. Titulinis ekranas (`StarterPlayerScripts/TitleScreen`)
- **Kamera:** lėtai skrieja aplink sporto salę; spalvų korekcija, gylio efektas, kino juostos viršuje ir apačioje.
- **Mygtukai:** **PLAY** (arba Enter / gamepad A), MUSIC / SOUND jungikliai.
- **„Welcome back“ kortelė:** kas laukia žaidėjo (paruoštos rėmėjų pajamos, pailsėję kovotojai, traumos, atviri turnyrai). Naujam žaidėjui rodomi pirmi žingsniai.
- **Iki PLAY paslėpta:** HUD, žaidėjų sąrašas ir judėjimas.

## 3. HUD (`MainHUDController`)
- **StatusPanel:** čempiono diržo plokštelė.
  - Medalione yra brangakmenis pagal reputaciją: Bronze → Silver → Gold → Sapphire → Ruby.
  - Pinigai animuotai skaičiuojasi, iššoka „+$25“ / „-$150“.
  - Pakilus lygiui medalionas pulsuoja ir groja garsas.
- **NavDock:** ringo kraštas su raudonu ir mėlynu kampais bei trimis virvėmis. Atidarytos panelės mygtukas šviečia.
- **Telefono mygtukas:** ženkliukas rodo, kiek įrašų galima paskelbti.

## 4. Panelės
| Raktas | Modulis | Turinys |
|---|---|---|
| `Profile` | `ProfilePanel` | Reputacija, 8 statistikos plytelės, karjeros kelias, trofėjų lentyna |
| `Academy` | `AcademyPanel` | Kovotojai kaip kolekcinės kortelės (OVR retumo rėmelyje), statistika, būklė, stilius; įranga; salės išvaizda |
| `Phone` | `PhonePanel` | SocialGym: įrašai, veikla, klientai, kovotojų paskyros |
| `Staff` | `StaffPanel` | 5 darbuotojų tipai su % bonusu, samdymas/atleidimas, kiek laiko biudžeto užteks algoms |
| `Scout` | `ScoutPanel` | Talentų paieška, skauto ataskaita (genetinės lubos), varžovų lygiai su tavo geriausio kovotojo OVR žyme |
| `Sponsor` | `SponsorPanel` | Sutartys, pajamų rinkimas, pasiūlymai su prestižu |
| `Tournament` | `TournamentPanel` | Turnyrai, Fight Camp patikra, **Tale of the Tape** (tavo kovotojas prieš varžovų lygį), rezultatai, karjeros laiptai |

Visų panelių bendras stilius:
- antraštės `Oswald` šriftu;
- atsidarymas su „smūgio“ efektu;
- garsai mygtukams, klaidoms ir atidarymui.

## 4a. Kovos ekranas (`StarterPlayerScripts/FightUI`) — TV transliacija
- **FIGHT NIGHT pasirinkimas:** prie ringo paspaudus E rodomi kovotojai su OVR kortelėmis, būsena ir „Send in“.
- **Transliacijos grafika:**
  - kino juostos su „FIGHT NIGHT ● LIVE“;
  - „Tale of the Tape“ pristatymas (raudonas ir mėlynas kampai, statistikos juostos);
  - rezultatų lenta su raundų taškais.
- **Raundas:**
  - „ROUND 1“ / „FIGHT!“ užrašai su gongu;
  - momentum juosta su komentarais, kuri baigiasi tikru raundo rezultatu;
  - „MARTIN TAKES R1“.
- **Tarp raundų:** kampo planas su 4 pasirinkimais ir laikmačiu.
- **Pabaiga:** WINNER / DEFEAT kortelė, pergalės atveju konfeti ir minios garsas.
- **Serveris daro pauzes** (`FightConfig.IntroSeconds`, `RoundRevealSeconds`), kad animacijos spėtų.

## 4b. Kasdienis prizas, užduotys, lyderių lenta (`RetentionHandler`, `GoalsPanel`)
- **Prisijungimo serija:** 7 dienos, $100 → $1,000, 7-ą dieną +5 reputacijos. Praleidus dieną serija prasideda iš naujo. Dienos skaičiuojamos pagal UTC.
- **Kasdienės užduotys:** 3 per dieną. Pirmoji visada įvykdoma naujokui, perprisijungus užduotys nesikeičia. Progresą praneša treniruočių, kovų, įrašų, rėmėjų, turnyrų, padrąsinimo ir skautų handleriai.
- **Top Coaches:** reputacijos lyderių lenta (OrderedDataStore) „Daily Goals“ panelėje ir stende mieste prie salės išėjimo. Stendą (`Workspace.Town.LeaderboardBoard`) Studio galima perkelti.
- **HUD:** mygtukas „DAILY GOALS“ viršuje dešinėje rodo atliktas užduotis ir raudoną tašką, kai yra ką atsiimti. Panelė pati atsidaro po PLAY, jei laukia dienos prizas.
- **Konfigūracija:** `RetentionConfig.lua` (prizai, užduotys, jų atlygiai).

## 4c. Pamoka pirmoms 5 minutėms (`TutorialHandler`, `Tutorial`, `TutorialConfig`)
6 žingsniai:
1. Sveikinimas.
2. ACADEMY.
3. 2 treniruotės (auksinis spindulys ir „TRAIN HERE“).
4. Pirma kova („FIGHT HERE“).
5. Įrašas telefone.
6. Daily Goals.

Pabaigoje +$250. HUD mygtukai paryškinami pulsuojančiu žiedu su rodykle. Grįžę žaidėjai su progresu pamoką praleidžia automatiškai, bet kas gali ją praleisti mygtuku „Skip guide“.

Pirmasis kovotojas Alex dabar pradeda su statistikomis 14 (buvo 1). Taip jis pasiruošęs kovai po 2 treniruočių, ir pirma kova pasiekiama per pamoką.

## 4d. Duomenų saugumas (`DataStoreHandler`)
- **Pakartotiniai bandymai:** jei DataStore neatsako.
- **Sesijos užraktas:** du serveriai niekada nerašo to paties profilio. Naujas serveris palaukia, kol senas išsaugos.
- **Nepavykęs įkėlimas:** tuščias profilis niekada neišsaugomas, žaidėjui pasiūloma prisijungti iš naujo. Anksčiau būtent taip buvo galima prarasti visą progresą.
- **Automatinis išsaugojimas:** kas 2 min, o išjungiant serverį visi saugomi lygiagrečiai.
- **Seni išsaugojimai:** papildomi naujais laukais (`dataVersion`), NaN reikšmės išvalomos.
- **Tikras išsaugojimas veikia tik paskelbtame žaidime:** Studio reikia Game Settings → Security → „Enable Studio Access to API Services“.

## 5. Garsai (`ReplicatedStorage/Modules/SoundConfig`)
Kiekvienas garsas turi slotą su `id = ""`. Tuščias slotas tiesiog praleidžiamas, todėl žaidimas veikia ir be garsų. Įrašyk `"rbxassetid://..."`:

| Slotas | Kas tai |
|---|---|
| `Click` | mygtuko paspaudimas / pirštinės tuktelėjimas |
| `PanelOpen` | trumpas „whoosh“ atidarant panelę |
| `Error` | švelnus „negalima“ |
| `Cash` | pinigų gavimas („ka-ching“) |
| `LevelUp` | reputacijos lygio pakilimas |
| `Bell` | bokso gongas („ding-ding“), krovimo pabaiga ir PLAY |
| `Punch` | stiprus smūgis |
| `Crowd` | minios ovacijos |
| `LoadingMusic` | fono muzika krovimo ir titulinio ekrano metu (kartojama) |

## 6. Ikonos (`assets/icons/` + `ReplicatedStorage/Modules/IconConfig`)
10 baltų linijinių ikonų (256×256 PNG): profile, academy, staff, scout, sponsor, tournament, phone, money, belt, glove. Roblox jas nuspalvina (`ImageColor3`).

1. Studio: **View → Asset Manager → Bulk Import** ir pasirink failus iš `assets/icons/`.
2. Kiekvienos ikonos ID įrašyk į `IconConfig.lua` (`image = "rbxassetid://..."`).
3. Kol ID tuščias, rodomas emoji.

Ikonas iš naujo sugeneruoja `node tools/icons/make_icons.js`; `assets/icons/_preview.png` yra peržiūra.

## 7. Failai
```
src/
  ReplicatedFirst/LoadingScreen.client.lua
  ReplicatedStorage/Modules/
    MainHUDController, SoundConfig, Sfx, IconConfig, visi *Config ir DataSchema
    Panels/  PanelKit, ClientState, 7 panelių moduliai
  ServerScriptService/   visi serverio handleriai (*.server.lua)
  StarterPlayer/StarterPlayerScripts/
    TitleScreen, PanelsBootstrap, MainHUDBootstrap, FightUI, TrainingUI, ReputationUI
assets/icons/            PNG ikonos
tools/build_place.luau   surenka CoachAcademy_panels.rbxl
tools/ui-preview/        Roblox mock + renderer + scenarijai
tools/icons/             ikonų generatorius
```

## 8. Diegimas
**Paprasčiausia:** atidaryk `CoachAcademy_panels.rbxl` Roblox Studio. Jį iš naujo sugeneruoja:
```
lune run tools/build_place.luau CoachAcademy_active2_checkpoint.rbxl CoachAcademy_panels.rbxl
```

Build'as taip pat:
- išverčia treniruočių ir ringo `ProximityPrompt` užrašus;
- perkelia senus UI skriptus į `ServerStorage/LegacyUI`.

## 9. Serverio pakeitimai (trumpai)
- **PanelDataHandler:** `PanelSnapshot` (pilna būsena atidarant panelę, ribojama kas 0,3 s), pelno sekimas.
- **Personalas:** 5 tipai (Assistant Coach, Strength Coach, Physio, Talent Scout, Nutritionist). Speed Coach ir Sports Psychologist lieka seniems save'ams.
- **Skautai:** skauto ataskaita ($40) atskleidžia genetines lubas.
- **Turnyrai:** trofėjai.
- **Akademija:**
  - grindų pasirinkimas;
  - pavadinimas filtruojamas per `TextService`;
  - UTF-8 saugus trumpinimas.

## 10. Testavimas be Studio (`tools/ui-preview`)
Mock paleidžia **tikrus** serverio ir kliento skriptus:
- savybės tikrinamos pagal Roblox API;
- virtualus laikas;
- RemoteEvent'ai su eilėmis.

`shoot.js` daro ekrano nuotraukas ir randa nukirptą tekstą. Paspausti galima tik matomus mygtukus.

```
cd tools/ui-preview
python3 fetch_assets.py            # vieną kartą: API dump + šriftai
./all.sh                           # visi scenarijai -> shots/
./all.sh loading title flow_play   # krovimas, titulinis, PLAY
```

**Ko mock'as negali:** tikrų paspaudimų, 3D vaizdo, našumo telefone. Po įdiegimo Studio paspaudyk viską, ypač telefono režimu (Test → Device).
