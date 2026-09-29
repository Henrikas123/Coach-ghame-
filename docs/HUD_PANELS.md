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
