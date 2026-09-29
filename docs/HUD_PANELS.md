# HUD panelės

`MainHUDController` NavDock mygtukai ir Phone FAB kviečia `_G.CoachAcademyPanels[key]()`. Šiame aplanke esantis kodas užregistruoja visas 7 paneles:

| Raktas | Modulis | Turinys |
|---|---|---|
| `Profile` | `ProfilePanel` | Trenerio profilis: reputacijos lygis ir žvaigždės su progresu, 8 statistikos plytelės (kovotojai, pergalės, pergalių %, turnyrų titulai, balansas, pelnas, sekėjai, rėmėjai), karjeros kelias (Vietinės kovos → Regionas → WBF kontraktas → Reitingai → Pasaulio titulas), trofėjų lentyna |
| `Academy` | `AcademyPanel` | **Kovotojai:** sąrašas ir kortelė (statistika su genetinėmis lubomis/MAX, nuovargis, nuotaika + „Padrąsinti“, trauma + „Poilsio kambarys“, bandomasis laikotarpis, kovos stiliaus keitimas su stiprybėmis/silpnybėmis). **Įranga:** pirkimas. **Išvaizda:** pavadinimas, sienos, grindys, logotipas su gyva peržiūra |
| `Phone` | `PhonePanel` | Telefonas su „SocialGym“ programėle: įrašų skelbimas su cooldown'ais, veiklos srautas, reach iki kito walk-in kliento, bandomieji klientai, kiekvieno kovotojo atskira paskyra |
| `Staff` | `StaffPanel` | 5 darbuotojų tipai (Asistentas treneris, Jėgos treneris, Fizioterapeutas, Skautas, Mitybos specialistas), kiekvienas su % bonusu; samdymas/atleidimas (su patvirtinimu), atlyginimų suvestinė ir kiek laiko biudžeto užteks algoms |
| `Scout` | `ScoutPanel` | Talentų paieška (skautas), kandidatai su potencialu, **skauto ataskaitos** pirkimas (atskleidžia genetines lubas), samdymas; varžovų žvalgyba pagal karjeros lygį (su tavo geriausio to lygio kovotojo OVR žyme) + stilių ratas |
| `Sponsor` | `SponsorPanel` | Aktyvios sutartys (pajamų rinkimas su laikmačiu, paruoštos pajamos paryškinamos), pasiūlymai su visa verte ir prestižu, didesni rėmėjai pagal žvaigždes |
| `Tournament` | `TournamentPanel` | Turnyrai: kovotojo pasirinkimas, fight camp patikra (pasiruošimas, sveikata, nuovargis, laimėjimo tikimybė pagal tikrą kovos formulę), registracija, rezultatas. Karjeros laiptai: kiekvieno kovotojo progresas ir „Kovoti“ |

## Failai

```
src/
  ReplicatedStorage/Modules/Panels/
    PanelKit.lua          -- bendras UI rinkinys (paletė, mygtukai, kortelės, tabai, toast, panelių valdymas)
    ClientState.lua       -- vienas kliento duomenų šaltinis (visi *Update remote'ai + PanelSnapshot)
    ProfilePanel.lua, AcademyPanel.lua, PhonePanel.lua,
    StaffPanel.lua, ScoutPanel.lua, SponsorPanel.lua, TournamentPanel.lua
  StarterPlayer/StarterPlayerScripts/
    PanelsBootstrap.client.lua   -- registruoja paneles į _G.CoachAcademyPanels
  ServerScriptService/
    PanelDataHandler.server.lua  -- PanelSnapshot RemoteFunction + pelno (uždirbta/išleista) sekimas
    AcademyHandler / ScoutHandler / TournamentHandler / TrainingHandler (.server.lua) -- nedideli papildymai
  ReplicatedStorage/Modules/
    AcademyConfig / StaffConfig / ScoutConfig / MainHUDController (.lua) -- papildymai ir pataisymai
tools/
  build_place.luau   -- surenka CoachAcademy_panels.rbxl iš checkpoint + src/
  ui-preview/        -- Roblox mock + renderer + scenarijai (automatinis testavimas ir ekrano nuotraukos)
```

## Diegimas

**A. Paruoštas place failas (paprasčiausia):** atidaryk `CoachAcademy_panels.rbxl` Roblox Studio. Jį iš naujo sugeneruoja:

```
lune run tools/build_place.luau CoachAcademy_active2_checkpoint.rbxl CoachAcademy_panels.rbxl
```

**B. Rankiniu būdu esamame place:**
1. `ReplicatedStorage/Modules` sukurk Folder `Panels` ir į jį įdėk 9 ModuleScript'us iš `src/ReplicatedStorage/Modules/Panels/` (vardas = failo vardas be `.lua`).
2. `StarterPlayer/StarterPlayerScripts` sukurk LocalScript `PanelsBootstrap` (turinys iš `PanelsBootstrap.client.lua`).
3. `ServerScriptService` sukurk Script `PanelDataHandler`. `PanelSnapshot` ir `ScoutReportRequest` remote'us skriptai susikuria patys.
4. Atnaujink pakeistus failus: `AcademyConfig`, `StaffConfig`, `ScoutConfig`, `MainHUDController`, `AcademyHandler`, `ScoutHandler`, `TournamentHandler`, `TrainingHandler`.
5. Išjunk arba perkelk į `ServerStorage` senus UI skriptus: `AcademyUI`, `PhoneUI`, `FighterProfileUI`, `StaffUI`, `ScoutUI`, `SponsorUI`, `TournamentUI`, `EquipmentShopUI`. Jei jų nepamirši, `PanelsBootstrap` vis tiek neleis jiems perrašyti naujų panelių (įspėja Output'e).

## Serverio pakeitimai (trumpai)

- **PanelDataHandler (naujas):** `PanelSnapshot` grąžina pilną profilio būseną atidarant panelę, todėl panelės visada rodo tikslius duomenis net jei pradiniai serverio pranešimai praleisti.
  - Užklausos ribojamos: dažniau nei kas 0,3 s grąžinama ką tik sudaryta būsena.
  - Skaičiuoja `profile.lifetimeEarned` / `lifetimeSpent` (Profilio „Pelnas“) iš balanso pokyčių kas sekundę. Pelnas tikslus, bet jei pajamos ir išlaidos įvyksta tą pačią sekundę, „uždirbta/išleista“ skaidymas jas sutraukia.
- **AcademyHandler / AcademyConfig:** grindų pasirinkimas (`FloorOptions`, `profile.floorColorIndex`, taikoma `GymLayout.Floor`). Pirmas variantas = esamos grindys. Pavadinimo taisymai:
  - Trumpinama simboliais, ne baitais. Anksčiau lietuviška raidė galėjo būti perkirpta pusiau, ir DataStore tokio (netinkamo UTF-8) profilio nebeišsaugodavo.
  - Pavadinimas filtruojamas per `TextService`, nes jis matomas visiems ant iškabos.
  - NaN/inf indeksai atmetami.
- **TournamentHandler:** laimėjus turnyrą `profile.trophies[pavadinimas] += 1` (trofėjų lentyna); „čempionu“ su diakritika.
- **StaffConfig:** samdymo sąraše 5 koncepcijos tipai. Nauji: Asistentas treneris (+10% visoms treniruotėms), Skautas (−30% paieškos kaina, perpus trumpesnis laukimas), Mitybos specialistas (−25% nuovargio). `SpeedCoach` / `MentalCoach` lieka `Roles` (esami save'ai), tik nebesamdomi.
- **TrainingHandler:** Mitybos specialisto nuovargio daugiklis. **ScoutHandler:** Skauto nuolaida, `ScoutReportRequest` (skauto ataskaita, $40), genetinės lubos klientui siunčiamos tik nupirkus ataskaitą.
- **MainHUDController:**
  - `UIGradient` daugina spalvas iš `BackgroundColor3`, todėl StatusPanel ir NavDock buvo beveik juodi. Dabar fonas baltas ir matomi tikri `bgCardLight → bgCard`.
  - Phone FAB šešėlis dabar apvalus.
  - Pinigai ir reputacija papildomai imami iš `ClientState`. Anksčiau pradinį serverio pranešimą galėjo „pagauti“ kitas skriptas, ir HUD visą sesiją rodė „$ 500“ / „Vietinis treneris“.

## Testavimas be Studio (`tools/ui-preview`)

`run.luau` paleidžia **tikrus** serverio handlerius ir klientines paneles viename procese, Roblox API mock'e:
- savybės ir enum'ai validuojami pagal oficialų API dump'ą;
- RemoteEvent'ai veikia su tinklo kopijavimu ir eilėmis;
- `task` planuoklis naudoja virtualų laiką.

Scenarijai (`scenarios.luau`) paspaudžia mygtukus ir tikrina serverio būseną, pvz., „nupirkta įranga, nuskaičiuoti pinigai“. Kaip ir Roblox, paspausti galima tik matomą mygtuką (jei jis ar jo tėvas `Visible = false`, scenarijus krenta). `shoot.js` suskaičiuoja Roblox išdėstymą (UIListLayout, UIGridLayout, AutomaticSize, ScrollingFrame, UIStroke, UIGradient, CanvasGroup) ir daro ekrano nuotraukas. Taip pat randa teksto perpildymą.

```
cd tools/ui-preview
python3 fetch_assets.py      # vieną kartą: API dump + šriftai
./all.sh                     # visi scenarijai + nuotraukos -> shots/
./all.sh academy flow_post   # tik nurodyti

# galutinio place failo patikra (visi skriptai skaitomi iš .rbxl, ne iš src/)
COACH_PLACE_ONLY=1 COACH_PLACE=../../CoachAcademy_panels.rbxl lune run run.luau flow_customize
```

Ko mock'as **negali** patikrinti: tikro įvesties hit-testing, našumo mobiliuosiuose ir Roblox teksto atvaizdavimo (Montserrat čia pakeičia Gotham). Po įdiegimo verta Studio (Play) greitai paspaudyti kiekvieną panelę, ypač telefono (Device Emulator) režimu.

## Kokybės procesas

1. **Creator:** kodas ir scenarijai.
2. **Art Director / Critic:** dvi vizualinės peržiūros pagal nuotraukas, plius atskira inžinerinė Roblox runtime peržiūra.
3. **Polisher:** pataisyta, kas rasta, pavyzdžiui:
   - toast'ai perkelti į panelės apačią;
   - crimson spalva naudojama tik neigiamoms būsenoms;
   - 12 px teksto minimumas;
   - kompaktiškas (telefono) režimas;
   - `Active` paviršius, kad paspaudimai neprakristų ir neuždarytų panelės;
   - CanvasGroup pakeistas paprastu Frame;
   - UTF-8 pavadinimų taisymas.
4. **Antras Art Director ratas:**
   - prilipę veiksmų mygtukai apačioje (Akademijos išvaizda, Turnyrai), kad pagrindinis veiksmas visada matomas;
   - siaurame ekrane sąrašas → detalės su „atgal“ mygtuku;
   - neaktyvus mygtukas atrodo kaip būsena (pvz. „⏱ Palauk 0:15“), o ne kaip sugedęs mygtukas;
   - vienodos potencialo žymės, žvaigždės ir lietuviški pavadinimai visose panelėse;
   - rėmėjų logotipų spalvos pritrauktos prie paletės.
