# MES Analysis Index

This section collects the reverse-engineering results that are currently spread
across scene, system, data, and tool documents. It is organized by the remake
scene that consumes each result.

The authoritative source is the configured raw `ELFIMAGE/mes.arc`. Generated
IR, JSON projections, and these notes are audit aids. They never replace a
check against the archive when a new original-behavior claim is made.

See also the [caller-derived route classification](event_route_classification.md) for all literal EVENT candidates and explicitly unresolved routes.

## Scene Map

| Remake area | Principal original scripts | Analysis document |
|---|---|---|
| Shared loader, expressions, and control flow | all `.MES` entries | [Format and Method](format_and_method.md) |
| Town, train, grounds, and school-floor movement | `MACHI.MES`, `TRAIN.MES`, `GROUND.MES`, `FLOOR1.MES`--`FLOOR5.MES`; paired `MPC/CCD/EVE` data | [Map Movement Sources](map_movement_sources.md) |
| All movement-map location entry messages | `MACHI.MES`, `TRAIN.MES`, `GROUND.MES`, `FLOOR1.MES`--`FLOOR5.MES` | [Map Location Entries](map_location_entries.md) |
| Town map and fish-shop encounter dispatch | `MACHI.MES`, `12C.MES`, `D_PIC.MES` | [Town Map](town_map.md) |
| Saturday school-day and vacation starts | `27C_EV.MES`, `11C_EV.MES`, `FLOOR5.MES`, `MACHI.MES`, `LIBLARY.LIB` | [Saturday Start Routing](saturday_start.md) |
| Protagonist room and dormitory corridor round trip | `43C.MES`, `44C.MES` | [Room and Dormitory Corridor](room_screen.md) |
| Ordinary encounter conversation | `12C.MES`, `A_TALK*.MES`--`L_TALK*.MES` | [Normal Conversation](normal_conversation.md); the whole family and its call sites: [Talk Family](talk_family.md) |
| Encounter dialogue projection | `12C.MES`, `D_INTRO.MES`, `D_TALK50.MES`, `D_OUTRO.MES` | [Encounter Dialogue Projection](encounter_dialogue_projection.md) |
| Maki dialogue events and fragment catalogs | `EVENTD01.MES`, `EVENTD02.MES`, `EVENTD03.MES`, `EVENTD05.MES`, `EVENTD06.MES`, `EVENTD08.MES`, `EVENTD14.MES`, `01M.MES`, `10C.MES`, `12C.MES`, `D_PIC.MES` | [Character Events](character_events.md) |
| Mahoko event CG, source-commanded camera, and station return | `EVENTB03.MES`, `EVENTB14.MES`, `01M.MES`, `B_PIC.MES`, `LIBLARY.LIB` | [Character Events](character_events.md) |
| Mahoko B03 choices 1/2, bounded starting state and branch-local terminals | `EVENTB03.MES`, `B_PIC.MES`, `LIBLARY.LIB` | [B03 Choice Routes](eventb03_choice_routes.md) |
| Caller-qualified J04 branch matrix and callee-owned MACHI handoff, with native effects omitted | `01M.MES`, `EVENTJ04.MES`, `LIBLARY.LIB` | [J04 Analysis Route](eventj04_route.md) |
| Mahoko B03 result-2 numeric state12 branches, restoration and user-supported money hypothesis | `EVENTB03.MES`, `B_PIC.MES`, original EXE | [B03 State12 Routes](eventb03_state12_routes.md) |
| Mahoko B03 result-2 affection clamp and source-bound expression representatives | `EVENTB03.MES`, `B_PIC.MES`, original EXE | [B03 Affection Routes](eventb03_affection_routes.md) |
| Mahoko B03 existing state12/affection presets with results 1/3, unchanged outer traces and exact numeric outcomes | `EVENTB03.MES`, `B_PIC.MES`, `DEF_MAIN.MES`, original EXE | [B03 Preset Choice Routes](eventb03_preset_choice_routes.md) |
| Mahoko B03 numeric face flags, exact equality and threshold neighbors without product-preset promotion | `EVENTB03.MES`, `B_PIC.MES`, original EXE | [B03 Face Flag Routes](eventb03_face_flag_routes.md) |
| Mahoko B03 station candidate guard, source-linear prelude and unresolved natural-entry boundary | `01M.MES`, `MACHI.MES`, `EVENTB03.MES`, original EXE | [B03 Station Candidate Route](eventb03_candidate_entry.md) |
| Station candidate source priority before B03, with first-match stop and conditional zero-start prefix | `01M.MES`, `MACHI.MES`, `MACHI.EVE`, original EXE | [Station Candidate Priority](station_candidate_priority.md) |
| Station entry-zero conditional prefix, exact local CFG and ordered unresolved external boundaries | `01M.MES`, `MACHI.MES`, `MACHI.EVE`, original EXE | [Station Candidate Prefix](station_candidate_prefix.md) |
| Frozen-state composition of the station priority cascade and B03 candidate guard | `01M.MES`, original EXE | [Station-to-EVENTB03 Decision](station_eventb03_decision.md) |
| Source-bound station background selection across numeric date/time branches, stopping before native refresh | `LIBLARY.LIB`, `01M.MES`, `EVENTB03.MES`, original EXE | [Station Background Selection](station_background_selection.md) |
| Source-bound Mahoko date-dependent standing selection with symbolic copy inputs, stopping before routine 22 | `B_PIC.MES`, original EXE | [Mahoko Standing Selection](mahoko_standing_selection.md) |
| Archive-wide literal script-dispatch caller graph bounding the event corpus | all `.MES`/`.LIB` entries | [Event Corpus Inventory](event_corpus_inventory.md) |
| Where every entry is named once the strict decoder's opaque tails are scanned, bounding any unreachability claim | all `.MES`/`.LIB` entries, `START.MES`, `FLOOR4.MES` | [Dispatch Naming Reachability](dispatch_naming_reachability.md) |
| Entries whose name occurs nowhere in 1.5 GB of shipped data, and EVENTL09 as a pre-voice build of EVENTL10 | all `.MES`/`.LIB` entries, `EVENTL09.MES`, `EVENTL10.MES`, original EXE | [Unreferenced Entries](unreferenced_entries.md) |
| Archive-wide byte-identical message groups: the 365-entry replay gallery behind thirteen heroine menus, 27 EVENT entries and every ending with a gallery copy, and four shared scripts stored twice | all `.MES`/`.LIB` entries, `SCENE_*.MES`, `*_M.MES` | [Duplicate Entries](duplicate_entries.md) |
| The 44M caller group's eleven EVENT intros, which of them are cleanly guarded, all eleven measured and ten qualified, J11 last once Core 0.316.0 could read its second body | `44M.MES`, `EVENTC18.MES`, `EVENTH11.MES`, `EVENTF22.MES`, `EVENTF17.MES`, `EVENTF06.MES`, `EVENTL10.MES`, `EVENTH18.MES`, `EVENTI14.MES`, `EVENTA22.MES` | [44M Caller Group](44m_caller_group.md) |
| The 01M station caller group's nine EVENT intros: the two guard cascades, which intros are cleanly guarded, which stand behind the station's own choice, every guard read as a scene condition, D05, G11, I16 and L03 qualified, and H07, M06 and M09 qualified through the train's map-location contract (Core 0.318.0), every intro declared | `01M.MES`, `EVENTH07.MES`, `EVENTM06.MES`, `EVENTM09.MES`, `EVENTD05.MES`, `EVENTI16.MES`, `EVENTG11.MES`, `EVENTL03.MES` | [01M Caller Group](01m_caller_group.md) |
| The FLOOR5 school-floor caller group's seven EVENT intro sites, all nested calls: five clean guards with an M18/H10/H16 chain behind one selection result, two sites with no guard at all declared on the v9 shape, and E15 as one event with two entrances | `FLOOR5.MES`, `EVENTF01.MES`, `EVENTG21.MES`, `EVENTE15.MES`, `EVENTM18.MES`, `EVENTH10.MES`, `EVENTH16.MES` | [FLOOR5 Caller Group](floor5_caller_group.md) |
| The 18M caller group's six EVENT intros: an I05/I09/M16 chain with two intros behind the caller's own selection, and guards that are earlier groups' predicates moved along their arcs, all six qualified | `18M.MES`, `EVENTC11.MES`, `EVENTI05.MES`, `EVENTI09.MES`, `EVENTK13.MES`, `EVENTL04.MES`, `EVENTM16.MES` | [18M Caller Group](18m_caller_group.md) |
| The 44C dormitory caller group's six EVENT intro sites: two independent guards, an M17/M10/M10/M03 ladder behind the dormitory's own selection answered 3, M10's two entrances told apart by one flag, M03's calendar-only disjunction, and M10's visit ladder that reaches `EVENTM11` on its second to fourth visits behind a 23-flag gate (2026-09-23) | `44C.MES`, `EVENTI24.MES`, `EVENTL25.MES`, `EVENTM03.MES`, `EVENTM10.MES`, `EVENTM11.MES`, `EVENTM17.MES` | [44C Caller Group](44c_caller_group.md) |
| The 17M caller group's five EVENT intro sites, four of them root handoffs back to the town map: three independent clean guards and an A20 tree with two entrances told apart by one flag behind the caller's own selection | `17M.MES`, `EVENTA02.MES`, `EVENTA10.MES`, `EVENTA20.MES`, `EVENTC10.MES` | [17M Caller Group](17m_caller_group.md) |
| The 23M caller group's five EVENT intro sites, all root handoffs back to GROUND: two false-edge ladders of Saturday-afternoon guards, the C family below and above one affection bar and the E family beside it | `23M.MES`, `EVENTC02.MES`, `EVENTC05.MES`, `EVENTC17.MES`, `EVENTE01.MES`, `EVENTE03.MES` | [23M Caller Group](23m_caller_group.md) |
| The 21C caller group's four EVENT intro sites in one ladder: a joint A-and-E event behind the caller's own question with two entrances, the C family's summer morning and the L family's summer late morning as a nested call | `21C.MES`, `EVENTA08.MES`, `EVENTC08.MES`, `EVENTL07.MES` | [21C Caller Group](21c_caller_group.md) |
| The 26M caller group's four EVENT intro sites, all root handoffs back to GROUND: the C family's spring and November Saturdays on 23M's pattern and an H-family afternoon, with C01's callee asking its own question | `26M.MES`, `EVENTC01.MES`, `EVENTC04.MES`, `EVENTC21.MES`, `EVENTH06.MES` | [26M Caller Group](26m_caller_group.md) |
| The town map's four unresolved EVENT intro sites: three E-family events behind the map's own destination choice, read back from MACHI.INC, and a G-family event behind one flag, two of them root handoffs with their own questions | `MACHI.MES`, `EVENTE04.MES`, `EVENTE10.MES`, `EVENTE18.MES`, `EVENTG04.MES` | [MACHI Caller Group](machi_caller_group.md) |
| The 03C caller group's three EVENT intro sites, all root handoffs: J15 as the Saturday that opens J14, J14's two sites counted by visits, both callees two-bodied with their own questions and several doors back to the town map | `03C.MES`, `EVENTJ14.MES`, `EVENTJ15.MES` | [03C Caller Group](03c_caller_group.md) |
| The 07M caller group's three EVENT intro sites, all root handoffs back to the town map: an A-family evening on a stored date, a G-family event behind five flags, and a J-family winter evening behind the caller's own question whose callee asks a second one with three doors | `07M.MES`, `EVENTA19.MES`, `EVENTG14.MES`, `EVENTJ19.MES` | [07M Caller Group](07m_caller_group.md) |
| The 11M caller group's three unresolved EVENT intro sites: the J family's spring weekday and the H-and-K winter weekday as nested calls whose guards the caller closes after the return, and the H family's summer weekday as a root handoff | `11M.MES`, `EVENTJ01.MES`, `EVENTH04.MES`, `EVENTK14.MES` | [11M Caller Group](11m_caller_group.md) |
| The 12C town place's five EVENT intros (Maki events D01, D02, D03, D08, D14) measured as analysis groups on 2026-09-21: nested calls returning to a caller that hands the root to MACHI, D01/D08/D14 by the callee's answer, D02's same-day gate on the D01 stamp | `12C.MES`, `EVENTD01.MES`, `EVENTD02.MES`, `EVENTD03.MES`, `EVENTD08.MES`, `EVENTD14.MES`, `D_PIC.MES` | [12C Caller Group](12c_caller_group.md) |
| The 13C town place's two EVENT intros (Mahoko events B01, B02) measured as analysis groups on 2026-09-21: nested calls returning to a caller whose date-selected BGM prefix precedes the MACHI handoff | `13C.MES`, `EVENTB01.MES`, `EVENTB02.MES` | [13C Caller Group](13c_caller_group.md) |
| The 15C caller group's three EVENT intro sites, every callee asking its own three-answer question: the I family's Saturday with two date windows as a root handoff by several doors, and the C and E families' weekdays as nested calls whose callees close their own gates | `15C.MES`, `EVENTI10.MES`, `EVENTC06.MES`, `EVENTE11.MES` | [15C Caller Group](15c_caller_group.md) |
| The 25C caller group's three EVENT intro sites, the first whose doors lead to the school ground: the F family's winter Saturday and the A family's Saturday lunchtime (its callee's three answers converging on one door, its guard reading the event stamp) as root handoffs, and the E family's spring Saturday as a nested call | `25C.MES`, `EVENTF20.MES`, `EVENTA03.MES`, `EVENTE05.MES` | [25C Caller Group](25c_caller_group.md) |
| The 30C caller group's three EVENT intro sites for one target: the G family's Saturday art-room visit as a ladder of first visit, first return and every return after, its callee dispatching a talk script by the G word's band and handing off to the second floor | `30C.MES`, `EVENTG01.MES` | [30C Caller Group](30c_caller_group.md) |
| The 35M caller group's three EVENT intro sites in one ladder of Saturday guards, all root handoffs to the fifth floor: the G family's spring afternoon whose first visit opens 30C's G01, the L family's spring Saturday behind a gate the callee sets early, and the I family's autumn-to-winter Saturday | `35M.MES`, `EVENTG02.MES`, `EVENTL02.MES`, `EVENTI13.MES` | [35M Caller Group](35m_caller_group.md) |
| The 05M caller group's two EVENT intro sites: the J family's weekday evening as a root handoff whose caller closes its own clear flag, and the L family's spring evening as a nested call whose callee asks two questions and replaces the root itself by one of two doors | `05M.MES`, `EVENTJ07.MES`, `EVENTL06.MES` | [05M Caller Group](05m_caller_group.md) |
| The 06C caller group's two EVENT intro sites: the L family's summer day as a nested call whose callee asks its own three-answer question and sets its gate early, and the J family's weekday evening as a nested call with no question, both closed by the caller after the return and resumed into the floor's own six-definition question | `06C.MES`, `EVENTL08.MES`, `EVENTJ18.MES` | [06C Caller Group](06c_caller_group.md) |
| The 09M caller group's two EVENT intro sites: the L family's autumn weekday as a root handoff behind the caller's own two-answer question, and Christmas Eve afternoon as a root handoff whose callee asks two answers and leaves by 44C or the town; the town map names 09M at the source-audited code coordinate 56863 | `09M.MES`, `EVENTL11.MES`, `EVENTM20.MES` | [09M Caller Group](09m_caller_group.md) |
| The 27C_EV caller group's two EVENT intro sites: the dormitory floor's M-family event on any day behind two flags, and its April 22 follow-up, both nested calls the caller closes itself before walking on into the floor's day; the floor is named by two source-audited typed handoffs in 43C_ASA | `27C_EV.MES`, `EVENTM01.MES`, `EVENTM14.MES` | [27C_EV Caller Group](27c_ev_caller_group.md) |
| The FLOOR4 caller group's three EVENT intro sites: the F family's appointment on a stored date as a nested call the callee closes itself, and, behind the map's arm 4, the A family's autumn scene and the L family's winter piano scene as root handoffs whose callees ask three answers and hand the root back to the floor | `FLOOR4.MES`, `EVENTF03.MES`, `EVENTA13.MES`, `EVENTL18.MES` | [FLOOR4 Caller Group](floor4_caller_group.md) |
| The FLOOR1 caller group's two EVENT intro sites for one target: the I family's spring eavesdropping in three stages behind the map's arm 3, each stage a root handoff that leaves by its own door and the floor's exits closing the day | `FLOOR1.MES`, `EVENTI04.MES` | [FLOOR1 Caller Group](floor1_caller_group.md) |
| The 19C caller group's one EVENT intro site: the L family's spring Saturday as a root handoff whose callee closes its own gate and leaves for the town | `19C.MES`, `EVENTL05.MES` | [19C Caller Group](19c_caller_group.md) |
| The 27C1A caller group's one EVENT intro site: the C family's spring Saturday early afternoon as a root handoff whose callee stores the date, closes two conjuncts and stamps 27 on its way to FLOOR1 | `27C1A.MES`, `EVENTC03.MES` | [27C1A Caller Group](27c1a_caller_group.md) |
| The 29C caller group's one EVENT intro site: the A family's spring Saturday early afternoon as a root handoff whose guard excludes its own stamp and whose callee re-stamps and leaves for FLOOR4 even when closed | `29C.MES`, `EVENTA05.MES` | [29C Caller Group](29c_caller_group.md) |
| The 34C caller group's one EVENT intro site: the L family's late-year afternoon as a root handoff whose callee counts a visit before its gate, closes itself early and stamps 34 on its way to FLOOR5 | `34C.MES`, `EVENTL20.MES` | [34C Caller Group](34c_caller_group.md) |
| The 33C caller group's one EVENT intro site: the A family's summer day as a root handoff whose callee moves the A word, closes three conjuncts, stamps 33 and re-stamps on every return | `33C.MES`, `EVENTA04.MES` | [33C Caller Group](33c_caller_group.md) |
| The 32C caller group's one EVENT intro site: the I family's autumn Saturday early afternoon as a root handoff whose callee closes two conjuncts and stamps 32 on its way to FLOOR1 | `32C.MES`, `EVENTI23.MES` | [32C Caller Group](32c_caller_group.md) |
| The 10C caller group's one EVENT intro site: the D family's spring weekday as a root handoff whose callee has no gate of its own - the caller's guard reads the flag it sets - and leaves for the town | `10C.MES`, `EVENTD06.MES` | [10C Caller Group](10c_caller_group.md) |
| The 20C caller group's one EVENT intro site: the L family's autumn weekday as a root handoff whose caller closes a conjunct in the gap and whose callee asks three answers, each moving the L word, before one door to the town | `20C.MES`, `EVENTL16.MES` | [20C Caller Group](20c_caller_group.md) |
| The 28C caller group's one EVENT intro site: the L family's autumn Saturday evening as a root handoff behind two nested guards, whose callee counts a visit before its gate, stores the date and stamps 28 on its way to FLOOR1 | `28C.MES`, `EVENTL13.MES` | [28C Caller Group](28c_caller_group.md) |
| The 05C caller group's one EVENT intro site: the I family's winter weekday as a root handoff behind a 14-conjunct guard and the caller's own three-answer question, whose callee stores and resets the I word and stamps 15 on its way to the town | `05C.MES`, `EVENTI21.MES` | [05C Caller Group](05c_caller_group.md) |
| The 27C3B caller group's one EVENT intro site: the A family's Saturday afternoon as a root handoff behind a 17-conjunct guard, whose callee asks three answers, each moving the A word, before one door to FLOOR4 | `27C3B.MES`, `EVENTA01.MES` | [27C3B Caller Group](27c3b_caller_group.md) |
| The REIKO42 caller group's one EVENT intro site: a summer weekday as a root handoff behind a ten-conjunct guard, whose callee counts a visit before its gate and asks three answers, each moving an affection word, before one door to the town | `REIKO42.MES`, `EVENTF07.MES` | [REIKO42 Caller Group](reiko42_caller_group.md) |
| The 06M caller group's one EVENT intro site: the day after a stored date as a root handoff behind the map's own two-answer question, whose callee moves two affection words, asks three answers and stamps 6 on its way to the town; the first group declaring both the caller's and the callee's contracts | `06M.MES`, `EVENTK06.MES` | [06M Caller Group](06m_caller_group.md) |
| The 16M caller group's one EVENT intro site: a root handoff selected by the map's own two-answer question inside its menu loop, whose staged callee plays its first visit, advances its stage word and stamps 16 on its way to the town | `16M.MES`, `EVENTQ01.MES` | [16M Caller Group](16m_caller_group.md) |
| The 10M caller group's one EVENT intro site: a weekday afternoon as a nested call behind the map's own two-answer question, whose callee counts a visit and returns, the map then closing two flags, stamping 10 and handing the root to the town | `10M.MES`, `EVENTM04.MES` | [10M Caller Group](10m_caller_group.md) |
| The 19M caller group's one EVENT intro site: an autumn weekday as a nested call behind the map's own two-answer question, whose callee counts a visit and returns, the map then closing two flags, stamping 19 and handing the root to the town | `19M.MES`, `EVENTM15.MES` | [19M Caller Group](19m_caller_group.md) |
| The 21M caller group's one EVENT intro site: a summer late morning as a nested call behind the map's own two-answer question, whose callee calls a picture script and returns, the map then closing two flags, stamping 21 and handing the root to the town | `21M.MES`, `EVENTM08.MES` | [21M Caller Group](21m_caller_group.md) |
| The 43C caller group's one EVENT intro site: an evening nested call behind a four-conjunct guard, whose callee counts a visit and returns, the floor then closing the guard's flag and stopping at its own question; the question at `20161` identified as the room-action menu, and the 13 `?_H.MES` recollection ladders behind its answer 3 (declared EP-12 H) | `43C.MES`, `EVENTM05.MES`, `?_H.MES` | [43C Caller Group](43c_caller_group.md) |
| The 46M caller group's one EVENT intro site: the J family's late summer evening as a nested call behind a 14-conjunct guard, whose callee closes its own flag and returns, the map then closing a guard flag, stamping 46 and handing the root to the town | `46M.MES`, `EVENTJ09.MES` | [46M Caller Group](46m_caller_group.md) |
| The A_DATE5 caller group's one EVENT intro site: the A family's winter date as a nested call behind the script's own question, whose callee asks three answers that share one body and returns, the script then handing the root to the town | `A_DATE5.MES`, `EVENTA17.MES` | [A_DATE5 Caller Group](a_date5_caller_group.md) |
| The H_DATE3 caller group's one EVENT intro site: the H family's winter evening as a nested call behind two nested guards, whose callee asks three answers, each moving the H word, and returns, the script then closing the inner flag and handing the root to H_DATE5 | `H_DATE3.MES`, `EVENTH19.MES` | [H_DATE3 Caller Group](h_date3_caller_group.md) |
| The K_DATE3 caller group's one EVENT intro site: a winter evening as a nested call behind a five-conjunct guard ten bytes before the dispatch, whose callee counts a visit and returns, the script then closing the guard's flag and handing the root to K_DATE5 | `K_DATE3.MES`, `EVENTK15.MES` | [K_DATE3 Caller Group](k_date3_caller_group.md) |
| Python handoff frontier, branch sites and exact incoming callers for event analysis | 169 indexed entries and their callers | [Event Analysis Frontier](event_analysis_inventory.md) |
| GROUND H17/K09 calendar-backed caller paths, branch normalization, choice outcomes and reentry effects | `GROUND.MES`, `EVENTH17.MES`, `EVENTK09.MES`, `DEF_MAIN.MES`, `START.MES` | [GROUND Event Analysis](ground_event_analysis.md) |
| GROUND H01/H02 four intros, later choices, downstream dispatch boundaries and phase reentry | `GROUND.MES`, `EVENTH01.MES`, `EVENTH02.MES`, `DEF_MAIN.MES`, `START.MES` | [GROUND H01/H02 Analysis](ground_h01_h02_analysis.md) |
| GROUND H01/H02 carried-state continuations through K01/K_PIC to MACHI | `GROUND.MES`, `EVENTH01.MES`, `EVENTH02.MES`, `EVENTK01.MES`, `K_PIC.MES` | [GROUND K01/K_PIC Analysis](ground_k01_kpic_analysis.md) |
| GROUND C07 and sequential C12 calls, observed opaque guards, counters and reentry | `GROUND.MES`, `EVENTC07.MES`, `EVENTC12.MES`, `C_PIC.MES`, `O_PIC.MES` | [GROUND C07/C12 Analysis](ground_c07_c12_analysis.md) |
| GROUND K02 caller, seasonal guard, bit-mask preservation, word copy and reentry | `GROUND.MES`, `EVENTK02.MES` | [GROUND K02 Analysis](ground_k02_analysis.md) |
| GROUND H15 returning callee and A07 root replacement, with local guards, counter clamps and direct reentry | `GROUND.MES`, `EVENTH15.MES`, `H_PIC.MES`, `EVENTA07.MES`, `N_PIC.MES` | [GROUND H15/A07 Analysis](ground_h15_a07_analysis.md) |
| GROUND F02 typed guard chain head, root replacement, DEF11 date/clock normalization and inert reentry | `GROUND.MES`, `EVENTF02.MES` | [GROUND F02 Analysis](ground_f02_analysis.md) |
| GROUND G08 unguarded root replacement, its source-bound window proof, word-204 selection and replaying reentry | `GROUND.MES`, `EVENTG08.MES`, `G_PIC.MES` | [GROUND G08 Analysis](ground_g08_analysis.md) |
| Reservation, date, and post-date choices | `D_PROMIS.MES`, `D_DATE2.MES`, `D_DATE3.MES`, `D_DATE5.MES`, `MACHI.MES`, `D_TALK*.MES` | [Date Scene](date_scene.md) |
| Heroine A's promise date: the shared 11-caller guard, the multi-hop nested-call pass (A_PIC/A_DATE1/DENSHA+TRAIN/A_TIME/A_DATE2/A_DATE7), the town ending measured end to end, and the date5/hotel endings' own unresolved boundaries | `A_PROMIS.MES`, `01M.MES`, `A_PIC.MES`, `A_DATE1.MES`, `DENSHA.MES`, `TRAIN.MES`, `A_TIME.MES`, `YABAI.MES`, `A_DATE2.MES`, `A_DATE3.MES`, `A_DATE4.MES`, `A_DATE5.MES`, `A_DATE7.MES`, `MACHI.MES` | [A Date Flow](a_date_flow.md) |
| Heroine B's promise date, the A template applied by the new `draft_date_flow_specs.py`/`measure_date_flow.gd` pair: the same guard/hop shape on B's own cells and files, all three routes declared and validated, with B's own affection-ladder and special-date-gate departures from A | `B_PROMIS.MES`, `01M.MES`, `B_PIC.MES`, `B_DATE1.MES`, `DENSHA.MES`, `TRAIN.MES`, `B_TIME.MES`, `YABAI.MES`, `B_DATE2.MES`, `B_DATE3.MES`, `B_DATE4.MES`, `B_DATE5.MES`, `B_DATE7.MES`, `B_HOTEL.MES`, `B_HOTEL1.MES`, `B_HOTEL2.MES`, `MACHI.MES` | [B Date Flow](b_date_flow.md) |
| Heroines C..L's promise dates, the same tool pair generalized for three further structural departures (a jump-chased town terminal, an optional money gate, a HOTEL site-selector sharing its file with an unrelated question) and two open-choice sites answered by policy (E/I's own HOTEL2 ending, L's own DATE5 ending); J leaves one route out (an unresolved routing flag; D's hotel and L's DATE5, first left out for a contract-rebuild limitation, were declared 2026-09-26, Core 0.368.0) | `C_PROMIS.MES`..`L_PROMIS.MES`, `01M.MES`, `?_PIC.MES`, `?_DATE1.MES`, `DENSHA.MES`, `TRAIN.MES`, `?_TIME.MES`, `YABAI.MES`, `?_DATE2.MES`, `?_DATE3.MES`, `?_DATE4.MES`, `?_DATE5.MES`, `?_DATE7.MES`, `?_HOTEL.MES`, `?_HOTEL1.MES`, `?_HOTEL2.MES`, `MACHI.MES` | [Heroine Date Flows (C..L)](heroine_date_flows.md) |
| The twelve `?_PROMIS.MES` promises at the `01M.MES` station site, all twelve `01m-<letter>-promis` groups registered and passing, and the full catalog/registry/v6/package regeneration (catalog revision 32, 187 rows): each heroine's own guard flag (set only by that heroine's own `TALK` conversation scripts, cleared by the promise itself), the callee's two cascaded questions (a 15-place picker answered at registration position 3/location 2, then the already-Confirmed ten-option time selector), A's own options-8-10 latch left unresolved, and a playback-package-only replay gap (a sparse-catalog gate hash a package cannot fingerprint) found and closed with no package schema change | `A_PROMIS.MES`..`L_PROMIS.MES`, `01M.MES`, `A_TALK00.MES`..`L_TALK90.MES` | [Promise Groups](promise_groups.md) |
| The album behind the title menu (EP-12 gallery study): how `GIRLS.MES` reaches the thirteen `?_M.MES` menus, the native-selection menu template over the album's A6 table, the 365 scene unlock flags and the scripts that set them, the thirteen `?_CG.MES` viewers (389 slots), the thirteen in-room `?_H.MES` recollection scripts and the unreachable `OMAKE.MES`, all 365 `SCENE_*.MES` entries run standalone, their twins, a two-hop flow trial with the route toolchain, and all 13 albums declared (365 scenes as `<menu>-scene` flows with 91 variants, seeded menu selection, 33 twins as `duplicate_route`, 2026-10-04) | `START.MES`, `OPEN.MES`, `GIRLS.MES`, `*_M.MES`, `*_CG.MES`, `*_H.MES`, `OMAKE.MES`, `SCENE_*.MES`, `43C.MES`, `?_END.MES`, `data.arc` A6 tables | [Gallery Families](gallery_families.md) |
| The talk family (EP-12 TALK study): the 142 `?_TALK*.MES` scripts (96 affection-banded rung scripts, 28 follow-ons, 9 plain once-only scripts, `M_TALK`, eight scripts of the characters N..Q), their 4,905 call sites from 136 callers, the fixed eight-rung affection ladder of all 537 ladder blocks and the four-level guard (place roll, presence flag, calendar window, today flag), the heroine cells, the flags TALK sets for PROMIS, the topic-hub structure with its 488 routine-40 questions (485 nameable in a fresh state, 421 in the natural presence state before Core 0.371.0 and 485 since), answer paths and state-dependent coverage, the 296 DATE5/HOTEL sites the declared date routes never reach, twins, the trials with the route toolchain (v14 flows build, audit and validate; the caller-continuation measurer hangs), and the declarations, heroine K's nine scripts (2026-10-04) and the other eleven heroines', Tina's and the characters' 105 more (2026-10-05: 88 rung routes at the `01M.MES` blocks, eight plain scripts at `27C_EV.MES`, `M_TALK`, `N_TALK`..`Q_TALK1`; the other ladder blocks recorded as equivalents) | `?_TALK*.MES`, `01M.MES`, `NN[MC].MES`, `27C*.MES`, `?_DATE5.MES`, `?_HOTEL.MES`, `43C.MES`, `?_PIC.MES` | [Talk Family](talk_family.md) |
| Persistent map/character music and EVENTB03 impact effects | `LIBLARY.LIB` plus scene call sites, `EVENTB03.MES` | [Audio](audio.md) |
| Which records name a media file, and how the playback package's media inventory classifies them: the marker kinds, effects, the A6 shape, the BGM pair rule, and the loader strings (`system_call` functions 5, 8, 9, 24 and the three `native_record_dispatch` shapes) whose native meaning stays unresolved, with the 246 names absent from every original archive (WD-21 unit 1, 2026-10-06), and which occurrences a row's measured route reaches, the library-ladder finding and its exclusion (WD-21 U2, 2026-10-08) | all `.MES`/`.LIB` entries, `LIBLARY.LIB`, `EVENTD01.MES`, `*_M.MES`, `GROUND.MES` | [Media Reference Classification](media_references.md) |

## Confidence Labels

- **Confirmed**: checked in the authoritative archive and supported by a direct
  instruction, branch, state write, or call chain.
- **Projected**: decoded evidence is sufficient for the current runtime data,
  but one or more symbolic state names remain unresolved.
- **Observed**: repeatable corpus pattern whose complete native meaning is not
  yet proven.
- **Unresolved**: retained as an offset, numeric state reference, or diagnostic;
  it must not become a gameplay rule yet.

## Content Boundary

These documents record format facts, state expressions, numeric thresholds,
file names, offsets, and scene flow. They intentionally omit:

- original dialogue text;
- bytecode or long hexadecimal dumps;
- extracted images, audio, and voice data;
- lossless archive/container payloads.

Lossless and text-bearing analysis products remain under the Git-ignored
`analysis/` directory. Original assets remain under the Git-ignored `assets/`
directory and must also be excluded from public exports.

## Supporting Artifacts

- `tools/mes_archive_ir.py`: lossless container inspection.
- `content_core/mes_container.gd`: shared runtime/tool lossless container
  boundary, verified against every authoritative `mes.arc` entry.
- `content_core/mes_instruction_decoder.gd` and `mes_event_runner.gd`: strict
  GDScript structural decoding and unsupported-op-stop sandbox preview. The
  aligned regional API additionally owns EXE/runner-qualified `0x0D` native
  payloads containing control-looking bytes as one byte-preserving record
  rather than exposing sibling shadow branches or continuations.
- `content_core/mes_record_alignment_audit.gd` and
  `tools/content_suite/cli/audit_mes_record_alignment_corpus.gd`: exact
  bootstrap/address-region byte partition, compound-family inventory, and
  fail-closed opaque-tail audit across the authoritative MES/LIB corpus.
- `content_core/mes_routine40_reachability.gd`: source-revalidated numeric
  first/second-result rows for the evaluated 43C grouped registry, including
  exact consumer, fallback, and empty-list boundaries without execution.
- `content_core/mes_analysis_index.gd`: versioned static analysis v19 plus the
  independent `kakyu_mes_reference_graph/v1` bounded CFG projection.
- `content_core/mes_transfer_direction_audit.gd` and
  `tools/content_suite/cli/audit_mes_transfer_direction_corpus.gd`: current-schema
  typed branch/continuation direction and address-region inventory, with
  opaque ranges retained outside the absence claim and same-region backward
  candidates reserved for later natural-loop proof.
- `content_core/mes_analyzer_handoff.gd`: deterministic language-neutral Phase
  1-4 container/IR/reference/CFG/call/trace bundle consumed by Python without
  replacing current GDScript record ownership.
- `tools/validate_mes_analyzer_handoff.py`: strict Python compatibility and
  fingerprint validator for the v1 handoff.
- `tools/content_suite/cli/audit_mes_analyzer_handoff_corpus.gd` and
  `tools/validate_mes_analyzer_completion.py`: authoritative per-entry handoff
  determinism audit and compact Phase 1-4 completion-report consumer.
- `tools/decompile_mes_handoff.py`: Python Phase 5 linear lifter and validator
  for the lossless `kakyu_mes_decompiler_ir/v1` source form. It consumes the
  handoff rather than reparsing MES bytes.
- `tools/annotate_mes_decompiler.py`: deterministic source-qualified annotation
  JSON for numeric state/code coordinates, message coordinates, literal
  resources, and explicit unresolved semantic aliases.
- `tools/compose_mes_renderer_input.py`: exact source-reversible renderer-input
  core joining the linear program, semantic annotations, complete low-level
  fallback, and proved reducible conditional structures.
- `tools/compose_mes_renderer_overlays.py`: v2 proof-family composition for
  reversible guard/value/predicate, cross-region-join, and call overlays while
  retaining every rejection and the v1 fallback.
- `tools/compose_mes_renderer_loops.py`: v3 composition for the source-bound
  library/shared-return/execution-fallthrough/natural-loop family, with exact
  loop-envelope reversal and no guessed surface loop syntax.
- `tools/render_mes_pseudocode.py`: deterministic source-order pseudocode JSON
  with optional derived text, exact per-line reversal, and no decoded dialogue
  or guessed high-level surface syntax.
- `tools/audit_mes_decompiler_equivalence.py`: strict single-entry equivalence
  audit for renderer-input v3 and pseudocode v1, including complete byte/node
  coverage, source reversal, and unresolved-evidence inventory.
- `tools/audit_mes_decompiler_corpus.py`: bounded Phase 5 spool consumer that
  runs the full decompiler chain one handoff at a time and retains compact
  source-bound corpus coverage JSON without raw MES or pseudocode payloads.
  Its complete 1,016-entry report closes Phase 5 with byte-identical repeated
  output and all source/CFG/rendering/reversal invariants true.
- `tools/prepare_mes_editable_ir.py`: strict Phase 6 wrapper that embeds the
  immutable lossless decompiler JSON and reserves ordered authoring operations.
- `tools/compile_mes_noop.py`: zero-operation MES compiler and compact audit;
  it reopens a newly published byte-identical container and rejects edits until
  their relocation contracts are implemented.
- `content_core/mes_noop_compile_reopen.gd`: strict cross-language verifier
  that rebuilds the current GDScript Phase 1-4 analysis from compiled bytes.
- `tools/content_suite/cli/validate_mes_noop_compile.gd`: headless validator for a
  compiled MES and its Python no-op audit.
- `tools/audit_mes_noop_compile_corpus.py`: bounded process-level no-op corpus
  compiler that publishes compact MES/audit pairs and a completion manifest
  last.
- `content_core/mes_noop_corpus_reopen.gd` and
  `tools/content_suite/cli/audit_mes_noop_reopen_corpus.gd`: strict GDScript
  corpus consumer and headless authoritative-source verifier.
- `tools/plan_mes_message_relocation.py`: JSON-only MW-02 preflight for one
  source-hash-bound variable-length CP932 edit; it plans address-table and
  reference shifts and exposes opaque/MW-03 blockers before assembly.
- `tools/compile_mes_message_relocation.py`: blocker-free variable-length CP932
  assembler with exclusive MES/audit publication.
- `content_core/mes_message_compile_reopen.gd` and
  `tools/content_suite/cli/validate_mes_message_compile.gd`: strict Python-audit
  consumer and current Phase 1-4 changed-MES reopen.
- `tools/plan_mes_utf8_overlay.py`: strict `replace_message_utf8_overlay`
  planner that emits only a source-bound remake projection and forbids MES
  byte output.
- `content_core/mes_utf8_overlay_plan.gd` and
  `tools/content_suite/cli/validate_mes_utf8_overlay_plan.gd`: cross-language plan
  validator with optional authoritative ARC/entry rebinding; the validated
  plan stages through the existing overlay package.
- `tools/plan_mes_control_target_relocation.py`: JSON-only MW-03/MW-05
  augmentation that resolves exact command-`0x0B`, command-`0x0C`, and
  command-`0x10` definition-skip little-endian target operands while retaining
  unsupported message-plan blockers.
- `content_core/mes_control_target_relocation_plan.gd` and
  `tools/content_suite/cli/validate_mes_control_target_relocation_plan.gd`: strict
  cross-language verifier for target encoding, source/output coordinates,
  typed-target alignment, and non-overlapping patch ranges.
- `tools/compile_mes_control_target_relocation.py`: fail-closed MW-03 assembler
  that applies one validated message relocation plus exact branch/continuation
  target repairs and publishes a new MES/audit pair exclusively.
- `content_core/mes_control_target_compile_reopen.gd` and
  `tools/content_suite/cli/validate_mes_control_target_compile.gd`: independent
  GDScript audit consumer and Phase 1-4 reopen for every relocated target and
  the edited message.
- `tools/plan_mes_address_entry_insert.py`: JSON-only MW-06 plan for inserting
  one sorted address-table boundary at a unique strict typed instruction start
  inside an existing entry while retaining all bytecode coordinates.
- `content_core/mes_address_entry_insert_plan.gd` and
  `tools/content_suite/cli/validate_mes_address_entry_insert_plan.gd`: strict
  cross-language validator for the new cell, source/output table geometry,
  region split, and no-binary-publication boundary.
- `tools/compile_mes_address_entry_insert.py`: new-file-only MW-06 assembler
  that adds the planned table cell while retaining byte-identical bytecode and
  all code-relative coordinates.
- `content_core/mes_address_entry_insert_compile_reopen.gd` and
  `tools/content_suite/cli/validate_mes_address_entry_insert_compile.gd`:
  independent GDScript audit consumer and Phase 1-4 reopen for the new region
  split, target intro, and unchanged source node partition.
- `tools/plan_mes_control_target_edit.py`: JSON-only MW-06 plan that binds an
  exact typed conditional/continuation instruction, indexed edge, and a
  different strict typed target before any MES bytes may be assembled.
- `content_core/mes_control_target_edit_plan.gd` and
  `tools/content_suite/cli/validate_mes_control_target_edit_plan.gd`: strict
  cross-language validator for condition/transfer bytes, paired target hashes,
  and the isolated little-endian `u32` patch.
- `tools/compile_mes_control_target_edit.py`: new-file-only MW-06 assembler for
  one validated branch/continuation target edit and its exact changed-offset
  audit.
- `content_core/mes_control_target_edit_compile_reopen.gd` and
  `tools/content_suite/cli/validate_mes_control_target_edit_compile.gd`:
  independent GDScript audit consumer and Phase 1-4 reopen for the edited
  instruction, replacement typed target, and rebuilt indexed edge.
- `tools/plan_mes_control_body_edit.py` and
  `tools/compile_mes_control_body_edit.py`: fail-closed MW-06 planning and
  new-file-only assembly for exact strict-typed body insertion/removal with
  exhaustive address, reference, target, CFG, call/trace, and opaque-boundary
  inventories.
- `content_core/mes_control_body_edit_compile_reopen.gd` and
  `tools/content_suite/cli/export_mes_control_body_edit_handoff.gd`: independent
  changed-MES reopen and standard Phase 1-4 analyzer-handoff export for a
  validated control-body compile audit.
- `tools/diff_mes_control_body_semantics.py`,
  `content_core/mes_semantic_diff.gd`, and
  `tools/content_suite/cli/validate_mes_semantic_diff.gd`: first MW-07 semantic
  source/output diff. The Python producer reconstructs intended bytes and maps
  all source/output nodes; the GDScript consumer rejects changed transport,
  preservation counts, or invariants.
- `tools/content_suite/cli/export_mes_byte_patch_handoff.gd` and
  `tools/diff_mes_byte_patch_semantics.py`: common MW-07 path for same-layout
  state, condition, resource, inline-script, shared-call, registered-DEF-call,
  explicit-control-target, and same-length choice-option edits. V2 proves one
  exact intended owner patch, binds each family to its permitted semantic
  assertion, and distinguishes a bounded intended opaque edit from unrelated
  opaque content that remains byte-identical.
- `tools/diff_mes_address_entry_semantics.py`: MW-07 semantic diff v3 for one
  address-table entry insertion. It independently requires the four-byte table
  growth, byte-identical code and typed/opaque nodes, and exact reference
  coordinates while hashing the derived node/reference region reassignment.
- `tools/diff_mes_message_relocation_semantics.py`: MW-07 semantic diff v4 for
  a variable-length typed message replacement, with or without the augmented
  control-target repair audit. It reconstructs the changed container, maps all
  shifted nodes and references, and verifies the payload only by boundary and
  hash without retaining text.
- `tools/plan_mes_state_literal_edit.py`: JSON-only MW-04 preflight for one
  source-hash-bound, same-width literal expression inside a typed state-write
  run; it preserves destination and continuation structure and emits no MES
  bytes.
- `content_core/mes_state_literal_edit_plan.gd` and
  `tools/content_suite/cli/validate_mes_state_literal_edit_plan.gd`: strict
  cross-language validator for the typed write identity, JSON integer
  coordinates, literal encoding, retained continuation, and byte-local patch.
- `tools/compile_mes_state_literal_edit.py`: new-file-only MW-04 assembler and
  compact audit for one validated same-width state-literal plan; container
  size, address table, preamble, and all bytes outside the selected expression
  remain unchanged.
- `content_core/mes_state_literal_compile_reopen.gd` and
  `tools/content_suite/cli/validate_mes_state_literal_compile.gd`: independent
  compile-audit consumer and current Phase 1-4 changed-MES reopen that requires
  the selected typed write/literal to reindex exactly.
- `tools/plan_mes_condition_literal_edit.py`: JSON-only MW-04 preflight for one
  source-hash-bound literal token inside a typed command-`0x0B` condition; it
  preserves the condition terminator and binds the indexed trailing
  false-target operand without publishing MES bytes.
- `content_core/mes_condition_literal_edit_plan.gd` and
  `tools/content_suite/cli/validate_mes_condition_literal_edit_plan.gd`: strict
  cross-language validator for JSON integer coordinates, literal encoding,
  retained condition/target slices, and byte-local replacement.
- `tools/compile_mes_condition_literal_edit.py`: new-file-only MW-04 assembler
  and compact audit for one validated same-width condition-literal plan;
  container layout, condition terminator, false-target operand, and every byte
  outside the selected literal remain unchanged.
- `content_core/mes_condition_literal_compile_reopen.gd` and
  `tools/content_suite/cli/validate_mes_condition_literal_compile.gd`: independent
  compile-audit consumer and current Phase 1-4 changed-MES reopen that requires
  the branch, selected AST literal, condition terminator, and false target to
  reindex exactly.
- `tools/plan_mes_resource_name_edit.py`: JSON-only MW-04 preflight for one
  source-hash- and reference-bound same-length printable-ASCII name inside a
  strict-indexed typed MMO, AX, or voice marker. It freezes every non-name byte
  and emits no MES container.
- `content_core/mes_resource_name_edit_plan.gd` and
  `tools/content_suite/cli/validate_mes_resource_name_edit_plan.gd`: strict
  cross-language validator for JSON integer coordinates, exact typed resource
  identity, safe extension-preserving ASCII names, and unchanged marker
  prefix/suffix bytes.
- `tools/compile_mes_resource_name_edit.py`: new-file-only MW-04 assembler and
  compact audit for one validated same-length resource-name plan; container
  layout, marker envelope, and every byte outside the selected name remain
  unchanged.
- `content_core/mes_resource_name_compile_reopen.gd` and
  `tools/content_suite/cli/validate_mes_resource_name_compile.gd`: independent
  compile-audit consumer and current Phase 1-4 changed-MES reopen that requires
  the edited typed marker, name bytes, and strict-indexed resource reference to
  reappear exactly.
- `tools/plan_mes_inline_script_name_edit.py`: JSON-only MW-05 preflight for one
  same-length `.LIB` or `.MES` target inside a selector-2/3 inline execution
  envelope. It binds the exact indexed reference and containing node, including
  a bounded envelope retained inside one opaque owner, and publishes no MES
  bytes.
- `content_core/mes_inline_script_name_edit_plan.gd` and
  `tools/content_suite/cli/validate_mes_inline_script_name_edit_plan.gd`: strict
  cross-language validator for selector/extension pairing, owner/reference
  boundary pairing, exact envelope slices, and same-length safe names.
- `tools/compile_mes_inline_script_name_edit.py`: new-file-only MW-05 assembler
  and compact audit for one validated inline-script-name plan; it preserves the
  containing typed/opaque node boundary, selector envelope, container layout,
  and every byte outside the selected name.
- `content_core/mes_inline_script_name_compile_reopen.gd` and
  `tools/content_suite/cli/validate_mes_inline_script_name_compile.gd`: independent
  compile-audit consumer and current Phase 1-4 reopen that requires the same
  owner partition plus a redecoded envelope, replacement name, and reindexed
  strict or bounded resource reference.
- `tools/plan_mes_shared_routine_call_edit.py`: JSON-only MW-05 preflight for
  one typed command-`0x1D` 8-bit literal. It requires a unique physical resume
  node plus source and replacement `LIBLARY.LIB` total-return certificates and
  publishes no MES bytes.
- `tools/compile_mes_shared_routine_call_edit.py`: new-file-only assembler and
  compact audit for one validated shared-routine plan. It changes the selected
  literal byte only and retains the physical resume bytes, callee certificates,
  caller partition, and container layout.
- `content_core/mes_shared_routine_call_edit_plan.gd` and
  `tools/content_suite/cli/validate_mes_shared_routine_call_edit_plan.gd`: strict
  cross-language plan consumer for the typed call, exact literal, physical
  resume, and paired source/replacement total-return certificates.
- `content_core/mes_shared_routine_call_compile_reopen.gd` and
  `tools/content_suite/cli/validate_mes_shared_routine_call_compile.gd`: independent
  compile-audit consumer and current Phase 1-4 reopen that requires the edited
  call and literal to redecode while preserving the caller/resume partition.
- `tools/prove_mes_registered_definition_registry.py`: source-bound MW-05
  registry proof for one zero-start command-`0x14` path. It hashes every exact
  registered body range without executing it and explicitly excludes
  command-`0x10` choice-definition bodies from the registry family.
- `tools/plan_mes_registered_definition_call_edit.py`: JSON-only MW-05
  preflight for one typed command-`0x11` 8-bit literal. It binds the unique
  physical resume and exact source/replacement command-`0x14` registry body
  ranges while executing neither body and publishing no MES bytes.
- `tools/compile_mes_registered_definition_call_edit.py`: new-file-only MW-05
  assembler for that plan. Its compact audit proves that only the selector
  literal changed while the address table, caller resume, and both unexecuted
  registry body certificates remained fixed.
- `tools/prove_mes_choice_group_authoring.py`: source-bound MW-05 proof for one
  command-`0x1B`/`0x10` grouped choice route. It hashes exact option bodies,
  guards, numeric first/second-result consumers, stored fallback, routine-40
  terminal, and physical resume without exporting dialogue or running input.
- `tools/plan_mes_choice_option_edit.py`: JSON-only MW-05 same-byte-length
  CP932 option preflight bound to one grouped proof. It fixes the selected
  payload plus replacement hashes while retaining all group/result/caller
  coordinates and emits no MES container.
- `content_core/mes_choice_option_edit_plan.gd` and
  `tools/content_suite/cli/validate_mes_choice_option_edit_plan.gd`: independent
  GDScript consumer for that plan's exact message/body bytes, proof hashes,
  numeric-result topology, routine-40 terminal, physical resume, and zero
  coordinate delta.
- `tools/compile_mes_choice_option_edit.py`: new-file-only MW-05 assembler for
  the same-length choice plan. It changes only the selected payload and
  rebuilds the complete grouped authoring proof from output before publishing
  a compact compile audit.
- `content_core/mes_choice_option_compile_reopen.gd` and
  `tools/content_suite/cli/validate_mes_choice_option_compile.gd`: independent
  GDScript Phase 1-4 reopen for the compiled option, exact return,
  routine-40 terminal, physical resume, and retained grouped/result hashes.
- `content_core/mes_registered_definition_call_edit_plan.gd` and
  `tools/content_suite/cli/validate_mes_registered_definition_call_edit_plan.gd`:
  strict cross-language consumer for the command-`0x11` literal, physical
  resume, and source/replacement command-`0x14` body certificates.
- `content_core/mes_registered_definition_call_compile_reopen.gd` and
  `tools/content_suite/cli/validate_mes_registered_definition_call_compile.gd`:
  independent compile-audit consumer and current Phase 1-4 reopen that requires
  the edited call/literal to redecode while retaining both registry bindings.
- `tools/content_suite/cli/export_mes_decompiler_handoff_spool.gd`: read-only
  source-bound handoff/CFG and complete library-audit spool producer; it writes
  a path-free completion manifest last and refuses project/source-adjacent
  output.
- `tools/prove_mes_control_flow.py`: proof-bounded Phase 5 conditional and
  continuation transfer projection with explicit unresolved and expansion-leaf
  anchors.
- `tools/emit_mes_low_level_control.py`: deterministic labeled control IR for
  proved transfers and explicit fallback anchors before high-level structuring.
- `tools/prove_mes_if_regions.py`: same-region reducibility proof for forward
  `if_then` and two-arm `if_else` regions with exact linear-span, entry, and
  single-join checks.
- `tools/prove_mes_cross_region_joins.py`: bounded all-path convergence and
  external-entry audit for cross-region conditionals; it records only proved
  join relationships and retains low-level syntax for every result.
- `tools/prove_mes_guard_chains.py`: label-preserving proof of maximal
  false-edge condition chains; it does not infer `if`/`elif` or dispatch
  semantics.
- `tools/prove_mes_value_dispatches.py`: numeric value-dispatch proof for guard
  chains made entirely from one state coordinate's unique equality literals.
- `tools/prove_mes_predicate_dispatches.py`: bounded exact DNF projection for
  ordered compound/irregular guard chains made only from numeric state
  equalities; original AST, labels, and low-level fallback remain authoritative.
- `tools/prove_mes_natural_loops.py`: reachable-CFG dominator and single-entry
  proof for bounded same-region natural loops; grouped latches, exits, exact
  source envelopes, and the original label/goto fallback remain explicit.
- `tools/prove_mes_shared_call_returns.py`: source-bound return certificates for
  literal command-`0x1D` calls whose audited `LIBLARY.LIB` CFG is complete,
  entry-reachable, acyclic, and return-only at every terminal.
- `tools/prove_mes_call_families.py`: typed external-MES targets and registered-
  definition selectors with exact physical resume coordinates, explicit
  no-return-edge status, and retained low-level fallback.
- `tools/prove_mes_execution_fallthroughs.py`: exact same-region anchor
  fallthrough proof across NUL-consumed native payload rows and source-bound
  shared-call returns, with every stored-order node retained in the source map.
- `tools/export_mes_instruction_oracle.py` and
  `tools/export_mes_text_cache.py`: ignored, versioned Python-generated audit
  and UTF-8 presentation caches; neither is a runtime dependency.
- `tools/mes_basic_block_ir_v6.py`: production control-flow/expression IR with
  complete command `0x03` `global_u8`, command `0x04` `state_u16`, command
  `0x06` `banked_u8`, command `0x07` `banked_u16`, and command `0x08`
  `banked_i32` consecutive-write
  operands.
- `tools/audit_mes_command03.py`: archive-wide structural audit of strict-valid
  and tolerant-invalid command `0x03` runs, with an ordered repeated 16-bit
  global-index set for single-pass producer/ownership evidence.
- `tools/audit_mes_command04.py`: archive-wide candidate audit of native
  command-`0x04` dynamic `state_u16` runs, with strict-valid and
  structural-only overflow/continuation counts kept separate.
- `tools/audit_mes_command07.py`: archive-wide structural audit of command
  `0x06`, `0x07`, or `0x08` destination/bank/value runs, with bounded detailed
  records and complete field-range aggregates for focused producer audits.
- `tools/audit_mes_promise_calendar_fields.py`: hash-bound cross-audit of the
  thirteen `LIBLARY.LIB` routine-26 calendar-field blocks, twelve direct
  PROMIS writers, and the original EXE command-`0x07` word-write contract.
- `tools/audit_mes_promise_callers.py`: complete hash-bound inventory of the
  500 literal PROMIS command-`0x0F` activation records, their address-table
  owners, all target-specific command-`0x0B` flag gates, each target's common
  zero-start setup transfer, and the original EXE command-`0x0B`/`0x0F`/`0x14`
  contracts.
- `tools/content_suite/cli/audit_mes_promise_caller_reachability.gd`: all-zero
  isolated execution of all 146 physical PROMIS caller owners, including the
  bounded 27 -> 25/DEF26 -> 21 library chain, plus target-gate-only execution
  of all 499 unique owner/target pairs while preserving the unresolved incoming-
  state, nested-script, and host-selection boundary.
- `tools/content_suite/cli/audit_mes_promise_nested_calls.gd`: hash-bound execution
  of both explicit local choices on the `44C.MES` and `L_HOTEL2.MES`
  `L_TALK30.MES` routes, caller restoration, and exact `L_PROMIS.MES` stop.
- `tools/content_suite/validators/validate_event_player_nested_promise.gd`: headless UI
  integration check for both one-click caller starts, keyboard local-choice
  input, game-frame dialogue, caller restoration, and visible PROMIS stop.
- `tools/content_suite/cli/audit_mes_promise_writer_execution.gd`: rejects the 24
  physical owner intros as direct writer starts by locking their isolated
  shared-routine/return boundaries.
- `tools/content_suite/cli/audit_mes_promise_date_library_resume.gd`: composes nine
  valid-date PROMIS prefixes through shared routine 24 and their original
  caller resumes to the confirmed date writers and returns.
- `tools/content_suite/cli/audit_mes_promise_cei_date_routes.gd`: composes the
  presentation-bearing `C/E/I` date prefixes through routine 24, their date
  writers, ten-option selectors, and bounded default-location outcomes.
- `tools/audit_mes_promise_location_routes.py`: hash-bound cross-audit of twelve
  PROMIS location fields, all fifteen constant location writers per entry,
  all ten time-option rejection/success branches, the A-entry evening latch
  gate, and the original EXE command-`0x0B`/`0x0C` coordinate-transfer
  contract.
- `tools/audit_mes_ax_markers.py`: archive-wide audit of exact outer-`0x0D`
  presentation-subcommand-8 selector-0 AX load records and original
  `data.arc` target resolution.
- `tools/audit_mes_ax_bindings.py`: archive-wide audit of exact outer-`0x0D`
  presentation-subcommand-3 selector-0 AX destination-buffer bindings to
  consumer row 0, columns 0 through 2, plus exact selector-7 all-cell
  invalidation records.
- `tools/audit_eventb03_native_presentation.py`: source-qualified
  `mes.arc`/original-EXE audit of selector-2 selected-cell state, selector-6 active-cell update, EVENTB03's
  selector-7 invalidation, selector-8 AX activation/wait, and subcommand-10
  mode-1 guarded native surface composition envelopes; Content Core `0.196.0`
  exposes those exact records as typed, non-executing instruction/event trace
  rows. Its exhaustive same-shape scan confirms that selectors 2/6/7/8 are the
  only literal seven-byte subcommand-3 envelopes in the authoritative archive.
- `tools/audit_mes_surface_operations.py`: archive-wide audit of exact outer-
  `0x0D` presentation-subcommand-11 typed candidates, confirmed pixel-operation
  shapes, the exact six-record mode-13 `surface_display_refresh`, unresolved
  coordinates, and literal-versus-dynamic arguments.
- `tools/content_suite/cli/audit_mes_surface_dispatch_reachability.gd`: hash-bound
  separation of the unindexed `10M.MES` empty candidate from the executable
  `LIBLARY.LIB` routine-20 mode-13 dispatch, including its exact evaluated
  records and non-executing `surface_display_refresh_omitted` trace for the
  `(0,0) 544x60` attached-display refresh rectangle.
- `tools/audit_ai5_audio_exe.py`: original-runtime and Voice ARC cross-audit of
  the bounded embedded Ogg/Vorbis signatures plus Voice ARC registration,
  native presentation-subcommand-7 voice-name queue, named-stream loading,
  bounded Ogg stream handoff, terminal DirectSound Play dispatch, and
  three-way settings audio sample; physical device output is not observed by
  the static audit.
- `tools/audit_mes_command_0a.py`: archive-wide structural audit of the native
  command-`0x0A` dynamic dword destination/value-run shape, retained local
  expression depths, minimum incoming persistent-stack depth, and net stack
  delta. It reports 0 rows at instruction v45 (no command-`0x0A` record exists
  in the typed IR; [Format and Method](format_and_method.md), the command-`0x0A`
  paragraph).
- `tools/inspect_normal_talk.py`: exact-label normal-conversation corpus scan.
- `tools/export_encounter_mes_dialogue.py`: local, source-offset-audited dialogue
  projection for the supported encounter trace.
- `tools/inspect_mes_bgm.py`: library BGM selector and call-site inspection.
- `tools/inspect_map_sources.py`: direct `MPC/CCD/EVE` movement, entrance, and
  collision audit for all original walkable maps.
- `tools/export_map_location_entries.py`: local, source-offset-audited
  conditions, inline messages, and calls for all 88 movement-map locations.
- `data/mes_conditions/`: runtime-safe caller and internal-condition
  projections.
- [MES Condition Projection](../data/mes_condition_projection.md): boundary
  between internal branches and event availability.
