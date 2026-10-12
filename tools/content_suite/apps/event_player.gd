class_name KakyuEventPlayer
extends Control

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcProvenanceScript := preload("res://content_core/arc_provenance.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContentSetScript := preload("res://content_core/content_set.gd")
const ContentResolverScript := preload("res://content_core/content_resolver.gd")
const ContentIdentityScript := preload("res://content_core/content_identity.gd")
const ContentLaunchContextScript := preload("res://content_core/content_launch_context.gd")
const MesEditorRunRequestScript := preload("res://content_core/mes_editor_run_request.gd")
const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const MesSemanticDiffScript := preload("res://content_core/mes_semantic_diff.gd")
const EventCatalogScript := preload("res://content_core/event_catalog.gd")
const EventAudioStateScript := preload("res://content_core/event_audio_state.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesCalendarStateScript := preload("res://content_core/mes_calendar_state.gd")
const MesMahokoStandingPlanScript := preload("res://content_core/mes_mahoko_standing_plan.gd")
const MesContextIndexScript := preload("res://content_core/mes_context_index.gd")
const MesStartupContextScript := preload("res://content_core/mes_startup_context.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const MesRoutine40ChoiceContractScript := preload("res://content_core/mes_routine40_choice_contract.gd")
const MesRoutine40GroupPreviewContractScript := preload("res://content_core/mes_routine40_group_preview_contract.gd")
const EventPlayerRoutine40ConsumerPlanScript := preload("res://content_core/event_player_routine40_consumer_plan.gd")
const MesDetachedDefinitionPreviewScript := preload("res://content_core/mes_detached_definition_preview.gd")
const MesScriptCallRunnerScript := preload("res://content_core/mes_script_call_runner.gd")
const MesCallerRouteScript := preload("res://content_core/mes_caller_route.gd")
const MesInstructionDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const MesLibraryAuditScript := preload("res://content_core/mes_library_audit.gd")
const MesLibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const MesLibraryRunnerScript := preload("res://content_core/mes_library_runner.gd")
const MesRegisteredDefinitionCallScript := preload("res://content_core/mes_registered_definition_call.gd")
const MesRegisteredDefinitionRunnerScript := preload("res://content_core/mes_registered_definition_runner.gd")
const MesStackEffectScript := preload("res://content_core/mes_stack_effect.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const TextCacheScript := preload("res://content_core/mes_text_cache.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")
const MmoCodecScript := preload("res://content_core/mmo_codec.gd")
const DatPalCodecScript := preload("res://content_core/dat_pal_codec.gd")
const AxDwordStreamScript := preload("res://content_core/ax_dword_stream.gd")
const AxAnimationScript := preload("res://content_core/ax_animation.gd")
const AxPlaybackPlanScript := preload("res://content_core/ax_playback_plan.gd")
const AxSurfaceBindingScript := preload("res://content_core/ax_surface_binding.gd")
const MesActiveSurfaceAxAuditScript := preload("res://content_core/mes_active_surface_ax_audit.gd")
const MesAxRuntimeChainScript := preload("res://content_core/mes_ax_runtime_chain.gd")
const LogicalSurfaceCompositorScript := preload("res://content_core/logical_surface_compositor.gd")
const AudioValidatorScript := preload("res://content_core/audio_entry_validator.gd")
const TimelineScript := preload("res://content_core/event_presentation_timeline.gd")
const ToolWindowDisplayScript := preload("res://tools/content_suite/tool_window_display.gd")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const LegacyGreenChromaKeyShader := preload("res://shaders/legacy_green_chroma_key.gdshader")
const ContractValues := preload("res://content_core/contract_values.gd")
const EVENT_CATALOG_PATH := "res://config/event_catalog/original_events_v1.json"
const VIEW_MODE_PLAYBACK := "playback"
const VIEW_MODE_ANALYSIS := "analysis"
const AUDITED_CONTEXT_REGISTRATIONS := 1154
const AUDITED_START_ENTRY_SHA256 := "ba57bf666fbd9db9b3110f2bf1c70e80e11a35de00e82256aaaf35921c77038f"
const AUDITED_CALENDAR_TABLE_SHA256 := MesCalendarStateScript.AUDITED_TABLE_SHA256
const AUDITED_ROUTINE40_BODY_OFFSET := 0x1C8E
const AUDITED_ROUTINE40_END_OFFSET := 0x1D67
const AUDITED_ROUTINE40_NATIVE_RECORD_OFFSETS := [0x1C95, 0x1CC4]
const AUDITED_DEF26_REGISTRATION_OFFSET := 0x01FC
const AUDITED_DEF26_BODY_OFFSET := 0x0203
const AUDITED_DEF26_SKIP_TARGET := 0x042D
const AUDITED_D_PIC_STANDING_RESOURCES := ["D.MMO", "D5.MMO", "D1.MMO", "D2.MMO", "D3.MMO", "D4.MMO"]
const PROMISE_DATE_ROUTE_KIND := "isolated_promise_date"
const NESTED_PROMISE_ROUTE_KIND := "audited_nested_promise"
const NESTED_PROMISE_TALK_ENTRY := "L_TALK30.MES"
const NESTED_PROMISE_TALK_SHA256 := "c66e0b8ecfbf86d5022885033b4737d8e672c87ae352f39c4d03557220956a54"
const NESTED_PROMISE_TALK_CHOICE_BOUNDARY := 0x0561
const NESTED_PROMISE_DEFINITION_IDS := [0, 1]
const NESTED_PROMISE_DEFINITION_OFFSETS := [0x026D, 0x02A8]
const NESTED_PROMISE_DEFINITION_TARGETS := [0x0285, 0x02C2]
const NESTED_PROMISE_ROUTES := {
	"44C.MES": {
		"entry_sha256": "49b5ae569923d6b0e58bf6bf64786f2e96fe9de00c9bad56cd450cb4a487d0ce",
		"owner_index": 376,
		"intro": 0xC52A,
		"talk_call": 0xC593,
		"talk_resume": 0xC5A3,
		"promise_gate": 0xC6DC,
		"promise_call": 0xC6EC,
	},
	"L_HOTEL2.MES": {
		"entry_sha256": "5ed3ba5238949f180a8da82961df9d9fe6b8bf818dbc7cf464c84ac38de85e49",
		"owner_index": 142,
		"intro": 0x421C,
		"talk_call": 0x4292,
		"talk_resume": 0x42A2,
		"promise_gate": 0x43DB,
		"promise_call": 0x43EB,
	},
}
const PROMISE_DATE_ROUTE_DEFINITIONS := {
	"A_PROMIS.MES": {
		"entry_sha256": "81d3de790b2a1542f09dfedd753c5010970971acb38e64b9e0241c6c2f31ca19",
		"intro": 0x2036, "boundary": 0x2091, "resume": 0x2096,
		"writer": 0x209B, "date_suffix_rows": 103, "field": 215,
		"choice_boundary": 0x2C6B, "choice_resume": 0x2C70, "location_field": 119,
	},
	"B_PROMIS.MES": {
		"entry_sha256": "c1270051a6ea49bcc84fae4d9060e6d2bc114b672dc8beecdf5e97dc552c446d",
		"intro": 0x253A, "boundary": 0x2591, "resume": 0x2596,
		"writer": 0x259B, "date_suffix_rows": 70, "field": 233,
		"choice_boundary": 0x2F88, "choice_resume": 0x2F8D, "location_field": 209,
	},
	"C_PROMIS.MES": {
		"entry_sha256": "485e997c7c328277de5dbdd11f32bcff291a20005825a26d5aecfbc172eb3fba",
		"intro": 0x1B97, "boundary": 0x1C0B, "resume": 0x1C10,
		"writer": 0x1C15, "field": 225,
		"choice_boundary": 0x2655, "choice_resume": 0x265A, "location_field": 169,
		"validation_mode": "presentation_to_choice", "validation_dialogues": 4,
	},
	"D_PROMIS.MES": {
		"entry_sha256": "5d5a09ad7cb4a2a3af70cc6d32588d67445de5db585144c796bb0b722e661f68",
		"intro": 0x1CD0, "boundary": 0x1D2D, "resume": 0x1D32,
		"writer": 0x1D37, "date_suffix_rows": 70, "field": 237,
		"choice_boundary": 0x2726, "choice_resume": 0x272B, "location_field": 229,
	},
	"E_PROMIS.MES": {
		"entry_sha256": "0c72ae3a7977cb61753d73a3bee118ee230546f16752412081f63f054beca711",
		"intro": 0x1D50, "boundary": 0x1DBA, "resume": 0x1DBF,
		"writer": 0x1DC4, "field": 217,
		"choice_boundary": 0x2817, "choice_resume": 0x281C, "location_field": 129,
		"validation_mode": "presentation_to_choice", "validation_dialogues": 4,
	},
	"F_PROMIS.MES": {
		"entry_sha256": "60d8638c9d422a189dbd2b08ee6127ccdcb18a38370be0d965b8dfdd62492f08",
		"intro": 0x1DDE, "boundary": 0x1E3F, "resume": 0x1E44,
		"writer": 0x1E49, "date_suffix_rows": 78, "field": 213,
		"choice_boundary": 0x289B, "choice_resume": 0x28A0, "location_field": 109,
	},
	"G_PROMIS.MES": {
		"entry_sha256": "a3bb5f57e28def5baea46271813ea4529472a5568b48f05384468d9f4442ca8e",
		"intro": 0x2648, "boundary": 0x269D, "resume": 0x26A2,
		"writer": 0x26A7, "date_suffix_rows": 80, "field": 221,
		"choice_boundary": 0x3114, "choice_resume": 0x3119, "location_field": 149,
	},
	"H_PROMIS.MES": {
		"entry_sha256": "395a8c8290c57bf2cabfe679fa866369c2af5a9069527dfeb29cef245b25cdf8",
		"intro": 0x1D7D, "boundary": 0x1DDC, "resume": 0x1DE1,
		"writer": 0x1DE6, "date_suffix_rows": 80, "field": 227,
		"choice_boundary": 0x2855, "choice_resume": 0x285A, "location_field": 179,
	},
	"I_PROMIS.MES": {
		"entry_sha256": "afad7ff835232442f2d366fc3d4a0960a4b60fc74a6ceaf4cb8c365b1f5d7e30",
		"intro": 0x2554, "boundary": 0x25C4, "resume": 0x25C9,
		"writer": 0x25CE, "field": 219,
		"choice_boundary": 0x3039, "choice_resume": 0x303E, "location_field": 139,
		"validation_mode": "presentation_to_choice", "validation_dialogues": 4,
	},
	"J_PROMIS.MES": {
		"entry_sha256": "e64748323d69b53cd5db38ce1bb44353ec719d0c80d41bc3c04c39a0598672f2",
		"intro": 0x1DBB, "boundary": 0x1E12, "resume": 0x1E17,
		"writer": 0x1E1C, "date_suffix_rows": 70, "field": 235,
		"choice_boundary": 0x281D, "choice_resume": 0x2822, "location_field": 219,
	},
	"K_PROMIS.MES": {
		"entry_sha256": "0a06c7efea59f44ca3bea815f7a8f25bfa5e08397e6c774f976811500582f90b",
		"intro": 0x21CF, "boundary": 0x221A, "resume": 0x221F,
		"writer": 0x2224, "date_suffix_rows": 80, "field": 229,
		"choice_boundary": 0x2C9B, "choice_resume": 0x2CA0, "location_field": 189,
	},
	"L_PROMIS.MES": {
		"entry_sha256": "4dd0cfd93a2f0146764a3086ba5dec1429775e22ce9e1c511fdb013faf14e40c",
		"intro": 0x1C13, "boundary": 0x1C72, "resume": 0x1C77,
		"writer": 0x1C7C, "date_suffix_rows": 80, "field": 231,
		"choice_boundary": 0x26F5, "choice_resume": 0x26FA, "location_field": 199,
	},
}
const CONFIRMED_PREVIEW_ANCHORS := {
	"44C.MES": {
		"entry_sha256": "49b5ae569923d6b0e58bf6bf64786f2e96fe9de00c9bad56cd450cb4a487d0ce",
		"anchors": [{
			"label": "L conversation through nested choice to PROMIS boundary",
			"offset": 0xC52A,
			"event_start_kind": NESTED_PROMISE_ROUTE_KIND,
		}],
	},
	"L_HOTEL2.MES": {
		"entry_sha256": "5ed3ba5238949f180a8da82961df9d9fe6b8bf818dbc7cf464c84ac38de85e49",
		"anchors": [{
			"label": "L hotel conversation through nested choice to PROMIS boundary",
			"offset": 0x421C,
			"event_start_kind": NESTED_PROMISE_ROUTE_KIND,
		}],
	},
	"EVENTB01.MES": {
		"source": KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY,
		"anchors": [{
			"label": "Mahoko event from original zero-coordinate caller to first dialogue",
			"event_start_kind": "dialogue",
		}],
	},
	"EVENTB02.MES": {
		"source": KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY,
		"anchors": [{
			"label": "Mahoko event from original zero-coordinate caller to first dialogue",
			"event_start_kind": "dialogue",
		}],
	},
	"EVENTB15.MES": {
		"source": KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY,
		"anchors": [{
			"label": "Mahoko event from original 11M zero-coordinate caller to first dialogue",
			"event_start_kind": "dialogue",
		}],
	},
	"EVENTB14.MES": {
		"source": KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY,
		"anchors": [{
			"label": "Mahoko event from original 44M zero-coordinate caller to first dialogue",
			"event_start_kind": "dialogue",
		}],
	},
	"EVENTD01.MES": {
		"source": KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY,
		"anchors": [
			{
				"label": "Maki event from original zero-coordinate caller",
				"event_start_kind": "dialogue",
			},
		],
	},
	"EVENTD02.MES": {
		"source": KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY,
		"anchors": [
			{
				"label": "Maki event from original zero-coordinate caller",
				"event_start_kind": "dialogue",
			},
		],
	},
	"D_PIC.MES": {
		"entry_sha256": "72473432ce3dd6e0fc1e994a737dbecd5494eaf4477efc24368d3b3160d7fecd",
		"anchors": [
			{"label": "D.MMO standing", "offset": 0x00CC},
			{"label": "D5.MMO standing", "offset": 0x0172},
			{"label": "D1.MMO standing", "offset": 0x023C},
			{"label": "D2.MMO standing", "offset": 0x02E6},
			{"label": "D3.MMO standing", "offset": 0x0390},
			{"label": "D4.MMO standing", "offset": 0x043A},
		],
	},
	"EVENTD03.MES": {
		"source": KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY,
		"anchors": [
			{
				"label": "Maki event from original zero-coordinate caller",
				"event_start_kind": "dialogue",
			},
		],
	},
	"EVENTD05.MES": {
		"source": KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY,
		"anchors": [
			{
				"label": "Maki complete dialogue and choice route",
				"event_start_kind": "dialogue",
				"prelude_mmo_route": "eventd05_hhmm",
			},
		],
	},
	"EVENTD08.MES": {
		"source": KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY,
		"anchors": [
			{
				"label": "Maki complete dialogue and choice route",
				"event_start_kind": "dialogue",
				"prelude_bgm": "MAKI.WAV",
				"prelude_bgm_selector": 33,
				"prelude_bgm_offset": 0x009A,
				"prelude_bgm_boundary": 0x00A0,
				"prelude_bgm_routine": 23,
				"prelude_bgm_entry": "D_PIC.MES",
				"prelude_bgm_entry_sha256": KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY,
			},
		],
	},
	"EVENTD14.MES": {
		"source": KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY,
		"anchors": [
			{
				"label": "Maki confirmed zero-start event bootstrap",
				"event_start_kind": "catalog_bootstrap",
			},
		],
	},
	"DEF_MAIN.MES": {
		"source": KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY,
		"anchors": [
			{
				"label": "DEF 26 isolated presentation body",
				"offset": AUDITED_DEF26_BODY_OFFSET,
				"event_start_kind": "isolated_body",
			},
		],
	},
}
const MEANINGFUL_SOURCE_SCAN_LIMIT := 16

@onready var archive_label: Label = %ArchiveLabel
@onready var view_mode_select: OptionButton = %ViewMode
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var sources_panel: VBoxContainer = %Sources
@onready var filter_edit: LineEdit = %FilterEdit
@onready var entry_tree: Tree = %EntryTree
@onready var address_tree: Tree = %AddressTree
@onready var intro_edit: LineEdit = %IntroEdit
@onready var intro_label: Label = %IntroLabel
@onready var run_button: Button = %Run
@onready var preview_fragment_button: Button = %PreviewFragment
@onready var previous_fragment_button: Button = %PreviousFragment
@onready var next_fragment_button: Button = %NextFragment
@onready var previous_meaningful_button: Button = %PreviousMeaningful
@onready var next_meaningful_button: Button = %NextMeaningful
@onready var start_event_button: Button = %StartEvent
@onready var continue_button: Button = %Continue
@onready var bgm_toggle_button: Button = %BgmToggle
@onready var game_preview: ContentToolGamePreview = %GamePreview
@onready var _preview_entry_label: Label = %PreviewEntryLabel
@onready var _preview_background_label: Label = %PreviewResourceLabel
@onready var preview_diagnostics: HBoxContainer = %PreviewDiagnostics
@onready var preview_audio: AudioStreamPlayer = %PreviewAudio
@onready var preview_effect_audio: AudioStreamPlayer = %PreviewEffectAudio
@onready var preview_voice: AudioStreamPlayer = %PreviewVoice
@onready var state_json: TextEdit = %StateJson
@onready var legacy_date_edit: SpinBox = %LegacyDateEdit
@onready var weekday_edit: SpinBox = %WeekdayEdit
@onready var hhmm_edit: SpinBox = %HhmmEdit
@onready var mahoko_affection_edit: SpinBox = %MahokoAffectionEdit
@onready var maki_affection_edit: SpinBox = %MakiAffectionEdit
@onready var promise_location_label: Label = %PromiseLocationLabel
@onready var promise_location_edit: SpinBox = %PromiseLocationEdit
@onready var apply_promise_location_button: Button = %ApplyPromiseLocation
@onready var flag_index_edit: SpinBox = %FlagIndexEdit
@onready var flag_value_edit: SpinBox = %FlagValueEdit
@onready var protagonist_name_edit: LineEdit = %ProtagonistNameEdit
@onready var work_tabs: TabContainer = %WorkTabs
@onready var result_tabs: TabContainer = %ResultTabs
@onready var trace_tree: Tree = %TraceTree
@onready var message_tree: Tree = %MessageTree
@onready var state_diff_tree: Tree = %StateDiffTree
@onready var script_call_tree: Tree = %ScriptCallTree
@onready var shared_routine_tree: Tree = %SharedRoutineTree
@onready var output: RichTextLabel = %Output
@onready var status_label: Label = %StatusLabel
@onready var catalog_window: Window = %CatalogWindow
@onready var catalog_text_filter: LineEdit = %CatalogTextFilter
@onready var catalog_character_filter: LineEdit = %CatalogCharacterFilter
@onready var catalog_date_filter: LineEdit = %CatalogDateFilter
@onready var catalog_place_filter: LineEdit = %CatalogPlaceFilter
@onready var catalog_type_filter: LineEdit = %CatalogTypeFilter
@onready var catalog_status_filter: OptionButton = %CatalogStatusFilter
@onready var catalog_count_label: Label = %CatalogCountLabel
@onready var catalog_tree: Tree = %CatalogTree
@onready var catalog_details: RichTextLabel = %CatalogDetails
@onready var catalog_preset_select: OptionButton = %CatalogPresetSelect
@onready var catalog_result_select: OptionButton = %CatalogResultSelect
@onready var catalog_state_form: VBoxContainer = %CatalogStateForm
@onready var catalog_use_form_state: CheckButton = %CatalogUseFormState
@onready var catalog_play_button: Button = %CatalogPlay
@onready var catalog_select_source_button: Button = %CatalogSelectSource
@onready var open_dialog: FileDialog = %OpenDialog
@onready var content_set_dialog: FileDialog = %ContentSetDialog
@onready var text_cache_dialog: FileDialog = %TextCacheDialog

var _reader: KakyuArcReader = ArcReaderScript.new()
var _content_set := ContentSetScript.new()
var _resolver := ContentResolverScript.new()
var _content_identity := ContentIdentityScript.new()
var _effective_media_identities: Dictionary = {}
var _parser := MesContainerScript.new()
var _runner := MesEventRunnerScript.new()
var _detached_definition_preview := MesDetachedDefinitionPreviewScript.new()
var _script_call_runner := MesScriptCallRunnerScript.new()
var _caller_route := MesCallerRouteScript.new()
var _state := SandboxStateScript.new(1)
var _text_cache := TextCacheScript.new()
var _cp932 := Cp932CodecScript.new()
var _mmo_codec := MmoCodecScript.new()
var _dat_pal_codec := DatPalCodecScript.new()
var _ax_dword_stream := AxDwordStreamScript.new()
var _ax_animation_reader := AxAnimationScript.new()
var _ax_playback_planner := AxPlaybackPlanScript.new()
var _ax_surface_binding := AxSurfaceBindingScript.new()
var _mes_active_surface_ax_audit := MesActiveSurfaceAxAuditScript.new()
var _mes_ax_runtime_chain := MesAxRuntimeChainScript.new()
var _stack_effect := MesStackEffectScript.new()
var _path_history := ToolPathHistoryScript.new()
var window_display_config_path := ToolWindowDisplayScript.DEFAULT_CONFIG_PATH
var _window_display: ContentToolWindowDisplay
var _launch_context := ContentLaunchContextScript.new()
var _event_catalog := EventCatalogScript.new()
var _event_analysis_profiles: KakyuEventAnalysisProfiles = null
var _event_analysis_profiles_error := ""
var _event_audio_state := EventAudioStateScript.new()
var _catalog_browser_rows: Dictionary = {}
var _catalog_preset_event_id := ""
# EP-10 unit 3: the guard-derived starting-state form.
var _catalog_guard_fields: Array = []
var _catalog_guard_field_values: Dictionary = {}
var _catalog_guard_caller_entry := ""
var _catalog_guard_offset := -1
var _v4_definition_site_index_built := false
var _v4_definition_site_index: Dictionary = {}
var _catalog_guard_definition_cache: Dictionary = {}
# Round 3 code review, item 5: the parsed caller document for the guard
# line, cached by "<entry>@<archive fingerprint>" so re-evaluating the
# guard on every field edit does not re-parse the same entry.
var _catalog_guard_document_cache: Dictionary = {}
var _catalog_playback_request: Dictionary = {}
var _catalog_terminal_match: Dictionary = {}
var _catalog_terminal_rejected_completion := false
var _catalog_playback_active := false
var _catalog_timeline_steps: Array = []
var _catalog_timeline_unclassified: Array = []
var _catalog_playback_autodriving := false
var _view_mode := VIEW_MODE_PLAYBACK
var _entries: Array[Dictionary] = []
var _document: Dictionary = {}
var _active_address_catalog: Dictionary = {}
var _catalog_fragment_summaries: Dictionary = {}
var _source_row_summaries: Dictionary = {}
var _library_index: Dictionary = {}
var _library_document: Dictionary = {}
var _startup_context: Dictionary = {}
var _selected_entry := ""
var _source_archive_paths: Dictionary = {}
var _source_archive_sha256: Dictionary = {}
var _text_cache_root := ""
var _text_messages: Dictionary = {}
var _preview_messages: Array[Dictionary] = []
var _preview_definitions: Array[Dictionary] = []
var _preview_message_index := -1
var _preview_result_status := ""
var _preview_result_offset := -1
var _preview_detached_definition_id := -1
var _preview_event_session := ""
var _preview_source_row_index := -1
var _preview_catalog_fragment_index := -1
var _preview_catalog_setup_native_fx_omitted := false
var _preview_catalog_confirmed_bootstrap := false
var _preview_event_complete := false
var _preview_completion_shown := false
var _preview_message_label: Label
var _preview_footer_label: Label
var _preview_mmo_name := ""
var _preview_mmo_status := ""
var _preview_dat_pal_name := ""
var _preview_dat_pal_status := ""
var _preview_foreground_mmo_name := ""
var _preview_foreground_mmo_status := ""
var _preview_ax_name := ""
var _preview_ax_status := ""
var _preview_ax_binding_table: Dictionary = {}
var _preview_surface_compositor := LogicalSurfaceCompositorScript.new()
var _preview_surface_background_checkpoint: Dictionary = {}
# EP-13 part A: what `_apply_timeline_step` last actually drew (not the
# previous timeline step's `visible` snapshot), so stepping backwards
# compares the target step against what is on screen instead of against the
# step two behind it.
var _preview_displayed_visible: Dictionary = {"background": "", "foreground": ""}
var _preview_bgm_name := ""
var _preview_bgm_stream: AudioStream
var _preview_voice_name := ""
var _preview_voice_archive := ""
var _preview_voice_stream: AudioStream
var _preview_effect_name := ""
var _preview_effect_stream: AudioStream
var _continuation_offset := -1
var _continuation_context: Dictionary = {}
var _choice_projection: Dictionary = {}
var _choice_index := -1
var _nested_promise_context: Dictionary = {}
var _nested_promise_reached_boundary := false


## TD-11 unit 2: a fresh evidence context built from the player's current
## members. Cheap, and a caller never holds a stale context.
func _evidence() -> KakyuEventPlayerEvidence:
	var evidence := KakyuEventPlayerEvidence.new()
	evidence.document = _document
	evidence.selected_entry = _selected_entry
	evidence.library_index = _library_index
	evidence.library_document = _library_document
	evidence.state = _state
	evidence.runner = _runner
	evidence.preview_event_session = _preview_event_session
	evidence.preview_definitions = _preview_definitions
	evidence.event_catalog = _event_catalog
	evidence.catalog_playback_request = _catalog_playback_request
	evidence.startup_context = _startup_context
	evidence.reader = _reader
	evidence.resolver = _resolver
	evidence.content_set = _content_set
	evidence.parser = _parser
	return evidence


# --- Evidence API -----------------------------------------------------------
#
# This player is an instrument of the analysis, not a product runtime, so its
# reason to exist is the evidence it produces. It had no way to produce that
# evidence except its user interface: twenty-one headless scripts instantiated
# the scene, added it to a live SceneTree, and drove the analysis by calling
# eighty-two private methods through `.call("_name")`, four hundred and twelve
# times, of which eighty-five were `_on_continue_pressed`. Advancing an analysis
# meant simulating a button press, and no compiler checked any of it.
#
# The methods below are that missing surface. They are named for what they mean
# to an analysis - open, load, start, advance, choose, inspect - rather than for
# the control that used to invoke them, and they delegate to the existing
# implementations without changing behaviour. A client holds a typed
# KakyuEventPlayer and calls them directly.
#
# That buys a declared protocol and a greppable identifier, not a static check.
# Godot 4.7 reports an unknown method on a typed value at run time, and the
# `--editor --quit-after` parse check does not report it either, so the type is
# documentation and editor completion rather than rejection. Every client here
# is a validator or a test that runs, so a break still surfaces.
#
# What is deliberately not here: the per-event entry points such as
# `_validate_eventb01_start`. Those are forty-one methods and ninety-two of the
# call sites, and they are per-event by nature; they belong with TD-04's move of
# per-event data into the catalog rather than in a generic surface.
#
# See todo/code_health.md TD-13 and docs/spec/tech/product_roles.md.


func open_content_set(path: String) -> void:
	_open_content_set(path)


func load_entry(entry_name: String, preserve_preview_session := false) -> void:
	_load_entry(entry_name, preserve_preview_session)


func select_address() -> void:
	_on_address_selected()


func set_view_mode(mode: String) -> Dictionary:
	return _set_view_mode(mode)


func start_event() -> void:
	_on_start_event_pressed()


func run_from_offset(start_offset: int, runtime_context := {}) -> void:
	_run_from_offset(start_offset, runtime_context)


## Round 2 code review, item 10: `build_play_request` results carry no view
## state - `play_catalog_request` plays a promoted (`analysis_group`) row
## outright (through `_play_group_route`); `analyze_catalog_request`
## analyzes it outright (through `_analyze_group_route`). Every catalog row
## carries `analysis_group` (EP-10 unit 5); the catalog button
## (`_on_catalog_play_pressed`) picks between the two by the current view
## mode.
func play_catalog_request(request: Dictionary) -> Dictionary:
	return _play_catalog_request(request)


func analyze_catalog_request(request: Dictionary) -> Dictionary:
	if _event_catalog.get_event(str(request.get("event_id", ""))).has("analysis_group"):
		return _analyze_group_route(request)
	return _play_catalog_request(request)


func advance() -> void:
	# The single most-called operation, and the clearest case of the interface
	# being the UI: this was `_on_continue_pressed`.
	_on_continue_pressed()


func step_preview_message(delta: int) -> void:
	_step_preview_message(delta)


func confirm_choice(index: int = -1) -> void:
	_confirm_projected_choice(index)


func send_preview_input(event: InputEvent, logical_position: Vector2) -> void:
	_on_game_preview_input(event, logical_position)


func reset_state() -> void:
	_on_reset_state_pressed()


func apply_quick_state() -> void:
	_on_apply_quick_state_pressed()


func confirmed_event_start() -> Dictionary:
	return _confirmed_event_start()


func resolve_mmo_image(resource_name: String) -> Dictionary:
	return _resolve_mmo_image(resource_name)


func latest_ax_resource(trace: Array) -> String:
	return _present_latest_ax_resource(trace)


func catalog_source_contract_evidence(definition: Dictionary) -> Dictionary:
	# The guard behind `_active_address_catalog.ok`. Exposed so a validator can
	# prove it rejects a changed hash, entry count or caller as well as accept
	# the original, which the positive contract alone cannot show.
	return _validate_address_catalog_source(definition)


func confirmed_address_catalog(entry_name: String, entry_sha256: String) -> Dictionary:
	return _confirmed_address_catalog(entry_name, entry_sha256)


func _ready() -> void:
	set_process(false)
	_window_display = _make_window_display()
	fullscreen_toggle.set_pressed_no_signal(_window_display.apply(get_window()) == ToolWindowDisplayScript.MODE_FULLSCREEN)
	entry_tree.set_column_title(0, "MES entry")
	entry_tree.set_column_title(1, "Bytes")
	address_tree.set_column_title(0, "Intro / confirmed preview")
	address_tree.set_column_title(1, "Code offset")
	address_tree.set_column_title(2, "Bytes / first stop")
	trace_tree.set_column_title(0, "Step")
	trace_tree.set_column_title(1, "MES / offset")
	trace_tree.set_column_title(2, "Opcode")
	trace_tree.set_column_title(3, "Effect / next")
	message_tree.set_column_title(0, "Offset")
	message_tree.set_column_title(1, "MES / text source")
	message_tree.set_column_title(2, "Text / raw CP932")
	message_tree.set_column_expand(0, false)
	message_tree.set_column_expand(1, false)
	message_tree.set_column_custom_minimum_width(0, 86)
	message_tree.set_column_custom_minimum_width(1, 78)
	state_diff_tree.set_column_title(0, "Storage")
	state_diff_tree.set_column_title(1, "Bank")
	state_diff_tree.set_column_title(2, "Index")
	state_diff_tree.set_column_title(3, "Before -> After")
	script_call_tree.set_column_title(0, "Depth")
	script_call_tree.set_column_title(1, "Caller / call")
	script_call_tree.set_column_title(2, "Callee")
	script_call_tree.set_column_title(3, "Resume / return")
	shared_routine_tree.set_column_title(0, "Offset")
	shared_routine_tree.set_column_title(1, "Opcode")
	shared_routine_tree.set_column_title(2, "Structural detail")
	shared_routine_tree.set_column_title(3, "Raw bytes")
	work_tabs.set_tab_title(0, "Sandbox")
	work_tabs.set_tab_title(1, "Results")
	result_tabs.set_tab_title(0, "Trace")
	result_tabs.set_tab_title(1, "Messages")
	result_tabs.set_tab_title(2, "State Diff")
	result_tabs.set_tab_title(3, "Script Calls")
	result_tabs.set_tab_title(4, "Shared Routine")
	result_tabs.set_tab_title(5, "Summary")
	_setup_game_preview()
	_setup_view_mode()
	preview_audio.finished.connect(_sync_bgm_button)
	_path_history.apply_source_dialog(open_dialog)
	_path_history.apply_elfimage_dialog(content_set_dialog)
	state_json.text = "[]"
	_sync_quick_state_fields()
	_setup_event_catalog_browser()
	var arguments := OS.get_cmdline_user_args()
	_apply_startup_arguments(arguments)


func _make_window_display() -> ContentToolWindowDisplay:
	return ToolWindowDisplayScript.new("event_player", window_display_config_path)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event
	if key_event.keycode == KEY_F11 or (key_event.keycode == KEY_ENTER and key_event.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> String:
	var mode := _window_display.toggle(get_window())
	var is_fullscreen := mode == ToolWindowDisplayScript.MODE_FULLSCREEN
	fullscreen_toggle.set_pressed_no_signal(is_fullscreen)
	status_label.text = "Fullscreen: on" if is_fullscreen else "Fullscreen: off"
	return mode


func _on_fullscreen_toggle_toggled(_pressed: bool) -> void:
	toggle_fullscreen()


func _setup_view_mode() -> void:
	view_mode_select.clear()
	view_mode_select.add_item("Playback")
	view_mode_select.set_item_metadata(0, VIEW_MODE_PLAYBACK)
	view_mode_select.add_item("Analysis")
	view_mode_select.set_item_metadata(1, VIEW_MODE_ANALYSIS)
	_set_view_mode(VIEW_MODE_PLAYBACK)


func _on_view_mode_selected(index: int) -> void:
	if index < 0 or index >= view_mode_select.item_count:
		return
	_set_view_mode(str(view_mode_select.get_item_metadata(index)))


func _set_view_mode(mode: String) -> Dictionary:
	var normalized := mode.strip_edges().to_lower()
	if normalized not in [VIEW_MODE_PLAYBACK, VIEW_MODE_ANALYSIS]:
		return {"ok": false, "error": "Unknown Event Player view mode: %s" % mode}
	_view_mode = normalized
	var analysis := normalized == VIEW_MODE_ANALYSIS
	sources_panel.visible = analysis
	intro_label.visible = analysis
	intro_edit.visible = analysis
	run_button.visible = analysis
	preview_fragment_button.visible = analysis
	preview_diagnostics.visible = analysis
	work_tabs.visible = analysis
	status_label.visible = analysis
	for index in range(view_mode_select.item_count):
		if str(view_mode_select.get_item_metadata(index)) == normalized:
			view_mode_select.select(index)
			break
	_continue_catalog_playback_if_needed()
	_sync_catalog_play_button_text()
	return {"ok": true, "mode": _view_mode}


func _setup_event_catalog_browser() -> void:
	catalog_tree.set_column_title(0, "Event")
	catalog_tree.set_column_title(1, "Character")
	catalog_tree.set_column_title(2, "Playback")
	catalog_tree.set_column_title(3, "Blocker")
	catalog_tree.set_column_expand(0, true)
	for column in [1, 2, 3]: catalog_tree.set_column_expand(column, false)
	catalog_status_filter.clear()
	for pair in [["All support", ""], ["Minimal playback", "minimal_playback"], ["Analysis only", "analysis_only"], ["Blocked", "blocked"], ["Not applicable", "not_applicable"]]:
		catalog_status_filter.add_item(str(pair[0]))
		catalog_status_filter.set_item_metadata(catalog_status_filter.item_count - 1, str(pair[1]))
	var loaded := _event_catalog.load_file(EVENT_CATALOG_PATH)
	if not loaded.ok:
		catalog_details.text = "Event Catalog rejected: %s" % str(loaded.error)
		catalog_play_button.disabled = true
		catalog_select_source_button.disabled = true
		return
	_rebuild_event_catalog_browser()


func _on_catalog_pressed() -> void:
	_on_catalog_event_selected()
	catalog_window.popup_centered(Vector2i(1050, 700))


func _on_catalog_filter_changed(_value = null) -> void:
	_rebuild_event_catalog_browser()


func _rebuild_event_catalog_browser() -> void:
	var status := ""
	if catalog_status_filter.selected >= 0:
		status = str(catalog_status_filter.get_item_metadata(catalog_status_filter.selected))
	var result := _event_catalog.build_browser_rows({
		"text": catalog_text_filter.text,
		"character_id": catalog_character_filter.text,
		"date_tag": catalog_date_filter.text,
		"place_id": catalog_place_filter.text,
		"event_type": catalog_type_filter.text,
		"playback_status": status,
	})
	catalog_tree.clear()
	_catalog_browser_rows.clear()
	_clear_catalog_preset_selection()
	catalog_play_button.disabled = true
	catalog_select_source_button.disabled = true
	if not result.ok:
		catalog_count_label.text = "Catalog filter rejected"
		catalog_details.text = str(result.error)
		return
	var root := catalog_tree.create_item()
	for untyped_row in result.rows:
		var row: Dictionary = untyped_row
		_catalog_browser_rows[str(row.event_id)] = row
		var item := catalog_tree.create_item(root)
		item.set_text(0, str(row.title))
		item.set_text(1, ", ".join(row.character_ids))
		item.set_text(2, str(row.playback_status).replace("_", " "))
		item.set_text(3, "blocked" if row.has_blocking_blocker else ("%d note(s)" % row.blockers.size() if not row.blockers.is_empty() else "none"))
		item.set_metadata(0, str(row.event_id))
	catalog_count_label.text = "%d visible / %d cataloged events" % [int(result.visible_count), int(result.total_count)]
	catalog_details.text = "Select a catalog event to inspect playback support."


func _on_catalog_event_selected() -> void:
	var item := catalog_tree.get_selected()
	var event_id := str(item.get_metadata(0)) if item != null else ""
	_sync_catalog_preset_selection(event_id)
	_refresh_catalog_event_details()


func _clear_catalog_preset_selection() -> void:
	_catalog_preset_event_id = ""
	catalog_preset_select.clear()
	catalog_preset_select.disabled = true
	catalog_preset_select.text = "Select preset"
	catalog_preset_select.tooltip_text = "Select a catalog event first."
	_clear_catalog_result_selection()
	_clear_catalog_state_form()


func _clear_catalog_result_selection() -> void:
	catalog_result_select.clear()
	catalog_result_select.disabled = true
	catalog_result_select.text = "Select result"
	catalog_result_select.visible = false


func _sync_catalog_preset_selection(event_id: String) -> void:
	var event := _event_catalog.get_event(event_id)
	if event_id.is_empty() or event.is_empty() or not _catalog_browser_rows.has(event_id):
		_clear_catalog_preset_selection()
		return
	var same_event := _catalog_preset_event_id == event_id
	var retained_id := ""
	if same_event and catalog_preset_select.selected >= 0:
		retained_id = str(catalog_preset_select.get_item_metadata(catalog_preset_select.selected))
	_catalog_preset_event_id = event_id
	catalog_preset_select.clear()
	var is_group_route := event.has("analysis_group")
	# Round 3 code review, item 9: the default option is whatever
	# `build_play_request` itself defaults to (its own `_build_group_route_request`
	# option-selection rule), not a second, separately maintained copy of it.
	var default_probe_request := _event_catalog.build_play_request(event_id, "", "")
	var default_option_id := str(default_probe_request.get("selection", {}).get("option_id", "")) if default_probe_request.get("ok", false) else ""
	var resolved_preset_id := "" if same_event else (_measured_group_route_preset_id(event_id, default_option_id) if is_group_route else "")
	var selected_index := -1
	for preset_value in event.get("presets", []):
		var preset: Dictionary = preset_value
		var index := catalog_preset_select.item_count
		var preset_id := str(preset.get("preset_id", ""))
		catalog_preset_select.add_item(str(preset.get("label", preset_id)))
		catalog_preset_select.set_item_metadata(index, preset_id)
		if same_event and preset_id == retained_id:
			selected_index = index
		elif not same_event and is_group_route and not resolved_preset_id.is_empty() and preset_id == resolved_preset_id:
			selected_index = index
		elif not same_event and not is_group_route and selected_index < 0 and str(preset.get("kind", "")) == "original_branch":
			selected_index = index
	if not same_event and is_group_route and selected_index < 0 and catalog_preset_select.item_count > 0:
		# EP-10 unit 2 owner ruling: no preset's readiness resolved (e.g. no
		# archive is open); fall back to the first preset rather than none.
		selected_index = 0
	catalog_preset_select.disabled = catalog_preset_select.item_count == 0
	catalog_preset_select.select(selected_index)
	if selected_index < 0:
		catalog_preset_select.text = "Select preset"
	catalog_preset_select.tooltip_text = (
		"The previous preset is no longer available; select a current preset explicitly."
		if same_event and selected_index < 0 and not retained_id.is_empty()
		else "Select the exact catalog preset to inspect and play."
	)
	var choices: Array = event.get("choices", [])
	# Round 9 code review, item 2: the chosen result is retained on the
	# same_event path, exactly as the preset is - only a different row
	# resets it to the default measured option.
	var retained_option_id := ""
	if same_event and not catalog_result_select.disabled and catalog_result_select.selected >= 0:
		retained_option_id = str(catalog_result_select.get_item_metadata(catalog_result_select.selected))
	catalog_result_select.clear()
	if choices.is_empty():
		_clear_catalog_result_selection()
	else:
		var choice: Dictionary = choices[0]
		var default_result_index := -1
		var retained_index := -1
		for option_value in choice.get("options", []):
			var option: Dictionary = option_value
			var index := catalog_result_select.item_count
			var terminal_ids: Array = option.get("terminal_ids", [])
			var measured := not terminal_ids.is_empty()
			var strings: Array[String] = []
			for terminal_id in terminal_ids:
				strings.append(str(terminal_id))
			var option_id := str(option.get("option_id", ""))
			var label := "%s -> %s" % [option_id, ", ".join(strings)]
			if not measured:
				label += " (not measured)"
			catalog_result_select.add_item(label)
			catalog_result_select.set_item_metadata(index, option_id)
			catalog_result_select.set_item_disabled(index, not measured)
			if measured and default_result_index < 0:
				default_result_index = index
			if same_event and measured and option_id == retained_option_id:
				retained_index = index
		catalog_result_select.disabled = catalog_result_select.item_count == 0
		catalog_result_select.visible = true
		catalog_result_select.select(retained_index if retained_index >= 0 else default_result_index)
	_sync_catalog_state_form(event_id)


func _clear_catalog_state_form() -> void:
	for child in catalog_state_form.get_children():
		catalog_state_form.remove_child(child)
		child.queue_free()
	_catalog_guard_fields = []
	_catalog_guard_field_values = {}
	_catalog_guard_caller_entry = ""
	_catalog_guard_offset = -1
	if catalog_use_form_state != null:
		catalog_use_form_state.button_pressed = false
		catalog_use_form_state.disabled = true
		# Round 3 code review, item 3: the toggle is hidden, not merely
		# disabled, for a row that cannot use it at all.
		catalog_use_form_state.visible = false


## The v4 document `(caller.entry.upper(), caller.offset)` index, scanned
## from the v4 directory once and cached - the same key the promotion
## generator uses, so a hand-authored row's site finds its document too.
func _v4_site_index() -> Dictionary:
	if _v4_definition_site_index_built:
		return _v4_definition_site_index
	_v4_definition_site_index_built = true
	_v4_definition_site_index = {}
	var directory := DirAccess.open("res://config/event_definitions/v4")
	if directory == null:
		return _v4_definition_site_index
	for file_name in directory.get_files():
		if not file_name.ends_with(".json") or file_name == "index.json":
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/event_definitions/v4".path_join(file_name)))
		if not parsed is Dictionary:
			continue
		var doc: Dictionary = parsed
		var caller: Dictionary = doc.get("trigger", {}).get("caller", {})
		if caller.is_empty():
			continue
		var key := "%s:%d" % [str(caller.get("entry", "")).to_upper(), int(caller.get("offset", -1))]
		_v4_definition_site_index[key] = str(doc.get("id", ""))
	return _v4_definition_site_index


func _guard_definition_id_for_event(event: Dictionary) -> String:
	var definition_id := str(event.get("analysis_group", {}).get("definition_id", ""))
	if not definition_id.is_empty():
		return definition_id
	var caller: Dictionary = event.get("source", {}).get("caller", {})
	var key := "%s:%d" % [str(caller.get("entry", "")).to_upper(), int(caller.get("dispatch_offset", -1))]
	return str(_v4_site_index().get(key, ""))


func _guard_definition(definition_id: String) -> Dictionary:
	if definition_id.is_empty():
		return {}
	if _catalog_guard_definition_cache.has(definition_id):
		return _catalog_guard_definition_cache[definition_id]
	var path := "res://config/event_definitions/v4/%s.json" % definition_id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var document: Dictionary = parsed if parsed is Dictionary else {}
	_catalog_guard_definition_cache[definition_id] = document
	return document


func _catalog_guard_base_writes() -> Array:
	var selected := _selected_catalog_preset()
	if not selected.get("ok", false):
		return []
	return (selected.preset as Dictionary).get("writes", []).duplicate(true)


func _sync_catalog_state_form(event_id: String) -> void:
	_clear_catalog_state_form()
	var event := _event_catalog.get_event(event_id)
	if event.is_empty():
		return
	# Round 3 code review, item 3: the toggle only ever applies to a
	# promoted (`analysis_group`) row; a hand-authored row shows the form
	# read-only instead, with no toggle at all.
	if not event.has("analysis_group"):
		var hand_row_label := Label.new()
		hand_row_label.text = "Tool-seeded runs apply to promoted rows."
		catalog_state_form.add_child(hand_row_label)
		return
	if catalog_use_form_state != null:
		catalog_use_form_state.visible = true
	var definition_id := _guard_definition_id_for_event(event)
	var definition := _guard_definition(definition_id)
	# The 10 `caller_prefix`-origin v4 documents carry an explicit `"guard": null`.
	var guard_value: Dictionary = definition.get("guard", {}) if definition.get("guard", null) is Dictionary else {}
	var conjuncts: Array = guard_value.get("conjuncts", [])
	if definition.is_empty() or guard_value.is_empty() or conjuncts.is_empty():
		var label := Label.new()
		label.text = "No typed guard; the presets are the only starting states."
		catalog_state_form.add_child(label)
		return
	var built := KakyuEventGuardForm.fields(conjuncts)
	_catalog_guard_fields = built.fields
	var writes_by_key := KakyuEventGuardForm.writes_by_key(_catalog_guard_base_writes())
	for field_value in _catalog_guard_fields:
		var field: Dictionary = field_value
		var row := HBoxContainer.new()
		# The run settings share the catalog window with the event list, so a
		# row's labels wrap instead of widening the column past the window
		# (2026-09-24: a long form pushed the Play button out of view).
		var name_label := Label.new()
		name_label.text = str(field.label)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size = Vector2(90, 0)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var spin := SpinBox.new()
		spin.min_value = int(field.min)
		spin.max_value = int(field.max)
		spin.step = 1
		var field_key := str(field.key)
		var initial: int = int(writes_by_key[field_key]) if writes_by_key.has(field_key) else _state.read_value(str(field.storage), int(field.index), int(field.bank))
		spin.value = clampi(initial, int(field.min), int(field.max))
		_catalog_guard_field_values[field_key] = int(spin.value)
		spin.value_changed.connect(_on_catalog_guard_field_changed.bind(field_key))
		row.add_child(spin)
		var hint := Label.new()
		var hint_bits: Array[String] = []
		if not (field.excluded as Array).is_empty():
			var excluded_strings: Array[String] = []
			for excluded_value in field.excluded:
				excluded_strings.append(str(excluded_value))
			hint_bits.append("excludes %s" % ", ".join(excluded_strings))
		hint_bits.append(str(field.cell_class))
		hint.text = "; ".join(hint_bits)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(60, 0)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(hint)
		catalog_state_form.add_child(row)
	for readonly_value in (built.readonly as Array):
		var readonly: Dictionary = readonly_value
		var readonly_label := Label.new()
		readonly_label.text = str(readonly.text)
		readonly_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		catalog_state_form.add_child(readonly_label)
	var guard_line := Label.new()
	guard_line.name = "GuardLine"
	guard_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalog_state_form.add_child(guard_line)
	var caller: Dictionary = event.get("source", {}).get("caller", {})
	_catalog_guard_caller_entry = str(caller.get("entry", ""))
	_catalog_guard_offset = int(guard_value.get("offset", -1))
	_refresh_catalog_guard_line()


func _on_catalog_guard_field_changed(value: float, key: String) -> void:
	_catalog_guard_field_values[key] = int(value)
	_refresh_catalog_guard_line()
	_refresh_catalog_event_details()


## The document parsed from `entry` in the currently open archive, cached by
## `(entry, archive fingerprint)` (round 3 code review, item 5) so the guard
## line does not re-parse the same entry on every field edit. `{}` when no
## archive is open or the entry cannot be read.
func _cached_catalog_guard_document(entry: String) -> Dictionary:
	if entry.is_empty() or not _reader.is_open():
		return {}
	var cache_key := "%s@%s" % [entry, _reader.get_archive_identity_fingerprint()]
	if _catalog_guard_document_cache.has(cache_key):
		return _catalog_guard_document_cache[cache_key]
	var data := _reader.read_entry(entry)
	if data.is_empty():
		return {}
	var document := _parser.parse(data, {"entry": entry})
	_catalog_guard_document_cache[cache_key] = document
	return document


## The analysis-group route the currently selected catalog preset (the base
## preset the guard form started from) resolves to, or `{}` when it cannot
## be resolved (no archive-independent profile match) - used only to seed
## the route's own runtime calendar context, exactly as the service does.
func _catalog_guard_route() -> Dictionary:
	var selected := _selected_catalog_preset()
	if not selected.get("ok", false):
		return {}
	var profiles := _ensure_event_analysis_profiles()
	if profiles == null:
		return {}
	var event := _event_catalog.get_event(str(selected.event_id))
	var analyzer := preload("res://tools/content_suite/catalog_analysis_run.gd").new()
	var reference := analyzer.resolve_group_route_reference(event, str((selected.preset as Dictionary).get("notes", "")), profiles)
	return reference.get("route", {}) if not reference.is_empty() else {}


func _fail_catalog_guard_line(guard_line: Label, text: String) -> void:
	guard_line.text = text
	catalog_use_form_state.disabled = true
	catalog_use_form_state.button_pressed = false


func _refresh_catalog_guard_line() -> void:
	var guard_line: Label = catalog_state_form.get_node_or_null("GuardLine")
	if guard_line == null or catalog_use_form_state == null:
		return
	if not _reader.is_open():
		_fail_catalog_guard_line(guard_line, "Guard: archive not open")
		return
	var document := _cached_catalog_guard_document(_catalog_guard_caller_entry)
	if not document.get("ok", false):
		_fail_catalog_guard_line(guard_line, "Guard: archive not open")
		return
	var code: PackedByteArray = document.get("bytecode", PackedByteArray())
	# Round 3 code review, items 2 and 6: the same `seed_route_state` the
	# service runs seeds this preview too (the route's own calendar context,
	# when it has one, then the writes), so the guard line and the service's
	# refusal can never disagree.
	var route := _catalog_guard_route()
	var documents := {}
	var state_context: Dictionary = route.get("state_context", {})
	if str(state_context.get("kind", "")) == "original_calendar":
		var context_entry := str(state_context.get("entry", ""))
		var context_document := _cached_catalog_guard_document(context_entry)
		if not context_document.get("ok", false):
			_fail_catalog_guard_line(guard_line, "Guard: archive not open")
			return
		documents[context_entry] = context_document
	var writes := KakyuEventGuardForm.writes(_catalog_guard_fields, _catalog_guard_field_values, _catalog_guard_base_writes())
	var analyzer := preload("res://tools/content_suite/catalog_analysis_run.gd").new()
	var seeded := analyzer.seed_route_state(documents, route, writes)
	if not seeded.get("ok", false):
		_fail_catalog_guard_line(guard_line, "Guard: fails")
		return
	var result := KakyuEventGuardForm.guard_result(code, code.size(), _catalog_guard_offset, seeded.state)
	var passes: bool = result.get("passes", false)
	guard_line.text = "Guard: passes" if passes else "Guard: fails"
	catalog_use_form_state.disabled = not passes
	if not passes:
		catalog_use_form_state.button_pressed = false


func _measured_group_route_preset_id(event_id: String, option_id: String) -> String:
	# See `catalog_analysis_run.gd`'s `pick_measured_preset_id` for the rule.
	var profiles := _ensure_event_analysis_profiles()
	if profiles == null:
		return ""
	var analyzer := preload("res://tools/content_suite/catalog_analysis_run.gd").new()
	return analyzer.pick_measured_preset_id(_event_catalog, profiles, event_id, option_id)


func _selected_catalog_preset() -> Dictionary:
	var item := catalog_tree.get_selected()
	var event_id := str(item.get_metadata(0)) if item != null else ""
	if event_id.is_empty() or event_id != _catalog_preset_event_id or not _catalog_browser_rows.has(event_id):
		return {"ok": false, "error": "Select a catalog event and its current preset."}
	var index := catalog_preset_select.selected
	if catalog_preset_select.disabled or index < 0 or index >= catalog_preset_select.item_count:
		return {"ok": false, "error": "Select a current catalog preset; no automatic replacement was applied."}
	var preset_id := str(catalog_preset_select.get_item_metadata(index))
	if preset_id.is_empty():
		return {"ok": false, "error": "The selected catalog preset is missing."}
	var event := _event_catalog.get_event(event_id)
	for preset_value in event.get("presets", []):
		var preset: Dictionary = preset_value
		if str(preset.get("preset_id", "")) == preset_id:
			return {"ok": true, "event_id": event_id, "preset": preset.duplicate(true)}
	return {"ok": false, "error": "The selected preset is no longer in the current catalog."}


func _catalog_selected_play_request() -> Dictionary:
	var selected := _selected_catalog_preset()
	if not selected.get("ok", false):
		return selected
	var preset: Dictionary = selected.preset
	var option_id := ""
	if not catalog_result_select.disabled and catalog_result_select.selected >= 0:
		option_id = str(catalog_result_select.get_item_metadata(catalog_result_select.selected))
	var event := _event_catalog.get_event(str(selected.event_id))
	# EP-10 unit 3: a tool-seeded starting state is only offered for an
	# analysis-group ("Analyze route") row, and only while its guard passes
	# (the toggle is disabled otherwise) - the ordinary refusal of a
	# non-`original_branch` preset does not apply to it.
	if (
		event.has("analysis_group")
		and catalog_use_form_state != null
		and not catalog_use_form_state.disabled
		and catalog_use_form_state.button_pressed
	):
		var writes := KakyuEventGuardForm.writes(_catalog_guard_fields, _catalog_guard_field_values, preset.get("writes", []))
		var tool_preset := KakyuEventGuardForm.tool_seeded_preset("tool-seeded", writes)
		return _event_catalog.build_play_request(str(selected.event_id), str(preset.preset_id), option_id, tool_preset)
	if str(preset.get("kind", "")) != "original_branch":
		return {"ok": false, "error": "This preset is for analysis or remake-only use, not ordinary catalog playback."}
	return _event_catalog.build_play_request(str(selected.event_id), str(preset.preset_id), option_id)


func _on_catalog_preset_selected(_index: int) -> void:
	var selected := _selected_catalog_preset()
	if selected.get("ok", false):
		var preset: Dictionary = selected.preset
		catalog_preset_select.tooltip_text = "%s\n%s" % [str(preset.get("label", preset.preset_id)), str(preset.get("notes", ""))]
		_sync_catalog_state_form(str(selected.event_id))
	_refresh_catalog_event_details()


func _on_catalog_result_selected(_index: int) -> void:
	_maybe_repick_preset_for_result()
	_refresh_catalog_event_details()


func _on_catalog_use_form_state_toggled(_pressed: bool) -> void:
	_refresh_catalog_event_details()


func _maybe_repick_preset_for_result() -> void:
	# Round 9 code review, item 1: changing the Result re-picks the measured
	# preset for that option, unless the currently selected preset's named
	# variant already selects it (its own answer is one of several the same
	# variant measured).
	var item := catalog_tree.get_selected()
	var event_id := str(item.get_metadata(0)) if item != null else ""
	if event_id.is_empty() or event_id != _catalog_preset_event_id:
		return
	var event := _event_catalog.get_event(event_id)
	if not event.has("analysis_group"):
		return
	if catalog_result_select.disabled or catalog_result_select.selected < 0:
		return
	var option_id := str(catalog_result_select.get_item_metadata(catalog_result_select.selected))
	var probe_request := _event_catalog.build_play_request(event_id, "", option_id)
	var new_selection: Dictionary = probe_request.get("selection", {}) if probe_request.get("ok", false) else {}
	var selected := _selected_catalog_preset()
	var already_selects := false
	if selected.get("ok", false) and not new_selection.is_empty():
		var profiles := _ensure_event_analysis_profiles()
		if profiles != null:
			var preset: Dictionary = selected.preset
			var analyzer := preload("res://tools/content_suite/catalog_analysis_run.gd").new()
			var reference := analyzer.resolve_group_route_reference(event, str(preset.get("notes", "")), profiles)
			if not reference.is_empty():
				already_selects = analyzer._selections_contain(reference.variant, new_selection, reference.route)
	if already_selects:
		return
	var resolved_preset_id := _measured_group_route_preset_id(event_id, option_id)
	if resolved_preset_id.is_empty():
		return
	for index in range(catalog_preset_select.item_count):
		if str(catalog_preset_select.get_item_metadata(index)) == resolved_preset_id:
			catalog_preset_select.select(index)
			break


func _refresh_catalog_event_details() -> void:
	var item := catalog_tree.get_selected()
	var event_id := str(item.get_metadata(0)) if item != null else ""
	var row: Dictionary = _catalog_browser_rows.get(event_id, {})
	if row.is_empty():
		_clear_catalog_preset_selection()
		catalog_play_button.disabled = true
		catalog_select_source_button.disabled = true
		catalog_details.text = "Select a catalog event to inspect playback support."
		return
	var selected := _selected_catalog_preset()
	var preset: Dictionary = selected.get("preset", {})
	var blocker_lines: Array[String] = []
	for blocker in row.blockers:
		blocker_lines.append("- %s%s" % [str(blocker.summary), " [%s]" % str(blocker.todo_id) if not str(blocker.todo_id).is_empty() else ""])
	var compatibility: Dictionary = row.compatibility
	var request := _catalog_selected_play_request()
	var readiness := _catalog_play_readiness(request)
	var readiness_text := "Ready" if readiness.get("ok", false) else str(readiness.get("error", request.get("error", "Unavailable")))
	catalog_details.text = "%s\n%s\n\nPlayback: %s\nClassification: %s\nCharacters: %s\nDate tags: %s\nPlaces: %s\nEvent types: %s\nRecommended preset: %s\nSelected preset: %s\nPreset notes: %s\nPlay readiness: %s\nMaterial branches: %d | Choices: %d | Terminals: %d\nMedia compatibility: %s\nMES compatibility: %s\n\nBlockers / limitations:\n%s" % [
		str(row.title), str(row.event_id), str(row.playback_status), str(row.classification), KakyuEventPlayerRules.catalog_list_text(row.character_ids), KakyuEventPlayerRules.catalog_list_text(row.date_tags), KakyuEventPlayerRules.catalog_list_text(row.place_ids), KakyuEventPlayerRules.catalog_list_text(row.event_types), str(row.recommended_preset.get("label", "none cataloged")), str(preset.get("label", "none selected")), str(preset.get("notes", "none")), readiness_text, int(row.branch_count), int(row.choice_count), int(row.terminal_count), str(compatibility.get("media_replacements", "unspecified")), str(compatibility.get("mes_replacements", "unspecified")), "\n".join(blocker_lines) if not blocker_lines.is_empty() else "- none cataloged",
	]
	var event := _event_catalog.get_event(event_id)
	if event.has("analysis_group"):
		var group_ids: Array[String] = []
		for group_value in event.get("analysis_group", {}).get("groups", []):
			group_ids.append(str((group_value as Dictionary).get("group_id", "")))
		var option_id := str(request.get("selection", {}).get("option_id", ""))
		catalog_details.text += "\nGroup: %s\nResult: %s" % [", ".join(group_ids), option_id if not option_id.is_empty() else "none"]
		if readiness.get("ok", false):
			catalog_details.text += "\nRoute: %s\nVariant: %s (%s)" % [
				str((readiness.get("route", {}) as Dictionary).get("route_id", "")),
				str(readiness.get("variant_id", "")), str(readiness.get("variant_source", "")),
			]
		var request_preset: Dictionary = request.get("preset", {})
		if request_preset.has("base_preset_id"):
			catalog_details.text += "\nStarting state: tool-seeded (guard passes)"
		else:
			catalog_details.text += "\nStarting state: %s" % str(preset.get("preset_id", ""))
	var callee_name := str(event.get("source", {}).get("callee", {}).get("entry", ""))
	_sync_catalog_play_button_text()
	catalog_play_button.disabled = not readiness.get("ok", false)
	catalog_play_button.tooltip_text = readiness_text
	catalog_select_source_button.disabled = not _reader.is_open() or callee_name.is_empty() or _reader.get_entry(callee_name).is_empty()


## Round 2 code review, item 6: `_set_view_mode` needs only the button's
## text to follow the mode change - not the whole details/readiness
## refresh `_refresh_catalog_event_details` does (which re-derives the play
## request and re-validates readiness against the open archive on every
## mode toggle).
func _sync_catalog_play_button_text() -> void:
	var item := catalog_tree.get_selected()
	var event_id := str(item.get_metadata(0)) if item != null else ""
	if not _catalog_browser_rows.has(event_id):
		return
	var event := _event_catalog.get_event(event_id)
	if event.has("analysis_group"):
		# EP-10 unit 4: a promoted row's Play is a replay of the finished
		# `run_group_route`; the button reads "Play" in Playback and
		# "Analyze route" in Analysis, both through the public play/analyze
		# request methods.
		catalog_play_button.text = "Analyze route" if _view_mode == VIEW_MODE_ANALYSIS else "Play"
	else:
		catalog_play_button.text = "Play"


func _ensure_event_analysis_profiles() -> KakyuEventAnalysisProfiles:
	# Round 9 code review, item 4: a load failure is not cached - the next
	# call retries - and readiness reporting surfaces `load_dir`'s own error
	# text instead of silently proceeding with an empty profile set.
	if _event_analysis_profiles != null:
		return _event_analysis_profiles
	var candidate := KakyuEventAnalysisProfiles.new()
	var loaded := candidate.load_dir()
	if not loaded.get("ok", false):
		_event_analysis_profiles_error = str(loaded.get("error", "Analysis-group profile directory could not be loaded."))
		return null
	_event_analysis_profiles_error = ""
	_event_analysis_profiles = candidate
	return _event_analysis_profiles


func _catalog_play_readiness(request: Dictionary) -> Dictionary:
	if not request.get("ok", false):
		return {"ok": false, "error": str(request.get("error", "Catalog play request was rejected."))}
	if str(request.get("schema", "")) != ContentCoreVersionScript.EVENT_CATALOG_PLAY_REQUEST_SCHEMA:
		return {"ok": false, "error": "Catalog play request schema is unsupported."}
	if str(request.get("execution_model", "")) == "group_route":
		var profiles := _ensure_event_analysis_profiles()
		if profiles == null:
			return {"ok": false, "error": "Analysis-group profiles could not be loaded: %s" % _event_analysis_profiles_error}
		return preload("res://tools/content_suite/catalog_analysis_run.gd").new().readiness_group(_reader, _resolver, _event_catalog, profiles, request)
	return {"ok": false, "error": "Catalog play request execution model is unsupported."}


func _on_catalog_play_pressed() -> void:
	var request := _catalog_selected_play_request()
	var played := analyze_catalog_request(request) if _view_mode == VIEW_MODE_ANALYSIS else play_catalog_request(request)
	if not played.get("ok", false):
		catalog_details.text += "\n\nPlay rejected: %s" % str(played.get("error", "unknown error"))
		catalog_play_button.disabled = true


func _reject_non_original_document() -> bool:
	if str(_document.get("source", {}).get("resolved_source", "")) != "original_arc":
		status_label.text = "Event Player plays original content only."
		return true
	return false


func _play_catalog_request(request: Dictionary) -> Dictionary:
	if not request.get("ok", false):
		return {"ok": false, "error": str(request.get("error", "Catalog play request was rejected."))}
	if _event_catalog.get_event(str(request.get("event_id", ""))).has("analysis_group"):
		return _play_group_route(request)
	return {"ok": false, "error": "Catalog entry has no supported playback route."}


## Round 2 code review (owner, 2026-09-20): the shared prologue of
## `_analyze_group_route` and `_play_group_route` - resolve profiles, run
## `run_group_route`, re-check readiness, `_load_entry` the callee, the
## hash check, `_reject_non_original_document`, and the state/sync/clear
## calls every group-route session needs before it can replace the visible
## session - so the two only branch on the presentation.
func _prepare_group_route_session(request: Dictionary) -> Dictionary:
	var analyzer := preload("res://tools/content_suite/catalog_analysis_run.gd").new()
	var profiles := _ensure_event_analysis_profiles()
	if profiles == null:
		return {"ok": false, "error": "Analysis-group profiles could not be loaded: %s" % _event_analysis_profiles_error}
	var verified := analyzer.run_group_route(_reader, _resolver, _event_catalog, profiles, request)
	if not verified.get("ok", false):
		return verified
	# Resolve again after computation, before replacing the visible session.
	var current := analyzer.readiness_group(_reader, _resolver, _event_catalog, profiles, request)
	if not current.get("ok", false):
		return current
	var entry := str(request.callee.entry)
	_load_entry(entry)
	if not _document.get("ok", false) or str(_document.get("entry_sha256", "")) != str(request.callee.entry_sha256):
		return {"ok": false, "error": "The analysis entry changed during session preparation."}
	if _reject_non_original_document():
		return {"ok": false, "error": status_label.text}
	_state = verified.probe.state_object
	_sync_state_json()
	_sync_quick_state_fields()
	_clear_choice_projection()
	_clear_continuation()
	_clear_preview_route_identity()
	return {"ok": true, "verified": verified, "entry": entry}


func _analyze_group_route(request: Dictionary) -> Dictionary:
	var prepared := _prepare_group_route_session(request)
	if not prepared.get("ok", false):
		return prepared
	var verified: Dictionary = prepared.verified
	_set_view_mode(VIEW_MODE_ANALYSIS)
	var result := {"status": "catalog_group_route_complete", "offset": int(verified.terminal_match.get("offset", -1)),
		"trace": verified.probe.trace, "messages": verified.probe.messages, "state_diff": verified.probe.state_diff,
		"error": "Unbroken caller path through the shared call frame; native presentation omitted."}
	_show_result(result, int(request.callee.start_coordinate))
	_clear_continuation()
	_preview_event_complete = true
	catalog_window.hide()
	var preset_label := "tool-seeded state" if (request.get("preset", {}) as Dictionary).has("base_preset_id") else str(request.preset.preset_id)
	status_label.text = "Analysis complete · %s · %s · %s" % [
		str(request.event_id), preset_label,
		KakyuEventOutcomeVocabulary.phrase(KakyuEventOutcomeVocabulary.matched_terminal_outcome(verified.terminal_match, request.get("terminals", []))),
	]
	return {"ok": true, "event_id": str(request.event_id), "preset_id": str(request.preset.preset_id),
		"option_id": str(request.get("selection", {}).get("option_id", "")), "mode": "group_route", "status": result.status,
		"complete": true, "terminal_match": verified.terminal_match, "scope": verified.scope, "caller_executed": true,
		"native_presentation": "omitted", "message_count": verified.probe.messages.size(),
		"route_id": str(verified.route_id), "variant_id": str(verified.variant_id), "variant_source": str(verified.variant_source)}


## EP-10 unit 4: a promoted row's Play is a replay of the finished
## `run_group_route` result. Runs the route exactly as `_analyze_group_route`
## does (through `_prepare_group_route_session`), then turns the run's
## trace and messages into a presentation timeline and steps the Playback
## view through it instead of showing the Analysis trace/message trees.
func _play_group_route(request: Dictionary) -> Dictionary:
	var prepared := _prepare_group_route_session(request)
	if not prepared.get("ok", false):
		return prepared
	var verified: Dictionary = prepared.verified
	var entry: String = prepared.entry
	# EP-14: the media a shared library routine executed reach the timeline in
	# call order, anchored to the route row that called the routine.
	var timeline: Dictionary = TimelineScript.build(verified.probe.trace, verified.probe.messages, verified.terminal_match, verified.probe.library_media)
	if not timeline.get("ok", false):
		return timeline
	_set_view_mode(VIEW_MODE_PLAYBACK)
	# Round 2 code review, item 4: stop the effect channel (and every other
	# retained media status) explicitly before a new group-route session
	# replaces it, rather than relying only on `_load_entry`'s own reset.
	_clear_preview_media_state()
	_catalog_playback_request = request.duplicate(true)
	_catalog_playback_active = true
	_catalog_terminal_match = verified.terminal_match.duplicate(true)
	_catalog_terminal_rejected_completion = false
	# Round 2 code review, item 2: the run ended at its matched terminal
	# whatever its outcome - an `analysis_boundary` stage with an
	# unresolved outcome is a legitimate ending for a group route, not an
	# incomplete one, so completion does not depend on `route_ended`.
	_preview_event_complete = true
	_catalog_timeline_steps = timeline.steps
	_catalog_timeline_unclassified = (timeline.get("unclassified", []) as Array).duplicate()
	_preview_messages.clear()
	_preview_definitions.clear()
	for untyped_step in timeline.steps:
		var step: Dictionary = untyped_step
		if (step.get("messages", []) as Array).is_empty():
			continue
		var presentation := _resolve_step_presentation(step)
		presentation["source"] = "group route"
		presentation["_timeline_step_index"] = int(step.index)
		_preview_messages.append(presentation)
	_preview_message_index = -1
	_preview_result_status = str(verified.terminal_match.get("runtime_status", "catalog_group_route_complete"))
	_preview_result_offset = int(verified.terminal_match.get("offset", -1))
	_preview_completion_shown = false
	_preview_entry_label.text = "%s · group route replay" % entry
	catalog_window.hide()
	if not _preview_messages.is_empty():
		_preview_message_index = 0
		_apply_timeline_step(_catalog_timeline_steps[0], true)
		_show_preview_message()
	else:
		# Round 2 code review, item 1: a run with no message at all still
		# has a closing step (or an empty one); apply it through the same
		# path `_show_event_complete` uses for the ordinary case.
		_show_event_complete()
	var preset_label := "tool-seeded state" if (request.get("preset", {}) as Dictionary).has("base_preset_id") else str(request.preset.preset_id)
	var phrase := KakyuEventOutcomeVocabulary.phrase(KakyuEventOutcomeVocabulary.matched_terminal_outcome(verified.terminal_match, request.get("terminals", [])))
	status_label.text = "Play complete · %s · %s · %s" % [str(request.event_id), preset_label, phrase]
	# EP-13 part B: the step count is now pinned to the run's own
	# `dialogue_boundary` count (+ closing), independent of `timeline.steps`,
	# so a validator can check the timeline module's own arithmetic against
	# the source trace rather than against a number the same build derived.
	var dialogue_boundary_count := 0
	for untyped_row in verified.probe.trace:
		if str((untyped_row as Dictionary).get("effect", "")) == "dialogue_boundary":
			dialogue_boundary_count += 1
	return {"ok": true, "event_id": str(request.event_id), "preset_id": str(request.preset.preset_id),
		"option_id": str(request.get("selection", {}).get("option_id", "")), "mode": "group_route_play", "status": "catalog_group_route_play",
		"complete": true, "terminal_match": verified.terminal_match, "scope": verified.scope, "caller_executed": true,
		"native_presentation": "played", "message_count": verified.probe.messages.size(), "step_count": timeline.steps.size(),
		"dialogue_boundary_count": dialogue_boundary_count,
		"route_id": str(verified.route_id), "variant_id": str(verified.variant_id), "variant_source": str(verified.variant_source)}


## EP-13 part B: a step's displayed text is the concatenation of its
## records' own resolved presentations (`_resolve_message_presentation` per
## record) - `[<name>]line` reads as one line, and an unresolved protagonist
## name insert still shows its placeholder, exactly as `_resolve_message_presentation`
## already resolves it record by record. `text_parts` keeps the individual
## resolved strings for callers that want the per-record breakdown; the
## Analysis view's own per-record tables read `step.messages` directly and
## are unaffected by this presentation.
func _resolve_step_presentation(step: Dictionary) -> Dictionary:
	var records: Array = step.get("messages", [])
	var text_parts: Array[String] = []
	var tooltip_parts: Array[String] = []
	var first_presentation: Dictionary = {}
	for untyped_record in records:
		var presentation := _resolve_message_presentation(untyped_record as Dictionary)
		if first_presentation.is_empty():
			first_presentation = presentation
		text_parts.append(str(presentation.text))
		tooltip_parts.append(str(presentation.tooltip))
	return {
		"offset": int(first_presentation.get("offset", int(step.get("source_offset", -1)))),
		"source_entry": str(first_presentation.get("source_entry", step.get("source_entry", ""))),
		"source": str(first_presentation.get("source", "group route")),
		"text": "".join(text_parts),
		"text_parts": text_parts,
		"tooltip": "\n---\n".join(tooltip_parts),
	}


## Applies one presentation-timeline step's cumulative picture state
## (`step.visible`), presenting the background - then the foreground - only
## when each differs from what is actually on screen (`_preview_displayed_visible`,
## not the previous timeline step's `visible` - EP-13 part A: comparing
## against the previous *step* breaks stepping backwards, which applies the
## target step directly and would otherwise compare it against the step two
## behind it instead of what the target step is replacing). This is correct
## in either direction: a foreground shown several steps back and untouched
## since is not re-presented, and stepping backwards restores exactly what
## that line showed. `_present_mmo_resource` clears the foreground layer
## when it redraws the background surface, so a background change always
## re-presents the current foreground too, even when the foreground's own
## name did not change. When stepping forward, also plays the step's voice,
## BGM and effect requests. Stepping backwards applies pictures only (no
## sound), per the EP-10 unit 4 spec.
func _apply_timeline_step(step: Dictionary, forward: bool) -> void:
	var visible: Dictionary = step.get("visible", {})
	var background_name := str(visible.get("background", ""))
	var foreground_name := str(visible.get("foreground", ""))
	var displayed_background := str(_preview_displayed_visible.get("background", ""))
	var displayed_foreground := str(_preview_displayed_visible.get("foreground", ""))
	var background_changed := not background_name.is_empty() and background_name != displayed_background
	if background_changed:
		_present_mmo_resource(background_name, "group route")
	if not foreground_name.is_empty() and (background_changed or foreground_name != displayed_foreground):
		_present_mmo_foreground(foreground_name, "group route")
	_preview_displayed_visible = visible.duplicate()
	if not forward:
		return
	for untyped_bgm in step.get("bgm", []):
		var bgm: Dictionary = untyped_bgm
		_present_bgm_resource(str(bgm.get("resource_name", "")), int(bgm.get("selector", -1)))
	var voice_name := str(step.get("voice", ""))
	if not voice_name.is_empty():
		_present_voice_resource(voice_name)
	for untyped_effect in step.get("effects", []):
		var effect: Dictionary = untyped_effect
		_play_effect_resource(str(effect.get("resource_name", "")), str(effect.get("resource_archive", "")))


## Fire-and-forget effect playback for the group-route presentation
## timeline: no timing claims, an unresolved file is ignored in Playback (it
## is listed in the Analysis trace instead). Resolves the same way BGM and
## voice do (`_resolve_audio_payload` then `_event_audio_identity`) and
## plays on the shared `preview_effect_audio` effect channel (the same one
## EVENTB03's effect cues use), falling back to voice.arc/se.arc - the
## archives the content set exposes for sound effects - when the trace row
## carries no archive.
func _play_effect_resource(resource_name: String, resource_archive: String) -> void:
	if resource_name.is_empty() or not _content_set.is_open():
		return
	var preferred: Array[String] = []
	if not resource_archive.is_empty():
		preferred.append(resource_archive.to_lower())
	preferred.append("voice.arc")
	preferred.append("se.arc")
	var found := _content_set.find_entry(resource_name, preferred)
	if not found.get("ok", false):
		return
	var archive_name := str(found.archive)
	var resolved := _resolve_audio_payload(archive_name, resource_name)
	if not resolved.get("ok", false):
		return
	var audio_identity := _event_audio_identity(resolved)
	if not audio_identity.get("ok", false):
		return
	if KakyuEventPlayerRules.is_headless_display():
		_preview_effect_name = resource_name
		return
	var data: PackedByteArray = resolved.data
	var container := str((resolved.validation as Dictionary).get("container", "")).to_lower()
	var stream: AudioStream = (
		AudioStreamOggVorbis.load_from_buffer(data) if container == "ogg"
		else AudioStreamWAV.load_from_buffer(data)
	)
	if stream == null:
		return
	preview_effect_audio.stop()
	_preview_effect_name = resource_name
	_preview_effect_stream = stream
	preview_effect_audio.stream = stream
	preview_effect_audio.play()


func _catalog_preset_application(state: KakyuMesSandboxState, preset: Dictionary) -> Dictionary:
	var applied_writes: Array[Dictionary] = []
	for untyped_write in preset.get("writes", []):
		if not untyped_write is Dictionary:
			return {"ok": false, "error": "Catalog preset contains a non-record write."}
		var write: Dictionary = untyped_write
		var storage := str(write.get("storage", ""))
		var bank := int(write.get("bank", 0))
		var index := int(write.get("index", -1))
		var expected_value := int(write.get("value", 0))
		var actual_value := state.read_value(storage, index, bank)
		if actual_value != expected_value:
			return {
				"ok": false,
				"error": "Catalog preset writes conflict at %s[%d:0x%X]." % [storage, bank, index],
			}
		applied_writes.append({
			"storage": storage,
			"bank": bank,
			"index": index,
			"value": actual_value,
		})
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.EVENT_CATALOG_PRESET_APPLICATION_SCHEMA,
		"preset_id": str(preset.get("preset_id", "")),
		"writes": applied_writes,
	}


func _on_catalog_select_source_pressed() -> void:
	var item := catalog_tree.get_selected()
	if item == null or not _reader.is_open(): return
	var event := _event_catalog.get_event(str(item.get_metadata(0)))
	var entry_name := str(event.get("source", {}).get("callee", {}).get("entry", ""))
	if entry_name.is_empty() or _reader.get_entry(entry_name).is_empty():
		catalog_select_source_button.disabled = true
		return
	filter_edit.text = ""
	_load_entry(str(_reader.get_entry(entry_name).name))
	_set_view_mode(VIEW_MODE_ANALYSIS)
	catalog_window.hide()


func _apply_startup_arguments(arguments: PackedStringArray) -> void:
	var startup := _launch_context.activate(arguments)
	if not startup.ok:
		status_label.text = str(startup.error)
		return
	if startup.named:
		_open_content_set(_launch_context.get_content_set_root())
		if _reader.is_open():
			var run_request_path := _launch_context.get_run_request_path()
			if not run_request_path.is_empty():
				var consumed := _consume_run_request(
					run_request_path, _launch_context.get_interface_proof_path()
				)
				if not consumed.get("ok", false):
					status_label.text = "MES Editor Run rejected: %s" % str(consumed.error)
			var selection_path := _launch_context.get_selection_path()
			if not selection_path.is_empty():
				var selection_consumed := _consume_selection(selection_path)
				if not selection_consumed.get("ok", false):
					status_label.text = "Selection rejected: %s" % str(selection_consumed.error)
		return
	var legacy_arguments: PackedStringArray = startup.legacy_arguments
	if not legacy_arguments.is_empty():
		var startup_path := str(legacy_arguments[0])
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(startup_path)):
			_open_content_set(startup_path)
		else:
			_open_archive(startup_path)
	if legacy_arguments.size() > 1:
		status_label.text = "Event Player plays original content only; an overlay root is not accepted."
		return


func _consume_run_request(request_path: String, interface_proof_path := "") -> Dictionary:
	if not _launch_context.is_active() or not _reader.is_open():
		return {"ok": false, "error": "MES Editor Run requires the request's named workspace."}
	var request_value = JSON.parse_string(FileAccess.get_file_as_string(request_path))
	if not request_value is Dictionary:
		return {"ok": false, "error": "MES Editor Run request is not a JSON object."}
	var request: Dictionary = request_value
	var validator := MesEditorRunRequestScript.new()
	var workspace_check := validator.validate_for_workspace(
		request, _launch_context.get_snapshot()
	)
	if not workspace_check.get("ok", false):
		return {"ok": false, "error": str(workspace_check.error)}
	var interface_check := KakyuEventPlayerRules.validate_run_interface(request, str(interface_proof_path))
	if not interface_check.get("ok", false):
		return interface_check
	if (
		str(request.content.get("source", "")) != "original_arc"
		or str(request.interface.get("kind", "")) != "exact_original"
		or str(request.content.get("effective_entry_sha256", "")) != str(request.content.get("source_entry_sha256", ""))
	):
		return {"ok": false, "error": "Event Player runs original entries only; the request carries edited or overlaid content."}
	var content: Dictionary = request.content
	var archive_name := str(content.archive).to_lower()
	var source_entry_sha := _reader.get_entry_fingerprint(str(content.entry))
	if (
		archive_name != "mes.arc"
		or _reader.get_archive_fingerprint() != str(content.source_archive_sha256)
		or source_entry_sha != str(content.source_entry_sha256)
	):
		return {"ok": false, "error": "MES Editor Run original source identity changed."}
	var descriptor := _resolver.resolve(archive_name, str(content.entry))
	if not descriptor.get("ok", false):
		return {"ok": false, "error": str(descriptor.get("error", "Run entry could not be resolved."))}
	if str(descriptor.get("source", "")) != str(content.source):
		return {"ok": false, "error": "MES Editor Run effective source priority changed."}
	var effective_data := _resolver.read_resolved(descriptor)
	if effective_data.is_empty() and not _resolver.last_error.is_empty():
		return {"ok": false, "error": _resolver.last_error}
	var effective_sha := OverlayPackageScript.sha256_bytes(effective_data)
	var effective_check := validator.validate_effective(
		request, effective_sha, effective_data.size()
	)
	if not effective_check.get("ok", false):
		return {"ok": false, "error": str(effective_check.error)}
	var candidate_document := MesContainerScript.new().parse(effective_data, {
		"archive": archive_name,
		"entry": str(content.entry),
		"resolved_source": str(descriptor.source),
	})
	if (
		not candidate_document.get("ok", false)
		or str(candidate_document.get("entry_sha256", "")) != effective_sha
	):
		return {"ok": false, "error": "MES Editor Run effective entry could not be parsed exactly."}
	if str(request.launch.mode) == "catalog_event":
		var catalog_run := _build_catalog_run_play_request(
			request, _launch_context.get_snapshot()
		)
		if not catalog_run.get("ok", false):
			return catalog_run
		var played := _play_catalog_request(catalog_run.play_request)
		if not played.get("ok", false):
			return played
		return {
			"ok": true,
			"schema": ContentCoreVersionScript.MES_EDITOR_RUN_REQUEST_SCHEMA,
			"mode": "catalog_event",
			"entry": _selected_entry,
			"event_id": str(request.launch.event_id),
			"preset_id": str(request.launch.preset_id),
			"status": str(played.get("status", "")),
		}
	var start := KakyuEventPlayerRules.run_request_analysis_start(request.launch, candidate_document)
	if not start.get("ok", false):
		return start
	var candidate_state := SandboxStateScript.new(1)
	_apply_startup_calendar_state(candidate_state)
	var candidate_result := MesEventRunnerScript.new().run(
		candidate_document.bytecode,
		int(start.offset),
		candidate_state,
		int(candidate_document.header.code_size),
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{
			"protagonist_name": protagonist_name_edit.text,
			"address_table_offsets": candidate_document.header.entry_offsets.duplicate(),
		}
	)
	if not candidate_result is Dictionary or str(candidate_result.get("status", "")).is_empty():
		return {"ok": false, "error": "MES Editor Run did not reach a typed analysis result."}
	var refreshed := _launch_context.refresh()
	if not refreshed.get("ok", false):
		return refreshed
	var current_generation := validator.validate_for_workspace(request, _launch_context.get_snapshot())
	if not current_generation.get("ok", false):
		return current_generation
	_load_entry(str(content.entry))
	if (
		not _document.get("ok", false)
		or str(_document.get("entry_sha256", "")) != effective_sha
		or _selected_entry.to_upper() != str(content.entry).to_upper()
	):
		return {"ok": false, "error": "MES Editor Run entry changed during transactional commit."}
	_state = candidate_state
	_sync_state_json()
	_sync_quick_state_fields()
	_clear_choice_projection()
	_clear_continuation()
	_clear_preview_route_identity()
	intro_edit.text = "0x%X" % int(start.offset)
	_set_view_mode(VIEW_MODE_ANALYSIS)
	_show_result(candidate_result, int(start.offset))
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_EDITOR_RUN_REQUEST_SCHEMA,
		"mode": "analysis_entry",
		"entry": _selected_entry,
		"start_offset": int(start.offset),
		"status": str(candidate_result.status),
	}


func _consume_selection(path: String) -> Dictionary:
	if not _launch_context.is_active() or not _reader.is_open():
		return {"ok": false, "error": "A selection requires the named workspace's open content set."}
	var selection_contract := ContentSelectionScript.new()
	var read_result := selection_contract.read_path(path)
	if not read_result.get("ok", false):
		return {"ok": false, "error": str(read_result.get("error", "Selection could not be read."))}
	var document: Dictionary = read_result.document
	var validated := selection_contract.validate_for_workspace(document, _launch_context.get_snapshot())
	if not validated.get("ok", false):
		return {"ok": false, "error": str(validated.get("error", "Selection was rejected."))}
	var selection: Dictionary = document.selection
	if str(selection.archive).to_lower() != "mes.arc":
		return {"ok": false, "error": "Event Player selections must name mes.arc; it plays original entries only."}
	var entry_name := str(selection.entry)
	var entry := _reader.get_entry(entry_name)
	if entry.is_empty() or _reader.get_entry_fingerprint(entry_name) != str(selection.source_entry_sha256):
		return {"ok": false, "error": "Selection names a changed or unknown original entry."}
	_load_entry(entry_name)
	_set_view_mode(VIEW_MODE_ANALYSIS)
	var event_id := str(selection.event_id)
	var preset_id := str(selection.preset_id)
	if not event_id.is_empty():
		if _event_catalog.get_summary().is_empty():
			return {"ok": false, "error": "Selection names a catalog event, but the Event Catalog is not loaded."}
		var event := _event_catalog.get_event(event_id)
		var callee_entry := str(event.get("source", {}).get("callee", {}).get("entry", "")).to_upper()
		if event.is_empty() or callee_entry != entry_name.to_upper():
			return {"ok": false, "error": "Selection names an event whose callee does not match its entry."}
		_open_catalog_window_for_selection(event_id, preset_id)
	var producer_app := str(document.producer.app)
	var event_suffix := " · event %s" % event_id if not event_id.is_empty() else ""
	status_label.text = "Selection from %s: %s%s" % [producer_app, entry_name, event_suffix]
	return {"ok": true, "entry": entry_name, "event_id": event_id, "preset_id": preset_id}


func _open_catalog_window_for_selection(event_id: String, preset_id: String) -> void:
	var root := catalog_tree.get_root()
	var item := root.get_first_child() if root != null else null
	while item != null:
		if str(item.get_metadata(0)) == event_id:
			item.select(0)
			break
		item = item.get_next()
	_on_catalog_event_selected()
	if not preset_id.is_empty():
		for index in range(catalog_preset_select.item_count):
			if str(catalog_preset_select.get_item_metadata(index)) == preset_id:
				catalog_preset_select.select(index)
				_on_catalog_preset_selected(index)
				break
	catalog_window.popup_centered(Vector2i(1050, 700))


func _build_catalog_run_play_request(
	request: Dictionary, workspace_snapshot: Dictionary
) -> Dictionary:
	var launch: Dictionary = request.get("launch", {})
	var content: Dictionary = request.get("content", {})
	var summary := _event_catalog.get_summary()
	if (
		str(launch.get("mode", "")) != "catalog_event"
		or str(summary.get("catalog_id", "")) != str(launch.get("catalog_id", ""))
	):
		return {"ok": false, "error": "MES Editor Run Event Catalog identity changed."}
	var preset_source := str(launch.preset_source)
	var play_request: Dictionary
	if preset_source == "catalog":
		play_request = _event_catalog.build_play_request(
			str(launch.event_id), str(launch.preset_id)
		)
	else:
		var project_preset := KakyuEventPlayerRules.project_run_preset(
			workspace_snapshot, str(launch.event_id), str(launch.preset_id)
		)
		if project_preset.is_empty():
			return {"ok": false, "error": "MES Editor Run project preset changed."}
		var base_preset_id := str(project_preset.get("catalog_preset_id", ""))
		play_request = _event_catalog.build_play_request(
			str(launch.event_id), base_preset_id
		)
		if play_request.get("ok", false):
			play_request["preset"] = {
				"preset_id": str(project_preset.preset_id),
				"label": str(project_preset.label),
				"kind": str(project_preset.kind),
				"writes": project_preset.get("writes", []).duplicate(true),
				"expected_branch_ids": [],
				"notes": "Workspace project preset; validated outside the path-free Run request.",
			}
	if not play_request.get("ok", false):
		return {"ok": false, "error": str(play_request.get("error", "Catalog preset is unavailable."))}
	var callee: Dictionary = play_request.get("callee", {})
	if (
		str(callee.get("archive", "")).to_lower() != str(content.get("archive", "")).to_lower()
		or str(callee.get("entry", "")).to_upper() != str(content.get("entry", "")).to_upper()
		or str(callee.get("entry_sha256", "")) != str(content.get("effective_entry_sha256", ""))
	):
		return {"ok": false, "error": "MES Editor Run catalog callee binding changed."}
	return {"ok": true, "play_request": play_request}


func _on_open_pressed() -> void:
	_path_history.apply_source_dialog(open_dialog)
	open_dialog.popup_centered_ratio(0.75)


func _on_content_set_pressed() -> void:
	_path_history.apply_elfimage_dialog(content_set_dialog)
	content_set_dialog.popup_centered_ratio(0.75)


func _on_content_set_selected(path: String) -> void:
	_open_content_set(path)


func _on_archive_selected(path: String) -> void:
	_open_archive(path)


func _open_archive(path: String) -> void:
	_close_source()
	_reset_source_view()
	_reader = ArcReaderScript.new()
	if not _reader.open(path):
		status_label.text = _reader.last_error
		return
	_path_history.remember_source_path(_reader.archive_path)
	_path_history.apply_source_dialog(open_dialog)
	_index_open_mes_archive(path, path, "Standalone mes.arc opened read-only")
	if _reader.is_open():
		_activate_original_resolver()


func _open_content_set(path: String) -> void:
	_close_source()
	_reset_source_view()
	if not _content_set.open(path):
		status_label.text = _content_set.last_error
		return
	_reader = _content_set.get_reader("mes.arc")
	var summary: Dictionary = _content_set.get_summary()
	var warning_text := ""
	if not summary.warnings.is_empty():
		warning_text = "; %d optional archive(s) unavailable" % summary.warnings.size()
	_index_open_mes_archive(
		str(_reader.archive_path),
		"ELFIMAGE · %d ARC" % int(summary.archive_count),
		"Content set opened read-only%s" % warning_text
	)
	for archive_name in _content_set.get_archive_names():
		if archive_name == "mes.arc":
			continue
		var content_reader: KakyuArcReader = _content_set.get_reader(archive_name)
		if not _resolver.register_original_archive(archive_name, str(content_reader.archive_path)):
			status_label.text = "Content resolver rejected %s: %s" % [archive_name, _resolver.last_error]
			return
		if not _remember_source_archive(archive_name, str(content_reader.archive_path)):
			status_label.text = "Could not fingerprint content-set archive: %s" % archive_name
			return
	_path_history.remember_elfimage(path)
	_path_history.apply_elfimage_dialog(content_set_dialog)
	if _reader.is_open():
		_activate_original_resolver()


func _reset_source_view() -> void:
	_catalog_playback_active = false
	_catalog_playback_autodriving = false
	_catalog_playback_request.clear()
	_catalog_terminal_match.clear()
	_catalog_terminal_rejected_completion = false
	_state.clear_native_relative_u8_layout()
	_clear_continuation()
	_entries.clear()
	_document.clear()
	_library_index.clear()
	_library_document.clear()
	_startup_context.clear()
	_source_archive_paths.clear()
	_source_archive_sha256.clear()
	_selected_entry = ""
	entry_tree.clear()
	address_tree.clear()
	trace_tree.clear()
	message_tree.clear()
	state_diff_tree.clear()
	script_call_tree.clear()
	shared_routine_tree.clear()
	output.text = ""
	_reset_game_preview()


func _index_open_mes_archive(path: String, display_name: String, source_status: String) -> void:
	var archive_name := path.replace("\\", "/").get_file()
	if not _resolver.register_original_archive(archive_name, path):
		status_label.text = _resolver.last_error
		_close_source()
		return
	if not _remember_source_archive(archive_name, path):
		status_label.text = "Could not fingerprint the opened MES archive."
		_close_source()
		return
	_reload_library_index(archive_name)
	if not _text_cache_root.is_empty():
		_configure_text_cache(_text_cache_root)
	for entry in _reader.get_entries():
		var extension := str(entry.name).get_extension().to_lower()
		if extension == "mes" or extension == "lib":
			_entries.append(entry)
	archive_label.text = display_name
	_rebuild_entry_tree()
	status_label.text = "%s; %d MES/LIB entries%s" % [
		source_status,
		_entries.size(),
		_startup_context_status_suffix(),
	]


func _remember_source_archive(archive_name: String, path: String) -> bool:
	var fingerprint := FileAccess.get_sha256(path)
	if fingerprint.is_empty():
		return false
	var key := archive_name.to_lower()
	_source_archive_paths[key] = ProjectSettings.globalize_path(path).simplify_path()
	_source_archive_sha256[key] = fingerprint
	return true


func _reload_library_index(archive_name: String) -> void:
	_library_index.clear()
	_library_document.clear()
	_startup_context.clear()
	var descriptor := _resolver.resolve(archive_name, "LIBLARY.LIB")
	if not descriptor.ok:
		return
	var data := _resolver.read_resolved(descriptor)
	if data.is_empty() and not _resolver.last_error.is_empty():
		return
	var document := MesContainerScript.new().parse(data, {
		"archive": archive_name,
		"entry": "LIBLARY.LIB",
		"resolved_source": descriptor.source,
	})
	if not document.ok or int(document.header.entry_count) != 0:
		return
	var index := MesLibraryIndexScript.new().build(document.bytecode, int(document.header.code_size))
	if not index.ok:
		return
	index["source"] = str(descriptor.source)
	index["entry_sha256"] = str(document.entry_sha256)
	_library_index = index
	_library_document = document
	_reload_startup_context(archive_name)


func _reload_startup_context(archive_name: String) -> void:
	_startup_context.clear()
	_state.clear_native_relative_u8_layout()
	if (
		not _reader.is_open()
		or _reader.get_archive_identity_fingerprint() != KakyuEventPlayerEvidence.AUDITED_MES_ARCHIVE_SHA256
		or str(_library_index.get("source", "")) != "original_arc"
		or not _is_catalog_source_entry(str(_library_index.get("entry_sha256", "")), "LIBLARY.LIB")
	):
		return
	var start_descriptor := _resolver.resolve(archive_name, "START.MES")
	var definition_descriptor := _resolver.resolve(archive_name, "DEF_MAIN.MES")
	if (
		not start_descriptor.get("ok", false)
		or str(start_descriptor.get("source", "")) != "original_arc"
		or not definition_descriptor.get("ok", false)
		or str(definition_descriptor.get("source", "")) != "original_arc"
	):
		return
	var start_data := _resolver.read_resolved(start_descriptor)
	if start_data.is_empty() and not _resolver.last_error.is_empty():
		return
	var definition_data := _resolver.read_resolved(definition_descriptor)
	if definition_data.is_empty() and not _resolver.last_error.is_empty():
		return
	var start_document := _parser.parse(start_data, {
		"archive": archive_name,
		"entry": "START.MES",
		"resolved_source": start_descriptor.source,
	})
	var definition_document := _parser.parse(definition_data, {
		"archive": archive_name,
		"entry": "DEF_MAIN.MES",
		"resolved_source": definition_descriptor.source,
	})
	if (
		not start_document.get("ok", false)
		or str(start_document.get("entry_sha256", "")) != AUDITED_START_ENTRY_SHA256
		or not definition_document.get("ok", false)
		or not _is_catalog_source_entry(str(definition_document.get("entry_sha256", "")), "DEF_MAIN.MES")
		or not KakyuEventPlayerRules.matches_audited_startup_execution(start_document)
	):
		return
	var projection := MesStartupContextScript.new().build(definition_document)
	var calendar_projection := MesCalendarStateScript.new().build(start_document)
	if (
		not projection.get("ok", false)
		or str(projection.get("schema", "")) != ContentCoreVersionScript.MES_STARTUP_CONTEXT_SCHEMA
		or projection.get("selector_order", []) != KakyuEventPlayerEvidence.AUDITED_STARTUP_CONTEXT_SELECTORS
		or int(projection.get("registration_count", 0)) != KakyuEventPlayerEvidence.AUDITED_STARTUP_CONTEXT_SELECTORS.size()
		or not (projection.get("registered_definitions", {}) as Dictionary).has(26)
		or not calendar_projection.get("ok", false)
		or str(calendar_projection.get("schema", "")) != ContentCoreVersionScript.MES_CALENDAR_STATE_SCHEMA
		or str(calendar_projection.get("table_sha256", "")) != AUDITED_CALENDAR_TABLE_SHA256
	):
		return
	projection["source"] = "original_arc"
	projection["startup_entry"] = "START.MES"
	projection["startup_entry_sha256"] = str(start_document.entry_sha256)
	projection["library_entry"] = "LIBLARY.LIB"
	projection["library_entry_sha256"] = str(_library_index.entry_sha256)
	projection["calendar_state"] = calendar_projection
	_startup_context = projection
	_apply_startup_calendar_state(_state)


func _apply_startup_calendar_state(state: KakyuMesSandboxState) -> bool:
	var calendar_projection: Dictionary = _startup_context.get("calendar_state", {})
	if (
		calendar_projection.is_empty()
		or str(calendar_projection.get("schema", "")) != ContentCoreVersionScript.MES_CALENDAR_STATE_SCHEMA
		or str(calendar_projection.get("table_sha256", "")) != AUDITED_CALENDAR_TABLE_SHA256
	):
		state.clear_native_relative_u8_layout()
		return false
	return bool(MesCalendarStateScript.new().apply_to_state(calendar_projection, state).get("ok", false))


func _startup_context_status_suffix() -> String:
	if _startup_context.is_empty():
		return ""
	var calendar_suffix := "; calendar state active" if _state.native_relative_u8_aliases_enabled() else ""
	return "; startup context %d indexed read-only%s" % [int(_startup_context.get("registration_count", 0)), calendar_suffix]


func _close_source() -> void:
	_resolver.close()
	if _reader != null:
		_reader.close()
	_content_set.close()
	_source_archive_paths.clear()
	_source_archive_sha256.clear()


func _exit_tree() -> void:
	if is_instance_valid(preview_audio):
		preview_audio.stop()
		preview_audio.stream = null
	if is_instance_valid(preview_effect_audio):
		preview_effect_audio.stop()
		preview_effect_audio.stream = null
	if is_instance_valid(preview_voice):
		preview_voice.stop()
		preview_voice.stream = null
	_preview_bgm_stream = null
	_preview_effect_stream = null
	_preview_voice_stream = null
	_launch_context.close()
	_close_source()


func _activate_original_resolver() -> bool:
	var prepared := _prepare_original_resolver_candidate()
	if not prepared.ok:
		status_label.text = "Original resolver activation rejected: %s" % str(prepared.error)
		return false
	var previous_resolver := _resolver
	_resolver = prepared.resolver
	previous_resolver.close()
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	_reload_library_index(archive_name)
	if not _selected_entry.is_empty():
		_load_entry(_selected_entry)
	return true


func _prepare_original_resolver_candidate() -> Dictionary:
	if not _reader.is_open() or _source_archive_paths.is_empty():
		return {"ok": false, "error": "Open mes.arc or an ELFIMAGE content set before preparing content layers."}
	var candidate := ContentResolverScript.new()
	var registered := _register_resolver_source_layers(candidate)
	if not registered.ok:
		candidate.close()
		return registered
	if not _selected_entry.is_empty():
		var mes_archive_name := _reader.archive_path.replace("\\", "/").get_file()
		var selected_descriptor := candidate.resolve(mes_archive_name, _selected_entry)
		if not selected_descriptor.get("ok", false):
			candidate.close()
			return {"ok": false, "error": str(selected_descriptor.get("error", "MES content could not be resolved."))}
		var selected_data := candidate.read_resolved(selected_descriptor)
		if selected_data.is_empty() and not candidate.last_error.is_empty():
			candidate.close()
			return {"ok": false, "error": candidate.last_error}
		var selected_parsed := _parser.parse(selected_data, {
			"archive": str(selected_descriptor.archive),
			"entry": str(selected_descriptor.entry),
			"resolved_source": str(selected_descriptor.source),
		})
		if not selected_parsed.ok:
			candidate.close()
			return {"ok": false, "error": "Original MES/LIB entry could not be parsed: %s" % str(selected_parsed.error)}
	return {
		"ok": true,
		"resolver": candidate,
		"archive_count": _source_archive_paths.size(),
	}


func _register_resolver_source_layers(candidate: KakyuContentResolver) -> Dictionary:
	for archive_name in _source_archive_paths:
		var archive_path := str(_source_archive_paths[archive_name])
		if not candidate.register_original_archive(archive_name, archive_path):
			return {"ok": false, "error": candidate.last_error}
		if FileAccess.get_sha256(archive_path) != str(_source_archive_sha256.get(archive_name, "")):
			return {"ok": false, "error": "Open source ARC changed before resolver activation: %s" % archive_name}
	return {"ok": true}


func _on_text_cache_pressed() -> void:
	text_cache_dialog.popup_centered_ratio(0.75)


func _on_text_cache_selected(path: String) -> void:
	_configure_text_cache(path)


func _configure_text_cache(path: String) -> void:
	if not _reader.is_open():
		status_label.text = "Open mes.arc before choosing its text cache."
		return
	if not _text_cache.configure(path, _reader.get_archive_fingerprint()):
		status_label.text = "Text cache rejected: %s" % _text_cache.last_error
		return
	_text_cache_root = path
	status_label.text = "Versioned UTF-8 text cache active."
	if not _selected_entry.is_empty():
		_load_entry(_selected_entry)


func _on_filter_changed(_value: String) -> void:
	_rebuild_entry_tree()


func _rebuild_entry_tree() -> void:
	entry_tree.clear()
	var root := entry_tree.create_item()
	var filter := filter_edit.text.strip_edges().to_upper()
	for entry in _entries:
		if not filter.is_empty() and not str(entry.name).to_upper().contains(filter):
			continue
		var item := entry_tree.create_item(root)
		item.set_text(0, str(entry.name))
		item.set_text(1, str(entry.size))
		item.set_metadata(0, entry.name)


func _on_entry_selected() -> void:
	var item := entry_tree.get_selected()
	if item != null:
		_load_entry(str(item.get_metadata(0)))


func _load_entry(entry_name: String, preserve_preview_session := false) -> void:
	if not preserve_preview_session:
		_catalog_playback_active = false
		_catalog_playback_request.clear()
	_clear_continuation()
	_selected_entry = entry_name
	_active_address_catalog.clear()
	_catalog_fragment_summaries.clear()
	_source_row_summaries.clear()
	_text_messages.clear()
	_document.clear()
	_sync_event_start_button()
	_sync_catalog_preview_button()
	address_tree.clear()
	trace_tree.clear()
	message_tree.clear()
	state_diff_tree.clear()
	script_call_tree.clear()
	shared_routine_tree.clear()
	output.text = "Select an intro and run until a safe boundary."
	if not preserve_preview_session:
		_reset_game_preview(entry_name)
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	var descriptor := _resolver.resolve(archive_name, entry_name)
	if not descriptor.ok:
		status_label.text = str(descriptor.error)
		return
	var data := _resolver.read_resolved(descriptor)
	if data.is_empty() and not _resolver.last_error.is_empty():
		status_label.text = _resolver.last_error
		return
	_document = _parser.parse(data, {
		"archive": archive_name,
		"entry": entry_name,
		"resolved_source": descriptor.source,
	})
	if not _document.ok:
		status_label.text = str(_document.error)
		return
	if not _text_cache_root.is_empty():
		var cached := _text_cache.load_entry(entry_name, str(_document.entry_sha256))
		if cached.ok:
			_text_messages = cached.messages
	var catalog_definition := _confirmed_address_catalog(entry_name, str(_document.entry_sha256))
	if not catalog_definition.is_empty():
		_active_address_catalog = catalog_definition
		_active_address_catalog.merge(_validate_address_catalog_source(catalog_definition), true)
		if _active_address_catalog.get("ok", false):
			_catalog_fragment_summaries = _build_catalog_fragment_summaries()
	var root := address_tree.create_item()
	for anchor in _confirmed_preview_anchors(entry_name, str(_document.entry_sha256)):
		if int(anchor.offset) < int(_document.header.code_size):
			_add_preview_anchor(root, str(anchor.label), int(anchor.offset))
	var bootstrap: Dictionary = _document.bootstrap
	if int(bootstrap.size) > 0:
		_add_address(root, "container bootstrap", 0, int(bootstrap.end_offset), "bootstrap")
	for entry in _document.entries:
		var entry_index := int(entry.index)
		var label := "#%04d" % entry_index
		var kind := "address_entry"
		if _active_address_catalog.get("ok", false):
			label = "Catalog setup #0000" if entry_index == 0 else "Fragment #%04d" % entry_index
			kind = "catalog_setup" if entry_index == 0 else "catalog_fragment"
		var address_item := _add_address(root, label, int(entry.offset), int(entry.end_offset), kind, entry_index)
		if kind == "catalog_fragment" and _catalog_fragment_summaries.has(entry_index):
			var fragment_summary: Dictionary = _catalog_fragment_summaries[entry_index]
			address_item.set_text(2, "%d · %s" % [
				int(entry.end_offset) - int(entry.offset),
				str(fragment_summary.display),
			])
			address_item.set_tooltip_text(2, str(fragment_summary.tooltip))
	var first := root.get_first_child()
	while first != null and not first.is_selectable(0):
		first = first.get_next()
	if first != null:
		first.select(0)
		intro_edit.text = "0x%X" % int(first.get_metadata(0))
	if _active_address_catalog.get("ok", false):
		status_label.text = (
			"%s loaded as a verified %d-fragment catalog; select a Fragment row to preview; %s"
		) % [entry_name, int(_active_address_catalog.fragment_count), _catalog_selection_note()]
	elif not catalog_definition.is_empty():
		status_label.text = "%s catalog validation failed: %s" % [
			entry_name,
			str(_active_address_catalog.get("error", "source mismatch")),
		]
	else:
		status_label.text = "%s loaded from %s; gameplay saves are isolated%s" % [
			entry_name,
			descriptor.source,
			_startup_context_status_suffix(),
		]
	_sync_event_start_button()
	_sync_catalog_preview_button()
	_sync_promise_location_fields()


func _add_address(
	root: TreeItem,
	label: String,
	offset: int,
	end_offset: int,
	kind := "address_entry",
	entry_index := -1
) -> TreeItem:
	var item := address_tree.create_item(root)
	item.set_text(0, label)
	item.set_text(1, "0x%08X" % offset)
	item.set_text(2, str(end_offset - offset))
	item.set_metadata(0, offset)
	item.set_metadata(1, kind)
	item.set_metadata(2, entry_index)
	if kind == "catalog_fragment":
		item.set_tooltip_text(0, "Verified original address-table fragment; native host selection order is unresolved.")
	elif kind == "catalog_setup":
		if str(_active_address_catalog.get("setup_start_kind", "")) == "audited_nested_call":
			item.set_tooltip_text(0, (
				"Verified original zero-coordinate event bootstrap; reaches confirmed dialogue and a DEF choice."
				if bool(_active_address_catalog.get("setup_reaches_event_choice", false))
				else "Verified target of the original zero-coordinate nested call; catalog setup only, not a selected event fragment."
			))
		else:
			item.set_tooltip_text(0, "Verified source-table setup entry for isolated analysis; native fragment selection and order remain unresolved; host activation remains unresolved.")
	elif kind == "address_entry":
		item.set_tooltip_text(0, "Original address-table row; previewing it is explicit tool input, not a confirmed native event order.")
	return item


func _add_preview_anchor(root: TreeItem, label: String, offset: int) -> void:
	var item := address_tree.create_item(root)
	item.set_text(0, "Confirmed: %s" % label)
	item.set_text(1, "0x%08X" % offset)
	item.set_text(2, "verified")
	item.set_tooltip_text(0, "Hash-bound original-source preview anchor; not a complete event entry point.")
	item.set_metadata(0, offset)
	item.set_metadata(1, "confirmed_anchor")
	item.set_metadata(2, -1)


func _confirmed_preview_anchors(entry_name: String, entry_sha256: String) -> Array:
	var normalized_entry := entry_name.to_upper()
	var promise_route: Dictionary = PROMISE_DATE_ROUTE_DEFINITIONS.get(normalized_entry, {})
	if (
		not promise_route.is_empty()
		and str(promise_route.entry_sha256) == entry_sha256.to_lower()
	):
		var anchor := {
			"label": "%s isolated scheduling route" % normalized_entry.get_basename(),
			"offset": int(promise_route.intro),
			"event_start_kind": PROMISE_DATE_ROUTE_KIND,
			"boundary": int(promise_route.boundary),
			"resume": int(promise_route.resume),
			"writer": int(promise_route.writer),
			"field": int(promise_route.field),
			"choice_boundary": int(promise_route.choice_boundary),
			"choice_resume": int(promise_route.choice_resume),
			"location_field": int(promise_route.location_field),
		}
		if promise_route.has("date_suffix_rows"):
			anchor["date_suffix_rows"] = int(promise_route.date_suffix_rows)
		if promise_route.has("validation_mode"):
			anchor["validation_mode"] = str(promise_route.validation_mode)
			anchor["validation_dialogues"] = int(promise_route.validation_dialogues)
		return [anchor]
	var definition: Dictionary = CONFIRMED_PREVIEW_ANCHORS.get(normalized_entry, {})
	if definition.is_empty():
		return []
	var anchors: Array = definition.anchors.duplicate(true)
	if str(definition.get("source", "")) != KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY:
		if str(definition.entry_sha256) != entry_sha256.to_lower():
			return []
		return anchors
	# A cataloged event's hash and start coordinate answer to the catalog, so an
	# unloaded catalog offers no anchor rather than a stale one.
	var callee := _event_catalog.find_callee_source(normalized_entry)
	if callee.is_empty():
		# Not a cataloged callee. The catalog still records this entry's own
		# identity as some event's required entry, and its anchors keep the
		# internal coordinates the catalog does not hold.
		var identity := _event_catalog.find_source_entry(normalized_entry)
		if identity.is_empty() or str(identity.entry_sha256) != entry_sha256.to_lower():
			return []
		return _catalog_sourced_anchors(anchors)
	if str(callee.entry_sha256) != entry_sha256.to_lower():
		return []
	for untyped_anchor in anchors:
		var anchor: Dictionary = untyped_anchor
		anchor["offset"] = int(callee.start_coordinate)
	return _catalog_sourced_anchors(anchors)


func _catalog_sourced_anchors(anchors: Array) -> Array:
	# An anchor may name a shared original entry the catalog records. Its hash
	# is written as `KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY` in the table so no frozen copy sits
	# beside the catalog's, and an unresolvable name yields no anchor at all.
	for untyped_anchor in anchors:
		var anchor: Dictionary = untyped_anchor
		if str(anchor.get("prelude_bgm_entry_sha256", "")) != KakyuEventPlayerEvidence.CATALOG_SOURCED_ENTRY:
			continue
		var expected := _catalog_source_entry_sha256(str(anchor.get("prelude_bgm_entry", "")))
		if expected.is_empty():
			return []
		anchor["prelude_bgm_entry_sha256"] = expected
	return anchors


func _confirmed_address_catalog(entry_name: String, entry_sha256: String) -> Dictionary:
	return _evidence().confirmed_address_catalog(entry_name, entry_sha256)


func _catalog_selection_note() -> String:
	if bool(_active_address_catalog.get("setup_reaches_event_choice", false)):
		return "confirmed zero-start event reaches original dialogue and choice; separate fragment host order remains unresolved"
	if (
		int(_active_address_catalog.get("nested_start_coordinate", -1)) == 0
		and int(_active_address_catalog.get("bootstrap_entry_index", -1)) == 0
	):
		return "original nested call reaches Catalog setup only; fragment selection/order remain unresolved"
	if str(_active_address_catalog.get("setup_start_kind", "")) == "source_table_entry":
		return "Catalog setup entry is inspectable; host activation and fragment selection/order remain unresolved"
	return "native host selection remains unresolved"


func _build_catalog_fragment_summaries() -> Dictionary:
	var summaries := {}
	var entries: Array = _document.get("entries", [])
	var table_offsets := _active_address_table_offsets()
	for entry_index in range(1, entries.size()):
		var entry: Dictionary = entries[entry_index]
		summaries[entry_index] = _build_source_row_summary(entry, table_offsets)
	return summaries


func _active_address_table_offsets() -> Array[int]:
	var table_offsets: Array[int] = []
	for untyped_offset in _document.get("header", {}).get("entry_offsets", []):
		table_offsets.append(int(untyped_offset))
	return table_offsets


func _build_source_row_summary(entry: Dictionary, table_offsets := []) -> Dictionary:
	var active_offsets: Array = table_offsets
	if active_offsets.is_empty():
		active_offsets = _active_address_table_offsets()
	var result := _runner.run(
		_document.bytecode,
		int(entry.get("offset", -1)),
		SandboxStateScript.new(1),
		int(_document.get("header", {}).get("code_size", -1)),
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{"address_table_offsets": active_offsets}
	)
	var status := str(result.get("status", "unknown"))
	var message_count := (result.get("messages", []) as Array).size()
	var definition_count := (result.get("definitions", []) as Array).size()
	var content_kinds: Array[String] = []
	if message_count > 0:
		content_kinds.append("dialogue")
	if definition_count > 0:
		content_kinds.append("DEF")
	if status == "native_presentation_boundary":
		content_kinds.append("native FX")
	var display_parts: Array[String] = []
	if message_count > 0:
		display_parts.append("%d msg" % message_count)
	if definition_count > 0:
		display_parts.append("%d DEF" % definition_count)
	var display := " / ".join(display_parts)
	if display.is_empty():
		display = status.replace("_", " ")
		match status:
			"native_presentation_boundary":
				display = "native FX"
			"script_return":
				display = "return"
	var state_diff_count := (result.get("state_diff", []) as Array).size()
	return {
		"status": status,
		"message_count": message_count,
		"definition_count": definition_count,
		"state_diff_count": state_diff_count,
		"content_kinds": content_kinds,
		"meaningful": not content_kinds.is_empty(),
		"display": display,
		"tooltip": (
			"First isolated stop: %s\nMessages reached: %d\nDEF rows reached: %d\n"
			+ "Sandbox changes: %d\nSource-table order only; native host selection is unresolved."
		) % [status, message_count, definition_count, state_diff_count],
	}


func _validate_address_catalog_source(definition: Dictionary) -> Dictionary:
	if not _reader.is_open() or _reader.get_archive_identity_fingerprint() != KakyuEventPlayerEvidence.AUDITED_MES_ARCHIVE_SHA256:
		return {"ok": false, "error": "authoritative mes.arc hash does not match"}
	var target_entry := _selected_entry.to_upper()
	var caller_entry := str(definition.get("caller_entry", "")).to_upper()
	var expected_entry_hash := str(definition.get("entry_sha256", ""))
	var expected_caller_hash := str(definition.get("caller_sha256", ""))
	if (
		str(_document.get("entry_sha256", "")) != expected_entry_hash
		or _reader.get_entry_fingerprint(target_entry) != expected_entry_hash
		or _reader.get_entry_fingerprint(caller_entry) != expected_caller_hash
	):
		return {"ok": false, "error": "catalog or caller entry hash does not match"}
	if int(_document.get("header", {}).get("entry_count", -1)) != int(definition.get("entry_count", -1)):
		return {"ok": false, "error": "catalog address-table count changed"}
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	for required_entry in [target_entry, caller_entry]:
		var descriptor := _resolver.resolve(archive_name, required_entry)
		if not descriptor.get("ok", false) or str(descriptor.get("source", "")) != "original_arc":
			return {"ok": false, "error": "%s must resolve from the audited original ARC" % required_entry}
		var expected_hash := expected_entry_hash if required_entry == target_entry else expected_caller_hash
		if ContractValues.sha256(_resolver.read_resolved(descriptor)) != expected_hash:
			return {"ok": false, "error": "%s resolved bytes changed" % required_entry}
	var decoder := MesInstructionDecoderScript.new()
	var entries: Array = _document.get("entries", [])
	var bootstrap_validation := _validate_catalog_bootstrap(definition, decoder)
	if not bootstrap_validation.get("ok", false):
		return bootstrap_validation
	for untyped_entry in entries:
		var entry: Dictionary = untyped_entry
		var entry_index := int(entry.get("index", -1))
		var label_instruction := decoder.decode_at(
			_document.bytecode,
			int(entry.get("offset", -1)),
			int(entry.get("end_offset", -1))
		)
		if (
			not label_instruction.get("ok", false)
			or str(label_instruction.get("op", "")) != "entry_label"
			or label_instruction.get("operands", []).is_empty()
			or int(label_instruction.operands[0].get("value", -1)) != entry_index
		):
			return {"ok": false, "error": "catalog entry label %d changed" % entry_index}
	var caller_document := _parser.parse(
		_reader.read_entry(caller_entry),
		{"archive": archive_name, "entry": caller_entry}
	)
	if not caller_document.get("ok", false):
		return {"ok": false, "error": "%s could not be parsed" % caller_entry}
	var caller_offset := int(definition.get("caller_offset", -1))
	var caller_resume := int(definition.get("caller_resume", -1))
	var caller_instruction := decoder.decode_at(caller_document.bytecode, caller_offset)
	if (
		not caller_instruction.get("ok", false)
		or int(caller_instruction.get("command_id", -1)) != int(definition.get("caller_command", -1))
		or str(caller_instruction.get("op", "")) != str(definition.get("caller_op", ""))
		or str(caller_instruction.get("script_target", "")).to_upper() != target_entry
		or int(caller_instruction.get("end_offset", -1)) != caller_resume
	):
		return {"ok": false, "error": "%s catalog caller envelope changed" % caller_entry}
	var expected_envelope := PackedByteArray([
		int(definition.get("caller_command", -1)),
		0x01,
	])
	expected_envelope.append_array(target_entry.to_lower().to_ascii_buffer())
	expected_envelope.append_array(PackedByteArray([0x00, 0x00]))
	if caller_document.bytecode.slice(caller_offset, caller_resume) != expected_envelope:
		return {"ok": false, "error": "%s catalog caller bytes changed" % caller_entry}
	var result := {
		"ok": true,
		"fragment_count": maxi(0, entries.size() - 1),
		"caller_entry": caller_entry,
		"caller_offset": caller_offset,
		"caller_resume": caller_resume,
	}
	result.merge(bootstrap_validation, true)
	return result


func _validate_catalog_bootstrap(definition: Dictionary, decoder: RefCounted) -> Dictionary:
	if not definition.has("setup_start_coordinate"):
		return {"ok": true}
	var start_coordinate := int(definition.get("setup_start_coordinate", -1))
	var expected_entry_offset := int(definition.get("setup_entry_offset", -1))
	var expected_entry_index := int(definition.get("setup_entry_index", -1))
	var start_kind := str(definition.get("setup_start_kind", ""))
	var entries: Array = _document.get("entries", [])
	if (
		start_coordinate < 0
		or expected_entry_index < 0
		or expected_entry_index >= entries.size()
		or int((entries[expected_entry_index] as Dictionary).get("offset", -1)) != expected_entry_offset
		or start_kind not in ["source_table_entry", "audited_nested_call"]
		or (start_kind == "source_table_entry" and start_coordinate != expected_entry_offset)
	):
		return {"ok": false, "error": "catalog setup entry changed"}
	var result := {
		"ok": true,
		"setup_start_coordinate": start_coordinate,
		"setup_entry_offset": expected_entry_offset,
		"setup_entry_index": expected_entry_index,
		"setup_start_kind": start_kind,
		"exe_audit_schema": str(definition.get("exe_audit_schema", "")),
	}
	if not definition.has("nested_start_coordinate"):
		return result
	var nested_start_coordinate := int(definition.get("nested_start_coordinate", -1))
	var expected_target := int(definition.get("bootstrap_target", -1))
	var expected_bootstrap_entry_index := int(definition.get("bootstrap_entry_index", -1))
	var code: PackedByteArray = _document.get("bytecode", PackedByteArray())
	var instruction: Dictionary = decoder.decode_at(
		code,
		nested_start_coordinate,
		int(_document.get("header", {}).get("code_size", code.size()))
	)
	var operands: Array = instruction.get("operands", [])
	if (
		not instruction.get("ok", false)
		or int(instruction.get("command_id", -1)) != int(definition.get("bootstrap_command", -1))
		or str(instruction.get("op", "")) != str(definition.get("bootstrap_op", ""))
		or operands.size() != 2
		or int(operands[1].get("value", -1)) != expected_target
		or nested_start_coordinate != start_coordinate
		or expected_bootstrap_entry_index != expected_entry_index
		or expected_target != expected_entry_offset
	):
		return {"ok": false, "error": "catalog zero-start bootstrap changed"}
	result["nested_start_coordinate"] = nested_start_coordinate
	result["bootstrap_target"] = expected_target
	result["bootstrap_entry_index"] = expected_bootstrap_entry_index
	return result


func _on_address_selected() -> void:
	_clear_continuation()
	var item := address_tree.get_selected()
	if item != null:
		intro_edit.text = "0x%X" % int(item.get_metadata(0))
	_sync_catalog_preview_button()
	var fragment := _selected_catalog_fragment()
	if not fragment.is_empty():
		var fragment_summary := _ensure_source_table_item_summary(item)
		status_label.text = (
			"Fragment #%04d selected; first stop %s (%s), state changes %d; preview is original and read-only; native host selection order remains unresolved"
			% [
				int(fragment.entry_index),
				str(fragment_summary.get("display", "unknown")),
				str(fragment_summary.get("status", "unknown")),
				int(fragment_summary.get("state_diff_count", 0)),
			]
		)
	else:
		var setup := _selected_catalog_setup()
		if not setup.is_empty():
			if str(setup.get("start_kind", "")) == "audited_nested_call":
				status_label.text = (
					"Confirmed event bootstrap selected; Start Confirmed Event follows the audited zero-coordinate caller to original dialogue and choice"
					if bool(_active_address_catalog.get("setup_reaches_event_choice", false))
					else "Catalog setup selected; Preview Setup follows the audited zero-coordinate call; no event fragment is selected"
				)
			else:
				status_label.text = "Catalog setup selected; Preview Setup inspects source-table entry zero; host activation remains unresolved"
		else:
			var source_row := _selected_source_row()
			if not source_row.is_empty():
				var source_summary := _sync_selected_source_row_summary(source_row)
				status_label.text = (
					"Source-table row #%04d selected; first stop %s (%s), state changes %d; preview starts only this original address row; native host selection/order is not inferred"
					% [
						int(source_row.entry_index),
						str(source_summary.get("display", "unknown")),
						str(source_summary.get("status", "unknown")),
						int(source_summary.get("state_diff_count", 0)),
					]
				)


func _on_address_activated() -> void:
	_on_preview_catalog_fragment_pressed()


func _selected_catalog_fragment() -> Dictionary:
	if not _active_address_catalog.get("ok", false):
		return {}
	var item := address_tree.get_selected()
	if item == null or str(item.get_metadata(1)) != "catalog_fragment":
		return {}
	var entry_index := int(item.get_metadata(2))
	var entries: Array = _document.get("entries", [])
	if entry_index <= 0 or entry_index >= entries.size():
		return {}
	var entry: Dictionary = entries[entry_index]
	if int(entry.get("offset", -1)) != int(item.get_metadata(0)):
		return {}
	return {
		"entry_index": entry_index,
		"offset": int(entry.offset),
		"end_offset": int(entry.end_offset),
	}


func _selected_catalog_setup() -> Dictionary:
	if (
		not _active_address_catalog.get("ok", false)
		or not _active_address_catalog.has("setup_start_coordinate")
	):
		return {}
	var item := address_tree.get_selected()
	if (
		item == null
		or str(item.get_metadata(1)) != "catalog_setup"
		or int(item.get_metadata(2)) != int(_active_address_catalog.get("setup_entry_index", -1))
		or int(item.get_metadata(0)) != int(_active_address_catalog.get("setup_entry_offset", -1))
	):
		return {}
	return {
		"start_coordinate": int(_active_address_catalog.setup_start_coordinate),
		"entry_offset": int(_active_address_catalog.setup_entry_offset),
		"entry_index": int(_active_address_catalog.setup_entry_index),
		"start_kind": str(_active_address_catalog.get("setup_start_kind", "")),
	}


func _selected_source_row() -> Dictionary:
	var item := address_tree.get_selected()
	if item == null or str(item.get_metadata(1)) != "address_entry":
		return {}
	var entry_index := int(item.get_metadata(2))
	var entries: Array = _document.get("entries", [])
	if entry_index < 0 or entry_index >= entries.size():
		return {}
	var entry: Dictionary = entries[entry_index]
	if int(entry.get("offset", -1)) != int(item.get_metadata(0)):
		return {}
	return {
		"entry_index": entry_index,
		"offset": int(entry.offset),
		"end_offset": int(entry.end_offset),
	}


func _sync_selected_source_row_summary(source_row: Dictionary) -> Dictionary:
	var item := address_tree.get_selected()
	if (
		item == null
		or int(item.get_metadata(2)) != int(source_row.get("entry_index", -1))
		or int(item.get_metadata(0)) != int(source_row.get("offset", -1))
	):
		return {}
	return _ensure_source_table_item_summary(item)


func _ensure_source_table_item_summary(item: TreeItem) -> Dictionary:
	if item == null:
		return {}
	var kind := str(item.get_metadata(1))
	if kind != "address_entry" and kind != "catalog_fragment":
		return {}
	var entry_index := int(item.get_metadata(2))
	var entries: Array = _document.get("entries", [])
	if entry_index < 0 or entry_index >= entries.size():
		return {}
	var summary: Dictionary
	if kind == "catalog_fragment":
		if not _catalog_fragment_summaries.has(entry_index):
			_catalog_fragment_summaries[entry_index] = _build_source_row_summary(entries[entry_index])
		summary = _catalog_fragment_summaries[entry_index]
	else:
		if not _source_row_summaries.has(entry_index):
			_source_row_summaries[entry_index] = _build_source_row_summary(entries[entry_index])
		summary = _source_row_summaries[entry_index]
	var entry: Dictionary = entries[entry_index]
	item.set_text(2, "%d · %s" % [
		int(entry.get("end_offset", -1)) - int(entry.get("offset", -1)),
		str(summary.get("display", "unknown")),
	])
	item.set_tooltip_text(2, str(summary.get("tooltip", "")))
	return summary


func _sync_catalog_preview_button() -> void:
	if not is_instance_valid(preview_fragment_button):
		return
	var fragment := _selected_catalog_fragment()
	var setup := _selected_catalog_setup()
	var source_row := _selected_source_row()
	preview_fragment_button.disabled = fragment.is_empty() and setup.is_empty() and source_row.is_empty()
	var source_navigation_available := not fragment.is_empty() or not source_row.is_empty()
	previous_fragment_button.disabled = (
		not source_navigation_available or _source_table_neighbor(-1) == null
	)
	next_fragment_button.disabled = (
		not source_navigation_available or _source_table_neighbor(1) == null
	)
	previous_meaningful_button.disabled = previous_fragment_button.disabled
	next_meaningful_button.disabled = next_fragment_button.disabled
	if not setup.is_empty():
		preview_fragment_button.text = (
			"Start Confirmed Event"
			if bool(_active_address_catalog.get("setup_reaches_event_choice", false))
			else "Preview Setup"
		)
		if str(setup.get("start_kind", "")) == "audited_nested_call":
			preview_fragment_button.tooltip_text = (
				"Run the audited original zero-coordinate bootstrap through its confirmed dialogue and choice route."
				if bool(_active_address_catalog.get("setup_reaches_event_choice", false))
				else "Run the audited original zero-coordinate bootstrap into catalog setup. This does not select an event fragment."
			)
		else:
			preview_fragment_button.tooltip_text = "Inspect verified source-table setup entry zero. Native host activation is not inferred."
	elif not source_row.is_empty():
		preview_fragment_button.text = "Preview Row #%04d" % int(source_row.entry_index)
		preview_fragment_button.tooltip_text = (
			"Preview this original address-table row in isolation. This is tool input, not a confirmed native host selection or event start."
		)
	elif fragment.is_empty():
		preview_fragment_button.text = "Preview Fragment"
		preview_fragment_button.tooltip_text = (
			"Select a verified Fragment row. Native host selection order remains unresolved."
		)
	else:
		preview_fragment_button.text = "Preview #%04d" % int(fragment.entry_index)
		preview_fragment_button.tooltip_text = (
			"Preview this hash-bound original address-table fragment in the isolated game frame."
		)
	previous_fragment_button.tooltip_text = "Preview the previous source-table row. This is not a confirmed native event order."
	next_fragment_button.tooltip_text = "Preview the next source-table row. This is not a confirmed native event order."
	previous_meaningful_button.tooltip_text = "Find and preview the previous dialogue, DEF, or native-FX row in displayed source-table order. Scans up to 16 rows per click."
	next_meaningful_button.tooltip_text = "Find and preview the next dialogue, DEF, or native-FX row in displayed source-table order. Scans up to 16 rows per click."


func _source_table_neighbor(direction: int) -> TreeItem:
	if direction == 0:
		return null
	var item := address_tree.get_selected()
	if item == null:
		return null
	var selected_kind := str(item.get_metadata(1))
	if selected_kind != "catalog_fragment" and selected_kind != "address_entry":
		return null
	return KakyuEventPlayerRules.same_kind_source_table_neighbor(item, direction, selected_kind)


func _preview_source_table_neighbor(direction: int) -> void:
	var target := _source_table_neighbor(direction)
	if target == null:
		status_label.text = "No further previewable source-table row is available in that direction."
		return
	target.select(0)
	address_tree.scroll_to_item(target)
	_on_address_selected()
	_on_preview_catalog_fragment_pressed()


func _meaningful_source_table_neighbor(direction: int) -> Dictionary:
	if direction == 0:
		return {}
	var item := address_tree.get_selected()
	if item == null:
		return {}
	var selected_kind := str(item.get_metadata(1))
	if selected_kind != "catalog_fragment" and selected_kind != "address_entry":
		return {}
	var candidate := item
	var last_scanned: TreeItem
	var scanned := 0
	while scanned < MEANINGFUL_SOURCE_SCAN_LIMIT:
		candidate = KakyuEventPlayerRules.same_kind_source_table_neighbor(candidate, direction, selected_kind)
		if candidate == null:
			return {
				"target": null,
				"cursor": last_scanned,
				"scanned": scanned,
				"has_more": false,
			}
		last_scanned = candidate
		scanned += 1
		var summary := _ensure_source_table_item_summary(candidate)
		if KakyuEventPlayerRules.source_row_is_meaningful(summary):
			return {
				"target": candidate,
				"cursor": candidate,
				"scanned": scanned,
				"has_more": KakyuEventPlayerRules.same_kind_source_table_neighbor(candidate, direction, selected_kind) != null,
			}
	return {
		"target": null,
		"cursor": last_scanned,
		"scanned": scanned,
		"has_more": (
			last_scanned != null
			and KakyuEventPlayerRules.same_kind_source_table_neighbor(last_scanned, direction, selected_kind) != null
		),
	}


func _preview_meaningful_source_table_neighbor(direction: int) -> void:
	var search := _meaningful_source_table_neighbor(direction)
	var target: TreeItem = search.get("target")
	if target == null:
		var cursor: TreeItem = search.get("cursor")
		if cursor != null:
			cursor.select(0)
			address_tree.scroll_to_item(cursor)
			_on_address_selected()
		var direction_label := "previous" if direction < 0 else "next"
		var scan_direction := "backward" if direction < 0 else "forward"
		var button_label := "Prev" if direction < 0 else "Next"
		if bool(search.get("has_more", false)):
			status_label.text = (
				"Scanned %d source-table rows %s without a content stop; click %s hit again to continue from row #%04d."
				% [
					int(search.get("scanned", 0)),
					scan_direction,
					button_label,
					int(cursor.get_metadata(2)),
				]
			)
		else:
			status_label.text = (
				"No %s dialogue, DEF, or native-FX row is available in displayed source-table order."
				% direction_label
			)
			if direction < 0:
				previous_meaningful_button.disabled = true
			else:
				next_meaningful_button.disabled = true
		return
	target.select(0)
	address_tree.scroll_to_item(target)
	_on_address_selected()
	_on_preview_catalog_fragment_pressed()


func _on_previous_catalog_fragment_pressed() -> void:
	_preview_source_table_neighbor(-1)


func _on_next_catalog_fragment_pressed() -> void:
	_preview_source_table_neighbor(1)


func _on_previous_meaningful_row_pressed() -> void:
	_preview_meaningful_source_table_neighbor(-1)


func _on_next_meaningful_row_pressed() -> void:
	_preview_meaningful_source_table_neighbor(1)


func _on_preview_catalog_fragment_pressed() -> void:
	var fragment := _selected_catalog_fragment()
	if fragment.is_empty():
		var setup := _selected_catalog_setup()
		if not setup.is_empty():
			_preview_catalog_setup(setup)
			return
		var source_row := _selected_source_row()
		if not source_row.is_empty():
			_preview_source_row(source_row)
			return
		status_label.text = "Select an address-table row, verified Fragment, or audited Catalog setup before previewing."
		return
	_clear_continuation()
	_reset_game_preview(_selected_entry)
	_preview_event_session = "catalog_fragment"
	_preview_catalog_fragment_index = int(fragment.entry_index)
	intro_edit.text = "0x%X" % int(fragment.offset)
	_run_from_offset(int(fragment.offset))
	_preview_entry_label.text = "%s · fragment #%04d · intro 0x%X · stopped 0x%X" % [
		_selected_entry,
		int(fragment.entry_index),
		int(fragment.offset),
		_preview_result_offset,
	]
	status_label.text = (
		"Previewed original fragment #%04d from %s; host selection order unresolved; sandbox only"
		% [int(fragment.entry_index), _selected_entry]
	)


func _preview_source_row(source_row: Dictionary) -> void:
	_clear_continuation()
	_reset_game_preview(_selected_entry)
	_preview_event_session = "source_row"
	var entry_index := int(source_row.entry_index)
	_preview_source_row_index = entry_index
	var offset := int(source_row.offset)
	intro_edit.text = "0x%X" % offset
	_run_from_offset(offset)
	_preview_entry_label.text = "%s · source row #%04d · intro 0x%X · stopped 0x%X" % [
		_selected_entry,
		entry_index,
		offset,
		_preview_result_offset,
	]
	status_label.text = (
		"Previewed original source-table row #%04d from %s; isolated tool path only; native host selection/order not inferred"
		% [entry_index, _selected_entry]
	)


func _preview_catalog_setup(setup: Dictionary) -> void:
	_clear_continuation()
	_reset_game_preview(_selected_entry)
	_preview_event_session = "catalog_setup"
	_preview_catalog_confirmed_bootstrap = false
	_preview_catalog_fragment_index = 0
	var start_coordinate := int(setup.start_coordinate)
	var state_before := _state.snapshot()
	intro_edit.text = "0x%X" % start_coordinate
	_run_from_offset(start_coordinate)
	var state_change_count := _state.diff(state_before).size()
	var start_label := "zero-start" if str(setup.get("start_kind", "")) == "audited_nested_call" else "entry-start"
	var route_label := "confirmed event bootstrap" if bool(_active_address_catalog.get("setup_reaches_event_choice", false)) else "catalog setup"
	_preview_entry_label.text = "%s · %s · %s 0x%X · stopped 0x%X" % [
		_selected_entry,
		route_label,
		start_label,
		start_coordinate,
		_preview_result_offset,
	]
	if str(setup.get("start_kind", "")) == "audited_nested_call":
		status_label.text = (
			"Started original zero-start event bootstrap from %s; %d isolated state changes; continue to confirmed dialogue/choice"
			% [_selected_entry, state_change_count]
			if bool(_active_address_catalog.get("setup_reaches_event_choice", false))
			else "Previewed original zero-start Catalog setup from %s; %d isolated state changes; no event fragment selected" % [_selected_entry, state_change_count]
		)
	else:
		status_label.text = "Previewed original source-table Catalog setup from %s; %d isolated state changes; host activation unresolved; no event fragment selected" % [_selected_entry, state_change_count]


func _on_load_state_pressed() -> void:
	var value = JSON.parse_string(state_json.text)
	if not value is Array:
		status_label.text = "Sandbox state must be a JSON array of storage/index/value records."
		return
	var candidate := SandboxStateScript.new(1)
	var loaded := candidate.load_values(value)
	if not loaded.ok:
		status_label.text = "Sandbox state rejected: accepted %d of %d records." % [loaded.accepted, loaded.total]
		return
	_apply_startup_calendar_state(candidate)
	_state = candidate
	_sync_quick_state_fields()
	_clear_continuation()
	_clear_choice_projection()
	_sync_event_start_button()
	status_label.text = "Loaded %d isolated sandbox state records." % loaded.accepted


func _on_apply_quick_state_pressed() -> void:
	var hhmm := int(hhmm_edit.value)
	if hhmm < 0 or hhmm > 2359 or hhmm % 100 >= 60:
		status_label.text = "HHMM must be between 0000 and 2359 with minutes below 60."
		return
	_state.write_value("state_u16", 4, int(weekday_edit.value))
	_state.write_value("state_u16", 7, int(legacy_date_edit.value))
	_state.write_value("state_u16", 19, hhmm)
	_state.write_value("banked_u16", 210, int(mahoko_affection_edit.value), 0)
	_state.write_value("banked_u16", 212, int(maki_affection_edit.value), 0)
	_sync_state_json()
	_clear_continuation()
	_clear_choice_projection()
	_sync_event_start_button()
	status_label.text = (
		"Applied isolated weekday/date/HHMM and Mahoko/Maki affection slots; "
		+ "original ARC and gameplay saves unchanged."
	)


func _on_set_quick_flag_pressed() -> void:
	var index := int(flag_index_edit.value)
	var value := int(flag_value_edit.value)
	_state.write_value("global_u8", index, value)
	_sync_state_json()
	_clear_continuation()
	_clear_choice_projection()
	status_label.text = (
		"Set isolated global_u8[%d] = %d; original ARC and gameplay saves unchanged."
		% [index, value]
	)


func _on_apply_promise_location_pressed() -> void:
	var route := _active_promise_date_route()
	if route.is_empty():
		status_label.text = "Select a hash-bound original PROMIS entry before applying a location."
		return
	var field := int(route.location_field)
	var location_id := int(promise_location_edit.value)
	_state.write_value("global_u8", field, location_id)
	_sync_state_json()
	_clear_continuation()
	_clear_choice_projection()
	_sync_event_start_button()
	status_label.text = (
		"Set isolated PROMIS location global_u8[%d] = %d; time rows will show audited OK/NO/GATE status; source and saves unchanged."
		% [field, location_id]
	)


func _on_flag_index_changed(_value: float) -> void:
	flag_value_edit.value = _state.read_value("global_u8", int(flag_index_edit.value))


func _on_reset_state_pressed() -> void:
	_state = SandboxStateScript.new(1)
	_apply_startup_calendar_state(_state)
	state_json.text = "[]"
	_sync_quick_state_fields()
	protagonist_name_edit.clear()
	_clear_continuation()
	_clear_choice_projection()
	_sync_event_start_button()
	status_label.text = "Sandbox state reset; no gameplay save was changed."


func _sync_quick_state_fields() -> void:
	weekday_edit.value = _state.read_value("state_u16", 4)
	legacy_date_edit.value = _state.read_value("state_u16", 7)
	hhmm_edit.value = _state.read_value("state_u16", 19)
	mahoko_affection_edit.value = _state.read_value("banked_u16", 210, 0)
	maki_affection_edit.value = _state.read_value("banked_u16", 212, 0)
	_on_flag_index_changed(flag_index_edit.value)
	_sync_promise_location_fields()


func _active_promise_date_route() -> Dictionary:
	var route: Dictionary = PROMISE_DATE_ROUTE_DEFINITIONS.get(_selected_entry.to_upper(), {})
	if (
		route.is_empty()
		or str(route.get("entry_sha256", "")) != str(_document.get("entry_sha256", ""))
		or str(_document.get("source", {}).get("resolved_source", "")) != "original_arc"
	):
		return {}
	return route


func _active_promise_option_route_state(option: int) -> String:
	var route := _active_promise_date_route()
	if route.is_empty():
		return "unavailable"
	return KakyuEventPlayerRules.promise_option_route_state(
		option,
		_selected_entry,
		_state.read_value("global_u8", int(route.location_field)),
		_state.read_value("global_u8", 1060)
	)


func _promise_option_route_tag(option: int) -> String:
	match _active_promise_option_route_state(option):
		"allowed":
			return " [OK]"
		"rejected":
			return " [NO]"
		"entry_gate":
			return " [GATE]"
	return ""


func _sync_promise_location_fields() -> void:
	if not is_instance_valid(promise_location_edit):
		return
	var route := _active_promise_date_route()
	var available := not route.is_empty()
	promise_location_edit.editable = available
	apply_promise_location_button.disabled = not available
	if not available:
		promise_location_label.text = "PROMIS location"
		promise_location_edit.value = 0
		promise_location_edit.tooltip_text = "Available only for a hash-bound original PROMIS scheduling entry."
		return
	var field := int(route.location_field)
	promise_location_label.text = "PROMIS location g[%d]" % field
	promise_location_edit.value = _state.read_value("global_u8", field)
	promise_location_edit.tooltip_text = (
		"Original selected-location ID in global_u8[%d]. Time-choice rows show [OK] for location-allowed, [NO] for rejected, and [GATE] for the separate A-entry 16:00-18:00 latch gate."
		% field
	)


func _sync_state_json() -> void:
	state_json.text = JSON.stringify(_state.to_records(), "\t")


func _on_run_pressed() -> void:
	if _document.is_empty() or not _document.get("ok", false):
		status_label.text = "Select a valid MES entry first."
		return
	var intro_result := KakyuEventPlayerRules.parse_offset(intro_edit.text)
	if not intro_result.ok:
		status_label.text = str(intro_result.error)
		return
	if _reject_non_original_document():
		return
	var intro_offset := int(intro_result.value)
	_catalog_playback_active = false
	_catalog_playback_request.clear()
	_clear_continuation()
	_clear_preview_route_identity()
	_prepare_confirmed_anchor_presentation(intro_offset)
	_run_from_offset(intro_offset)


func _on_start_event_pressed() -> void:
	var anchor := _confirmed_event_start()
	if anchor.is_empty():
		status_label.text = "This entry has no hash-bound event start yet; use an audited intro coordinate."
		return
	var intro_offset := int(anchor.offset)
	var nested_readiness := {}
	if str(anchor.get("event_start_kind", "")) == PROMISE_DATE_ROUTE_KIND:
		var validation := _validate_promise_date_route(anchor)
		if not validation.get("ok", false):
			status_label.text = "PROMIS date route unavailable: %s" % str(
				validation.get("error", "source validation failed")
			)
			return
	elif str(anchor.get("event_start_kind", "")) == NESTED_PROMISE_ROUTE_KIND:
		nested_readiness = _nested_promise_route_readiness(anchor)
		if not nested_readiness.get("ok", false):
			status_label.text = "Nested conversation route unavailable: %s" % str(
				nested_readiness.get("error", "source validation failed")
			)
			return
	if _reject_non_original_document():
		return
	intro_edit.text = "0x%X" % intro_offset
	_clear_continuation()
	_clear_preview_route_identity()
	_clear_preview_media_state()
	_prepare_confirmed_anchor_presentation(intro_offset)
	if (
		_selected_entry == "DEF_MAIN.MES"
		and _is_catalog_source_entry(str(_document.get("entry_sha256", "")), "DEF_MAIN.MES")
		and intro_offset == AUDITED_DEF26_BODY_OFFSET
	):
		_preview_event_session = "def26_isolated_body"
	elif str(anchor.get("event_start_kind", "")) == PROMISE_DATE_ROUTE_KIND:
		_preview_event_session = "promise_date"
	elif str(anchor.get("event_start_kind", "")) == NESTED_PROMISE_ROUTE_KIND:
		_preview_event_session = "nested_promise"
	_run_confirmed_event_execution(anchor, intro_offset, nested_readiness)
	if str(anchor.get("event_start_kind", "")) == NESTED_PROMISE_ROUTE_KIND:
		if str(_choice_projection.get("kind", "")) == "nested_promise":
			status_label.text = "Started audited nested conversation at 0x%X with an explicit sandbox seed; choose an original L_TALK30 body" % intro_offset
	elif str(anchor.get("event_start_kind", "")) == PROMISE_DATE_ROUTE_KIND:
		status_label.text = "Started confirmed PROMIS scheduling prefix at 0x%X; outer caller unresolved; sandbox only" % intro_offset
	elif str(anchor.get("event_start_kind", "")) == "catalog_bootstrap":
		status_label.text = "Started confirmed EVENTD14 zero-coordinate event bootstrap; continue through original dialogue to its choice; sandbox only"
	else:
		status_label.text = "Started confirmed %s event route at 0x%X; sandbox only" % [
			str(anchor.event_start_kind),
			intro_offset,
		]


func _run_confirmed_event_execution(anchor: Dictionary, intro_offset: int, nested_readiness: Dictionary) -> void:
	if str(anchor.get("event_start_kind", "")) == "catalog_bootstrap":
		_preview_catalog_setup({
			"start_coordinate": intro_offset,
			"entry_offset": int(_active_address_catalog.get("setup_entry_offset", -1)),
			"entry_index": int(_active_address_catalog.get("setup_entry_index", -1)),
			"start_kind": str(_active_address_catalog.get("setup_start_kind", "")),
		})
	elif str(anchor.get("event_start_kind", "")) == NESTED_PROMISE_ROUTE_KIND:
		_state.write_value("banked_u16", 209, 21, 0)
		_state.write_value("global_u8", 1941, 1)
		_nested_promise_context = nested_readiness.duplicate(true)
		_nested_promise_context["root_entry"] = _selected_entry.to_upper()
		_nested_promise_context["base_state"] = _state.snapshot()
		_sync_state_json()
		_run_nested_promise_route()
	else:
		_run_from_offset(intro_offset)


func _confirmed_event_start() -> Dictionary:
	for anchor in _confirmed_preview_anchors(_selected_entry, str(_document.get("entry_sha256", ""))):
		if not str(anchor.get("event_start_kind", "")).is_empty():
			return anchor
	return {}


func _nested_promise_route_readiness(anchor: Dictionary) -> Dictionary:
	if str(anchor.get("event_start_kind", "")) != NESTED_PROMISE_ROUTE_KIND:
		return {"ok": false, "error": "The selected anchor is not an audited nested PROMIS route."}
	var route: Dictionary = NESTED_PROMISE_ROUTES.get(_selected_entry.to_upper(), {})
	if (
		route.is_empty()
		or not _reader.is_open()
		or _reader.get_archive_identity_fingerprint() != KakyuEventPlayerEvidence.AUDITED_MES_ARCHIVE_SHA256
		or str(_document.get("entry_sha256", "")) != str(route.get("entry_sha256", ""))
		or str(_document.get("source", {}).get("resolved_source", "")) != "original_arc"
		or int(anchor.get("offset", -1)) != int(route.get("intro", -2))
	):
		return {"ok": false, "error": "The root MES or archive does not match the audited original route."}
	var address_offsets: Array = _document.get("header", {}).get("entry_offsets", [])
	var owner_index := int(route.get("owner_index", -1))
	if owner_index < 0 or owner_index >= address_offsets.size() or int(address_offsets[owner_index]) != int(route.intro):
		return {"ok": false, "error": "The audited root owner coordinate is absent from the original address table."}
	var descriptor := _resolver.resolve("mes.arc", NESTED_PROMISE_TALK_ENTRY)
	if not descriptor.get("ok", false) or str(descriptor.get("source", "")) != "original_arc":
		return {"ok": false, "error": "The exact original L_TALK30.MES target is unavailable or shadowed by an overlay."}
	var data := _resolver.read_resolved(descriptor)
	if data.is_empty() and not _resolver.last_error.is_empty():
		return {"ok": false, "error": "The nested conversation target could not be read."}
	var talk_document := _parser.parse(data, {
		"archive": "mes.arc",
		"entry": NESTED_PROMISE_TALK_ENTRY,
		"resolved_source": descriptor.source,
	})
	if not talk_document.get("ok", false) or str(talk_document.get("entry_sha256", "")) != NESTED_PROMISE_TALK_SHA256:
		return {"ok": false, "error": "L_TALK30.MES does not match the audited original entry."}
	return {
		"ok": true,
		"route": route.duplicate(true),
		"scripts": {
			_selected_entry.to_upper(): _document.duplicate(true),
			NESTED_PROMISE_TALK_ENTRY: talk_document,
		},
	}


func _promise_date_route_readiness(anchor: Dictionary) -> Dictionary:
	if str(anchor.get("event_start_kind", "")) != PROMISE_DATE_ROUTE_KIND:
		return {"ok": false, "error": "The selected anchor is not an isolated PROMIS date route."}
	var definition := _active_promise_date_route()
	if definition.is_empty():
		return {"ok": false, "error": "The route must resolve from its hash-bound original MES entry."}
	if (
		str(_library_index.get("source", "")) != "original_arc"
		or not _is_catalog_source_entry(str(_library_index.get("entry_sha256", "")), "LIBLARY.LIB")
		or str(_startup_context.get("source", "")) != "original_arc"
		or not _state.native_relative_u8_aliases_enabled()
	):
		return {"ok": false, "error": "The hash-bound START/LIBLARY calendar context is not active."}
	var entry_offsets: Array = _document.get("header", {}).get("entry_offsets", [])
	if not entry_offsets.has(int(anchor.get("offset", -1))):
		return {"ok": false, "error": "The confirmed owner intro is no longer an address-table entry."}
	var date_validation := _validate_legacy_calendar_date(_state.read_value("state_u16", 7))
	if not date_validation.get("ok", false):
		return date_validation
	return {
		"ok": true,
		"date": int(date_validation.date),
		"next_date": int(date_validation.next_date),
	}


func _validate_legacy_calendar_date(date_value: int) -> Dictionary:
	var calendar_projection: Dictionary = _startup_context.get("calendar_state", {})
	var row_lengths: Array = calendar_projection.get("row_lengths", [])
	if row_lengths.size() != 12:
		return {"ok": false, "error": "The audited original calendar rows are unavailable."}
	var month := int(date_value / 100)
	var day := date_value % 100
	if month < 1 or month > 12 or day < 1 or day > int(row_lengths[month - 1]):
		return {
			"ok": false,
			"error": "Apply a valid legacy date (MMDD) before starting this isolated route.",
		}
	var next_month := month
	var next_day := day + 1
	if next_day > int(row_lengths[month - 1]):
		next_day = 1
		next_month = month + 1
	return {
		"ok": true,
		"date": date_value,
		"next_date": next_month * 100 + next_day,
	}


func _validate_promise_date_route(anchor: Dictionary) -> Dictionary:
	var readiness := _promise_date_route_readiness(anchor)
	if not readiness.get("ok", false):
		return readiness
	if str(anchor.get("validation_mode", "")) == "presentation_to_choice":
		return _validate_promise_presentation_date_route(anchor, readiness)
	var probe_state := SandboxStateScript.new(1)
	if not _apply_startup_calendar_state(probe_state):
		return {"ok": false, "error": "The original calendar baseline could not be isolated for validation."}
	probe_state.write_value("state_u16", 7, int(readiness.date))
	probe_state.write_value("state_u16", 19, 77)
	probe_state.write_value("banked_u16", int(anchor.field), 0xFFFF, 0)
	var prefix := _runner.run(
		_document.bytecode,
		int(anchor.offset),
		probe_state,
		int(_document.header.code_size),
		2000,
		{
			"address_table_offsets": _document.header.entry_offsets,
			"native_stream_policy": "skip_bounded",
		}
	)
	var prefix_trace: Array = prefix.get("trace", [])
	if (
		str(prefix.get("status", "")) != "shared_routine_boundary"
		or prefix_trace.size() != 9
		or int(prefix.get("offset", -1)) != int(anchor.boundary)
		or int(prefix.get("resume_offset", -1)) != int(anchor.resume)
		or int(prefix_trace[-1].get("routine_id", -1)) != 24
		or probe_state.read_value("state_u16", 9) != 1
		or probe_state.read_value("state_u16", 10) != int(readiness.date)
	):
		return {"ok": false, "error": "The original owner prefix no longer reaches shared routine 24."}
	var library_result := MesLibraryRunnerScript.new().run(
		_library_document.bytecode,
		_library_index,
		24,
		probe_state,
		{
			"argument_slots": prefix.get("argument_slots", {}).duplicate(true),
			"persistent_expression_stack": prefix.get("persistent_expression_stack", []).duplicate(),
		}
	)
	if (
		not library_result.get("ok", false)
		or str(library_result.get("status", "")) != "library_return"
		or not (library_result.get("calls", []) as Array).is_empty()
		or not (library_result.get("messages", []) as Array).is_empty()
		or int(library_result.get("omitted_native_presentation_count", -1)) != 0
	):
		return {
			"ok": false,
			"error": "Shared routine 24 stopped at %s after %d rows with %d nested calls; this date path is not yet supported."
			% [
				str(library_result.get("status", "unknown")),
				(library_result.get("trace", []) as Array).size(),
				(library_result.get("calls", []) as Array).size(),
			],
		}
	var suffix := _runner.run(
		_document.bytecode,
		int(anchor.resume),
		probe_state,
		int(_document.header.code_size),
		2000,
		{
			"argument_slots": library_result.get("argument_slots", {}).duplicate(true),
			"persistent_expression_stack": library_result.get("persistent_expression_stack", []).duplicate(),
			"native_stream_policy": "skip_bounded",
		}
	)
	var writer_rows: Array = suffix.get("trace", []).filter(
		func(record: Dictionary) -> bool:
			return int(record.get("source_offset", -1)) == int(anchor.writer)
	)
	# Core 0.316.0 (2026-09-13): the 13-row "return" this probe once expected
	# after the writer was the 00 that ends a message wait's record list, read
	# as command 0x00 under the separator framing; the suffix runs on from the
	# writer to the time selector's DEF selection boundary, the route's
	# `choice_boundary`.
	if (
		str(suffix.get("status", "")) != "def_selection_boundary"
		or (suffix.get("trace", []) as Array).size() != int(anchor.get("date_suffix_rows", -1))
		or int(suffix.get("offset", -1)) != int(anchor.choice_boundary)
		or writer_rows.size() != 1
		or probe_state.read_value("banked_u16", int(anchor.field), 0) != int(readiness.next_date)
		or probe_state.read_value("state_u16", 10) != int(readiness.next_date)
	):
		return {
			"ok": false,
			"error": "The original date suffix produced %04d in field %d and %04d in state 10; expected %04d."
			% [
				probe_state.read_value("banked_u16", int(anchor.field), 0),
				int(anchor.field),
				probe_state.read_value("state_u16", 10),
				int(readiness.next_date),
			],
		}
	return readiness


func _validate_promise_presentation_date_route(anchor: Dictionary, readiness: Dictionary) -> Dictionary:
	var probe_state := SandboxStateScript.new(1)
	if not _apply_startup_calendar_state(probe_state):
		return {"ok": false, "error": "The original calendar baseline could not be isolated for validation."}
	probe_state.write_value("state_u16", 7, int(readiness.date))
	probe_state.write_value("state_u16", 19, 77)
	probe_state.write_value("banked_u16", int(anchor.field), 0xFFFF, 0)
	var cursor := int(anchor.offset)
	var context := {
		"address_table_offsets": _document.header.entry_offsets.duplicate(),
		"protagonist_name": "Audit",
	}
	var dialogue_boundaries := 0
	var library_calls := 0
	var writer_hits := 0
	var terminal: Dictionary = {}
	for _segment in range(64):
		var result := _runner.run(
			_document.bytecode,
			cursor,
			probe_state,
			int(_document.header.code_size),
			2000,
			context
		)
		for record in result.get("trace", []):
			if int(record.get("source_offset", -1)) == int(anchor.writer):
				writer_hits += 1
		var status := str(result.get("status", ""))
		if status == "dialogue_boundary":
			dialogue_boundaries += 1
			cursor = int(result.get("resume_offset", -1))
			context = {
				"address_table_offsets": _document.header.entry_offsets.duplicate(),
				"protagonist_name": "Audit",
				"argument_slots": result.get("argument_slots", {}).duplicate(true),
				"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
			}
			continue
		if status == "shared_routine_boundary":
			var trace: Array = result.get("trace", [])
			var routine_id := int(trace[-1].get("routine_id", -1)) if not trace.is_empty() else -1
			if (
				routine_id != 24
				or int(result.get("offset", -1)) != int(anchor.boundary)
				or int(result.get("resume_offset", -1)) != int(anchor.resume)
				or library_calls != 0
			):
				return {"ok": false, "error": "The presentation-bearing prefix reached an unexpected shared-library boundary."}
			var library_result := MesLibraryRunnerScript.new().run(
				_library_document.bytecode,
				_library_index,
				routine_id,
				probe_state,
				{
					"argument_slots": result.get("argument_slots", {}).duplicate(true),
					"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
				}
			)
			if (
				not library_result.get("ok", false)
				or str(library_result.get("status", "")) != "library_return"
				or (library_result.get("trace", []) as Array).size() != 102
				or not (library_result.get("calls", []) as Array).is_empty()
				or not (library_result.get("messages", []) as Array).is_empty()
				or int(library_result.get("omitted_native_presentation_count", -1)) != 0
			):
				return {"ok": false, "error": "Shared routine 24 no longer matches the audited presentation-bearing date route."}
			library_calls += 1
			cursor = int(result.get("resume_offset", -1))
			context = {
				"address_table_offsets": _document.header.entry_offsets.duplicate(),
				"protagonist_name": "Audit",
				"argument_slots": library_result.get("argument_slots", {}).duplicate(true),
				"persistent_expression_stack": library_result.get("persistent_expression_stack", []).duplicate(),
			}
			continue
		terminal = result
		break
	var definitions: Array = terminal.get("definitions", [])
	if (
		dialogue_boundaries != int(anchor.get("validation_dialogues", -1))
		or library_calls != 1
		or writer_hits != 1
		or str(terminal.get("status", "")) != "def_selection_boundary"
		or int(terminal.get("offset", -1)) != int(anchor.choice_boundary)
		or definitions.size() != 10
		or probe_state.read_value("banked_u16", int(anchor.field), 0) != int(readiness.next_date)
		or probe_state.read_value("state_u16", 10) != int(readiness.next_date)
	):
		return {
			"ok": false,
			"error": "The presentation-bearing date route did not reach its exact date writer and ten-option selector.",
		}
	return readiness


func _sync_event_start_button() -> void:
	if not is_instance_valid(start_event_button):
		return
	var anchor := _confirmed_event_start()
	start_event_button.disabled = anchor.is_empty()
	if anchor.is_empty():
		start_event_button.text = "Start Event"
		start_event_button.tooltip_text = (
			"This is a verified fragment catalog, but its native host selection is unresolved. Use Preview Fragment."
			if _active_address_catalog.get("ok", false)
			else "No hash-bound event start is available for this entry."
		)
		return
	var kind := str(anchor.event_start_kind)
	if kind == PROMISE_DATE_ROUTE_KIND:
		var readiness := _validate_promise_date_route(anchor)
		start_event_button.disabled = not readiness.get("ok", false)
		start_event_button.text = "Start PROMIS Schedule"
		start_event_button.tooltip_text = (
			"%s at 0x%X; runs original dialogue, routine 24, date field %d, and confirmed time choice. Outer gameplay caller unresolved."
			% [str(anchor.label), int(anchor.offset), int(anchor.field)]
			if readiness.get("ok", false)
			else str(readiness.get("error", "The isolated date route is unavailable."))
		)
		return
	if kind == NESTED_PROMISE_ROUTE_KIND:
		var readiness := _nested_promise_route_readiness(anchor)
		start_event_button.disabled = not readiness.get("ok", false)
		start_event_button.text = "Start Nested Dialogue"
		start_event_button.tooltip_text = (
			"%s at 0x%X; applies the documented sandbox seed, opens L_TALK30.MES, and restores this caller after an explicit choice."
			% [str(anchor.label), int(anchor.offset)]
			if readiness.get("ok", false)
			else str(readiness.get("error", "The nested route is unavailable."))
		)
		return
	match kind:
		"dialogue":
			start_event_button.text = "Start Event Dialogue"
		"choice":
			start_event_button.text = "Start Event Choice"
		"isolated_body":
			start_event_button.text = "Start Isolated DEF Body"
		"catalog_bootstrap":
			start_event_button.text = "Start Confirmed Event"
		_:
			start_event_button.text = "Start Confirmed Route"
	start_event_button.tooltip_text = "%s at confirmed code-relative offset 0x%X." % [
		str(anchor.label),
		int(anchor.offset),
	]


func _prepare_confirmed_anchor_presentation(intro_offset: int) -> void:
	for anchor in _confirmed_preview_anchors(_selected_entry, str(_document.get("entry_sha256", ""))):
		if int(anchor.offset) != intro_offset:
			continue
		if str(anchor.get("prelude_mmo_route", "")) == "eventd01_hhmm":
			var specification := KakyuEventPlayerRules.eventd01_background_specification(_state.read_value("state_u16", 19))
			_present_mmo_resource(
				str(specification.resource),
				"%s time reference 0x%X for sandbox HHMM %04d"
				% [_selected_entry.get_basename(), int(specification.source_offset), int(specification.hhmm)]
			)
		if str(anchor.get("prelude_mmo_route", "")) == "eventd05_hhmm":
			var specification := KakyuEventPlayerRules.eventd05_background_specification(_state.read_value("state_u16", 19))
			_present_mmo_resource(
				str(specification.resource),
				"EVENTD05 time reference 0x%X for sandbox HHMM %04d"
				% [int(specification.source_offset), int(specification.hhmm)]
			)
		if anchor.has("prelude_mmo"):
			_present_mmo_resource(
				str(anchor.prelude_mmo),
				"confirmed pre-anchor 0x%X" % int(anchor.get("prelude_mmo_offset", -1))
			)
		if anchor.has("prelude_bgm"):
			var bgm_request := _validated_anchor_bgm_request(anchor)
			if bgm_request.ok:
				_present_latest_bgm_resource([bgm_request.trace_record])
		return


# Core 0.316.0 (2026-09-13): EVENTD01's background references are the whole
# System.function[9] calls, so each source offset is the 0x0D byte.
func _validated_anchor_bgm_request(anchor: Dictionary) -> Dictionary:
	var entry_name := str(anchor.get("prelude_bgm_entry", "")).to_upper()
	var entry_sha := str(anchor.get("prelude_bgm_entry_sha256", ""))
	if (
		entry_name.is_empty()
		or entry_sha.is_empty()
		or not _reader.is_open()
		or _reader.get_entry_fingerprint(entry_name) != entry_sha
	):
		return {"ok": false, "error": "prelude BGM evidence entry is unavailable"}
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	var descriptor := _resolver.resolve(archive_name, entry_name)
	if not descriptor.ok or str(descriptor.source) != "original_arc":
		return {"ok": false, "error": "prelude BGM evidence must resolve from original ARC"}
	var data := _resolver.read_resolved(descriptor)
	if ContractValues.sha256(data) != entry_sha:
		return {"ok": false, "error": "prelude BGM evidence bytes changed"}
	var document := _parser.parse(data, {"archive": archive_name, "entry": entry_name})
	if not document.ok:
		return {"ok": false, "error": "prelude BGM evidence could not be parsed"}
	var probe_state := SandboxStateScript.new(1)
	var result := _runner.run(
		document.bytecode,
		int(anchor.get("prelude_bgm_offset", -1)),
		probe_state,
		int(document.header.code_size)
	)
	if result.get("trace", []).size() < 2:
		return {
			"ok": false,
			"error": "prelude BGM trace prefix changed: status=%s offset=0x%X rows=%d" % [
				str(result.get("status", "")),
				int(result.get("offset", -1)),
				result.get("trace", []).size(),
			],
		}
	var assignment: Dictionary = result.trace[0]
	var request: Dictionary = result.trace[1]
	if (
		int(assignment.get("source_offset", -1)) != int(anchor.get("prelude_bgm_offset", -1))
		or int(request.get("source_offset", -1)) != int(anchor.get("prelude_bgm_boundary", -1))
		or str(request.get("effect", "")) != "bgm_request"
		or int(request.get("bgm_selector", -1)) != int(anchor.get("prelude_bgm_selector", -1))
		or str(request.get("resource_name", "")).to_upper() != str(anchor.get("prelude_bgm", "")).to_upper()
		or int(request.get("routine_id", -1)) != int(anchor.get("prelude_bgm_routine", -1))
	):
		return {"ok": false, "error": "prelude BGM request changed"}
	return {"ok": true, "trace_record": request.duplicate(true)}


func _on_continue_pressed() -> void:
	if _continuation_offset < 0:
		status_label.text = "No supported dialogue continuation is available."
		return
	var resume_offset := _continuation_offset
	var runtime_context := _continuation_context.duplicate(true)
	if str(runtime_context.get("kind", "")) in ["catalog_setup_native_presentation_omitted", "catalog_setup_native_records_omitted"]:
		_preview_catalog_setup_native_fx_omitted = true
	_clear_continuation()
	if str(runtime_context.get("kind", "dialogue")) in ["shared_library", "registered_def_library"]:
		_run_library_and_resume(resume_offset, runtime_context)
	elif str(runtime_context.get("kind", "dialogue")) == "library_dialogue":
		_resume_library_and_resume(resume_offset, runtime_context)
	elif str(runtime_context.get("kind", "dialogue")) in ["registered_definition_start", "registered_definition_dialogue"]:
		_run_registered_definition_frame(resume_offset, runtime_context)
	else:
		_run_from_offset(resume_offset, runtime_context)
	_continue_catalog_playback_if_needed()


func _continue_catalog_playback_if_needed() -> void:
	if _catalog_playback_active and not _catalog_playback_autodriving and _view_mode == VIEW_MODE_PLAYBACK:
		_drive_catalog_playback_to_user_boundary()


func _drive_catalog_playback_to_user_boundary(max_transitions := 128) -> Dictionary:
	if not _catalog_playback_active:
		return {"ok": false, "error": "No catalog playback session is active."}
	if _view_mode != VIEW_MODE_PLAYBACK:
		return {"ok": true, "transitions": 0, "paused_for_analysis": true}
	if _catalog_playback_autodriving:
		return {"ok": true, "transitions": 0, "already_driving": true}
	_catalog_playback_autodriving = true
	var transitions := 0
	while (
		transitions < max_transitions
		and not _catalog_terminal_rejected_completion
		and _continuation_offset >= 0
		and _preview_messages.is_empty()
		and _choice_projection.is_empty()
	):
		var before_offset := _continuation_offset
		var before_kind := str(_continuation_context.get("kind", ""))
		_on_continue_pressed()
		transitions += 1
		if (
			_continuation_offset == before_offset
			and str(_continuation_context.get("kind", "")) == before_kind
			and _preview_messages.is_empty()
			and _choice_projection.is_empty()
		):
			_catalog_playback_autodriving = false
			_catalog_playback_active = false
			_catalog_playback_request.clear()
			return {"ok": false, "error": "Catalog playback made no progress at an internal boundary."}
	_catalog_playback_autodriving = false
	if _catalog_terminal_rejected_completion:
		_catalog_playback_active = false
		status_label.text = "Catalog playback rejected a changed terminal contract; switch to Analysis."
		return {
			"ok": false,
			"error": str(_catalog_terminal_match.get("error", "Catalog terminal observation changed.")),
		}
	if (
		transitions >= max_transitions
		and _continuation_offset >= 0
		and _preview_messages.is_empty()
		and _choice_projection.is_empty()
	):
		_catalog_playback_active = false
		_catalog_playback_request.clear()
		status_label.text = "Catalog playback stopped after too many internal transitions; switch to Analysis."
		return {"ok": false, "error": "Catalog playback exceeded its bounded internal-transition limit."}
	if (
		_continuation_offset < 0
		and _preview_messages.is_empty()
		and _choice_projection.is_empty()
		and not _preview_event_complete
	):
		_catalog_playback_active = false
		_catalog_playback_request.clear()
		status_label.text = "Catalog playback stopped at an unresolved boundary; switch to Analysis."
		return {
			"ok": false,
			"error": "Catalog playback reached an unresolved %s boundary." % (
				_preview_result_status if not _preview_result_status.is_empty() else "runtime"
			),
		}
	return {
		"ok": true,
		"transitions": transitions,
		"user_boundary": (
			"choice" if not _choice_projection.is_empty()
			else "dialogue" if not _preview_messages.is_empty()
			else "terminal" if _continuation_offset < 0
			else "analysis"
		),
	}


func _run_library_and_resume(resume_offset: int, runtime_context: Dictionary) -> void:
	if _library_document.is_empty() or _library_index.is_empty():
		status_label.text = "Shared library content is unavailable."
		return
	var before := _state.snapshot()
	var library_context := {
		"argument_slots": runtime_context.get("argument_slots", {}).duplicate(true),
		"persistent_expression_stack": runtime_context.get("persistent_expression_stack", []).duplicate(),
	}
	if bool(runtime_context.get("allow_audited_registered_def", false)):
		var registered_definitions := _audited_startup_registered_definitions()
		if registered_definitions.is_empty() or not registered_definitions.has(26):
			status_label.text = "Audited startup context is unavailable; original hashes or overlay priority differ."
			return
		library_context["registered_definitions"] = registered_definitions
	var library_result := MesLibraryRunnerScript.new().run(
		_library_document.bytecode,
		_library_index,
		int(runtime_context.get("routine_id", -1)),
		_state,
		library_context
	)
	if not library_result.ok:
		var boundary_result := _event_result_from_library_boundary(library_result, before)
		boundary_result["library_caller_resume_offset"] = resume_offset
		boundary_result["library_caller_binding"] = _library_caller_binding(resume_offset)
		boundary_result["library_registered_definition_mode"] = bool(
			runtime_context.get("allow_audited_registered_def", false)
		)
		_show_result(boundary_result, resume_offset)
		return
	_finish_library_and_resume(library_result, resume_offset, before, runtime_context)


func _resume_library_and_resume(resume_offset: int, runtime_context: Dictionary) -> void:
	if _library_document.is_empty() or _library_index.is_empty():
		status_label.text = "Shared library content is unavailable."
		return
	var continuation_value = runtime_context.get("library_frame_continuation", null)
	if not continuation_value is Dictionary:
		status_label.text = "Shared-library dialogue continuation is unavailable."
		return
	if runtime_context.get("library_caller_binding", {}) != _library_caller_binding(resume_offset):
		status_label.text = "Shared-library MES caller changed before continuation."
		return
	var library_context := {}
	if bool(runtime_context.get("allow_audited_registered_def", false)):
		var registered_definitions := _audited_startup_registered_definitions()
		if registered_definitions.is_empty() or not registered_definitions.has(26):
			status_label.text = "Audited startup context is unavailable; original hashes or overlay priority differ."
			return
		library_context["registered_definitions"] = registered_definitions
	var before := _state.snapshot()
	var library_result := MesLibraryRunnerScript.new().resume(
		_library_document.bytecode,
		_library_index,
		continuation_value,
		_state,
		library_context
	)
	if not library_result.get("ok", false):
		var boundary_result := _event_result_from_library_boundary(library_result, before)
		boundary_result["library_caller_resume_offset"] = resume_offset
		boundary_result["library_caller_binding"] = _library_caller_binding(resume_offset)
		boundary_result["library_registered_definition_mode"] = bool(
			runtime_context.get("allow_audited_registered_def", false)
		)
		_show_result(boundary_result, resume_offset)
		return
	_finish_library_and_resume(library_result, resume_offset, before, runtime_context)


func _library_caller_binding(resume_offset: int) -> Dictionary:
	var bytecode_value = _document.get("bytecode", null)
	return {
		"entry": _selected_entry,
		"entry_sha256": str(_document.get("entry_sha256", "")),
		"bytecode_sha256": ContractValues.sha256(bytecode_value) if bytecode_value is PackedByteArray else "",
		"code_size": int(_document.get("header", {}).get("code_size", -1)),
		"resume_offset": resume_offset,
	}


func _finish_library_and_resume(
	library_result: Dictionary,
	resume_offset: int,
	before: Dictionary,
	runtime_context := {}
) -> Dictionary:
	var preview_context := {
		"argument_slots": library_result.get("argument_slots", {}).duplicate(true),
		"persistent_expression_stack": library_result.get("persistent_expression_stack", []).duplicate(),
		"protagonist_name": protagonist_name_edit.text,
		"address_table_offsets": _document.get("header", {}).get("entry_offsets", []).duplicate(),
	}
	if runtime_context is Dictionary and str(runtime_context.get("native_record_policy", "")) == "omit_bounded":
		preview_context["native_record_policy"] = "omit_bounded"
	var result := _runner.run(
		_document.bytecode,
		resume_offset,
		_state,
		int(_document.header.code_size),
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		preview_context
	)
	var merged_trace: Array[Dictionary] = []
	for untyped_record in library_result.trace:
		var record: Dictionary = untyped_record.duplicate(true)
		if library_result.has("argument_alias_projection"):
			record["source_entry"] = "LIBLARY.LIB"
			record["argument_alias_projection"] = str(library_result.argument_alias_projection)
		record["step"] = merged_trace.size()
		merged_trace.append(record)
	for untyped_record in result.trace:
		var record: Dictionary = untyped_record.duplicate(true)
		record["step"] = merged_trace.size()
		merged_trace.append(record)
	var merged_messages: Array[Dictionary] = []
	for untyped_message in library_result.messages:
		merged_messages.append((untyped_message as Dictionary).duplicate(true))
	for untyped_message in result.messages:
		merged_messages.append((untyped_message as Dictionary).duplicate(true))
	result["trace"] = merged_trace
	result["messages"] = merged_messages
	result["state_diff"] = _state.diff(before)
	result["library_continuation"] = {
		"routine_id": int(library_result.routine_id),
		"trace_count": (library_result.trace as Array).size(),
		"call_count": (library_result.calls as Array).size(),
		"omitted_native_presentation_count": int(library_result.omitted_native_presentation_count),
		"omitted_native_record_count": int(library_result.get("omitted_native_record_count", 0)),
		"decoded_surface_operation_count": int(library_result.get("decoded_surface_operation_count", 0)),
		"decoded_surface_display_refresh_count": int(library_result.get("decoded_surface_display_refresh_count", 0)),
		"unresolved_surface_dispatch_count": int(library_result.get("unresolved_surface_dispatch_count", 0)),
		"state_diff": library_result.state_diff.duplicate(true),
		"external_definition_trace_count": (library_result.trace as Array).filter(
			func(record: Dictionary) -> bool: return record.has("external_definition_id")
		).size(),
	}
	if _preview_event_session == "promise_date":
		var route := _confirmed_event_start()
		if str(route.get("event_start_kind", "")) == PROMISE_DATE_ROUTE_KIND:
			result["promise_date_route"] = {
				"entry": _selected_entry,
				"intro": int(route.offset),
				"routine": int(library_result.routine_id),
				"writer": int(route.writer),
				"field": int(route.field),
				"input_date": _state.read_value("state_u16", 7),
				"output_date": _state.read_value("banked_u16", int(route.field), 0),
				"outer_caller_resolved": false,
			}
	_show_result(result, resume_offset)
	return result

func _event_result_from_library_boundary(library_result: Dictionary, before: Dictionary) -> Dictionary:
	var trace: Array = library_result.get("trace", [])
	var offset := -1
	if not trace.is_empty():
		offset = int(trace[-1].get("source_offset", -1))
	var result := {
		"ok": false,
		"schema": ContentCoreVersionScript.MES_EVENT_TRACE_SCHEMA,
		"status": str(library_result.status),
		"offset": offset,
		"trace": trace.duplicate(true),
		"messages": library_result.get("messages", []).duplicate(true),
		"state_diff": _state.diff(before),
		"error": str(library_result.get("error", "Shared library execution stopped.")),
		"argument_slots": library_result.get("argument_slots", {}).duplicate(true),
		"persistent_expression_stack": library_result.get("persistent_expression_stack", []).duplicate(),
		"library_continuation": {
			"routine_id": int(library_result.routine_id),
			"trace_count": trace.size(),
			"call_count": (library_result.get("calls", []) as Array).size(),
			"omitted_native_presentation_count": int(library_result.get("omitted_native_presentation_count", 0)),
			"omitted_native_record_count": int(library_result.get("omitted_native_record_count", 0)),
			"decoded_surface_operation_count": int(library_result.get("decoded_surface_operation_count", 0)),
			"decoded_surface_display_refresh_count": int(library_result.get("decoded_surface_display_refresh_count", 0)),
			"unresolved_surface_dispatch_count": int(library_result.get("unresolved_surface_dispatch_count", 0)),
			"state_diff": library_result.get("state_diff", []).duplicate(true),
		},
	}
	var continuation_value = library_result.get("continuation", null)
	if continuation_value is Dictionary:
		result["library_frame_continuation"] = (continuation_value as Dictionary).duplicate(true)
	if library_result.has("resume_offset"):
		result["resume_offset"] = int(library_result.resume_offset)
	return result


func _run_from_offset(start_offset: int, runtime_context := {}) -> void:
	var preview_context: Dictionary = runtime_context.duplicate(true)
	preview_context["protagonist_name"] = protagonist_name_edit.text
	preview_context["address_table_offsets"] = _document.get("header", {}).get("entry_offsets", []).duplicate()
	var result := _runner.run(
		_document.bytecode,
		start_offset,
		_state,
		int(_document.header.code_size),
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		preview_context
	)
	_attach_registered_definition_context(result, _audited_startup_registered_definitions())
	_show_result(result, start_offset)


func _attach_registered_definition_context(result: Dictionary, registry: Dictionary) -> void:
	if str(result.get("status", "")) != "definition_invoke_boundary" or registry.is_empty():
		return
	var trace: Array = result.get("trace", [])
	var terminal: Dictionary = trace[-1] if not trace.is_empty() else {}
	var definition_id := int(terminal.get("definition_id", -1))
	var start_offset := int(result.get("offset", -1))
	if not registry.has(definition_id) or start_offset < 0:
		return
	result["registered_definition_registry"] = registry.duplicate(true)
	result["registered_definition_id"] = definition_id
	result["registered_definition_controller_binding"] = _registered_definition_controller_binding(start_offset)


func _registered_definition_controller_binding(start_offset: int) -> Dictionary:
	var bytecode_value = _document.get("bytecode", null)
	return {
		"entry": _selected_entry,
		"entry_sha256": str(_document.get("entry_sha256", "")),
		"bytecode_sha256": ContractValues.sha256(bytecode_value) if bytecode_value is PackedByteArray else "",
		"code_size": int(_document.get("header", {}).get("code_size", -1)),
		"start_offset": start_offset,
		"address_table_offsets": _document.get("header", {}).get("entry_offsets", []).duplicate(),
	}


func _run_registered_definition_frame(start_offset: int, runtime_context: Dictionary) -> void:
	var registry_value = runtime_context.get("registered_definition_registry", null)
	var binding_value = runtime_context.get("registered_definition_controller_binding", null)
	if not registry_value is Dictionary or not binding_value is Dictionary:
		status_label.text = "Registered-DEF continuation context is unavailable."
		return
	if binding_value != _registered_definition_controller_binding(start_offset):
		status_label.text = "Registered-DEF MES caller changed before continuation."
		return
	var registry: Dictionary = (registry_value as Dictionary).duplicate(true)
	var runner := MesRegisteredDefinitionRunnerScript.new()
	var before := _state.snapshot()
	var result: Dictionary
	if str(runtime_context.get("kind", "")) == "registered_definition_dialogue":
		var continuation_value = runtime_context.get("registered_definition_continuation", null)
		if not continuation_value is Dictionary:
			status_label.text = "Registered-DEF dialogue continuation is unavailable."
			return
		result = runner.resume(
			_document.bytecode,
			continuation_value,
			_state,
			{
				"registered_definitions": registry,
				"address_table_offsets": _document.get("header", {}).get("entry_offsets", []).duplicate(),
			}
		)
	else:
		result = runner.run(
			_document.bytecode,
			start_offset,
			_state,
			int(_document.header.code_size),
			{
				"registered_definitions": registry,
				"address_table_offsets": _document.get("header", {}).get("entry_offsets", []).duplicate(),
				"argument_slots": runtime_context.get("argument_slots", {}).duplicate(true),
				"persistent_expression_stack": runtime_context.get("persistent_expression_stack", []).duplicate(),
				"registered_definition_native_stream_policy": "stop",
				"registered_definition_native_record_policy": "omit_bounded",
			}
		)
	result["state_diff"] = _state.diff(before)
	result["registered_definition_registry"] = registry
	result["registered_definition_controller_binding"] = (binding_value as Dictionary).duplicate(true)
	_show_result(result, start_offset)


func _run_nested_promise_route(choice_id := -1) -> void:
	if _nested_promise_context.is_empty():
		status_label.text = "The audited nested conversation context is unavailable."
		return
	var base_state_value = _nested_promise_context.get("base_state", {})
	if not base_state_value is Dictionary:
		status_label.text = "The nested conversation sandbox baseline is invalid."
		return
	_state.restore(base_state_value)
	var run_context := {
		"dialogue_policy": "continue",
		"native_stream_policy": "skip_bounded",
		"protagonist_name": protagonist_name_edit.text,
	}
	if choice_id >= 0:
		run_context["local_definition_choices"] = [choice_id]
	var result := _script_call_runner.run(
		_nested_promise_context.get("scripts", {}),
		str(_nested_promise_context.get("root_entry", "")),
		int(_nested_promise_context.get("route", {}).get("intro", -1)),
		_state,
		run_context,
		20000,
		32,
		8
	)
	var validation := _validate_nested_promise_result(result, choice_id)
	result["nested_promise_validation"] = validation.duplicate(true)
	result["nested_promise_choice_id"] = choice_id
	_nested_promise_reached_boundary = choice_id >= 0 and validation.get("ok", false)
	_sync_state_json()
	_show_result(result, int(_nested_promise_context.get("route", {}).get("intro", -1)))
	if not validation.get("ok", false):
		status_label.text = "Nested conversation stopped outside its audited envelope: %s" % str(validation.get("error", "unknown boundary"))


func _validate_nested_promise_result(result: Dictionary, choice_id: int) -> Dictionary:
	if _nested_promise_context.is_empty():
		return {"ok": false, "error": "missing route context"}
	var route: Dictionary = _nested_promise_context.get("route", {})
	var root_entry := str(_nested_promise_context.get("root_entry", ""))
	var calls: Array = result.get("script_calls", [])
	if calls.size() != 1:
		return {"ok": false, "error": "nested call count changed"}
	var call: Dictionary = calls[0]
	if (
		str(call.get("caller_entry", "")) != root_entry
		or str(call.get("callee_entry", "")) != NESTED_PROMISE_TALK_ENTRY
		or int(call.get("call_offset", -1)) != int(route.get("talk_call", -2))
		or int(call.get("resume_offset", -1)) != int(route.get("talk_resume", -2))
	):
		return {"ok": false, "error": "nested call/caller coordinates changed"}
	var trace: Array = result.get("trace", [])
	if choice_id < 0:
		var ids: Array[int] = []
		var offsets: Array[int] = []
		var targets: Array[int] = []
		for untyped_definition in result.get("definitions", []):
			var definition: Dictionary = untyped_definition
			ids.append(int(definition.get("definition_id", -1)))
			offsets.append(int(definition.get("source_offset", -1)))
			targets.append(int(definition.get("target_offset", -1)))
		if (
			not result.get("ok", false)
			or str(result.get("status", "")) != "def_selection_boundary"
			or str(result.get("current_entry", "")) != NESTED_PROMISE_TALK_ENTRY
			or int(result.get("offset", -1)) != NESTED_PROMISE_TALK_CHOICE_BOUNDARY
			or call.get("returned", false)
			or ids != NESTED_PROMISE_DEFINITION_IDS
			or offsets != NESTED_PROMISE_DEFINITION_OFFSETS
			or targets != NESTED_PROMISE_DEFINITION_TARGETS
			or (result.get("messages", []) as Array).size() != 1
		):
			return {"ok": false, "error": "nested local-choice boundary changed"}
		return {"ok": true, "phase": "choice"}
	if choice_id not in NESTED_PROMISE_DEFINITION_IDS:
		return {"ok": false, "error": "choice ID is outside the audited pair"}
	var selection := KakyuEventPlayerRules.nested_trace_at(trace, NESTED_PROMISE_TALK_ENTRY, NESTED_PROMISE_TALK_CHOICE_BOUNDARY)
	var gate := KakyuEventPlayerRules.nested_trace_at(trace, root_entry, int(route.get("promise_gate", -1)))
	var terminal: Dictionary = trace[-1] if not trace.is_empty() else {}
	var expected_return := 0x0284 if choice_id == 0 else 0x02C1
	if (
		result.get("ok", true)
		or str(result.get("status", "")) != "script_dispatch_boundary"
		or str(result.get("current_entry", "")) != root_entry
		or int(result.get("offset", -1)) != int(route.get("promise_call", -2))
		or not call.get("returned", false)
		or int(call.get("return_offset", -1)) != expected_return
		or str(selection.get("selection_policy", "")) != "explicit_tool_choice"
		or int(selection.get("selected_definition_id", -1)) != choice_id
		or int(gate.get("condition_value", -1)) != 1
		or str(gate.get("effect", "")) != "fallthrough"
		or str(terminal.get("target_entry", "")).to_upper() != "L_PROMIS.MES"
		or (result.get("messages", []) as Array).size() != 2
	):
		return {"ok": false, "error": "restored PROMIS dispatch route changed"}
	return {"ok": true, "phase": "promise_boundary", "choice_id": choice_id}


func _clear_continuation() -> void:
	_continuation_offset = -1
	_continuation_context.clear()
	if is_instance_valid(continue_button):
		continue_button.disabled = true
		continue_button.text = "Continue"


func _clear_choice_projection() -> void:
	_choice_projection.clear()
	_choice_index = -1


func _capture_continuation(result: Dictionary) -> void:
	_clear_continuation()
	var status := str(result.get("status", ""))
	if status == "library_dialogue_boundary":
		var library_frame_value = result.get("library_frame_continuation", null)
		var library_caller_resume := int(result.get("library_caller_resume_offset", -1))
		var library_caller_binding_value = result.get("library_caller_binding", null)
		if (
			not library_frame_value is Dictionary
			or not library_caller_binding_value is Dictionary
			or str((library_frame_value as Dictionary).get("schema", "")) != ContentCoreVersionScript.MES_LIBRARY_CONTINUATION_SCHEMA
			or library_caller_resume < 0
			or library_caller_resume >= int(_document.get("header", {}).get("code_size", 0))
			or library_caller_binding_value != _library_caller_binding(library_caller_resume)
		):
			return
		_continuation_offset = library_caller_resume
		_continuation_context = {
			"kind": "library_dialogue",
			"library_frame_continuation": (library_frame_value as Dictionary).duplicate(true),
			"library_caller_binding": (library_caller_binding_value as Dictionary).duplicate(true),
			"allow_audited_registered_def": bool(
				result.get("library_registered_definition_mode", false)
			),
		}
		continue_button.disabled = false
		continue_button.text = "Continue Library Dialogue"
		return
	if status == "registered_definition_dialogue_boundary":
		var registry_value = result.get("registered_definition_registry", null)
		var binding_value = result.get("registered_definition_controller_binding", null)
		var continuation_value = result.get("continuation", null)
		if not continuation_value is Dictionary:
			return
		var start_offset := int((continuation_value as Dictionary).get("root_start_offset", -1))
		if (
			not registry_value is Dictionary
			or not binding_value is Dictionary
			or start_offset < 0
			or binding_value != _registered_definition_controller_binding(start_offset)
		):
			return
		var registry: Dictionary = (registry_value as Dictionary).duplicate(true)
		var continuation: Dictionary = result.get("continuation", {})
		if str(continuation.get("schema", "")) != ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CONTINUATION_SCHEMA:
			return
		_continuation_context = {
			"kind": "registered_definition_dialogue",
			"registered_definition_continuation": continuation.duplicate(true),
		}
		continue_button.text = "Continue Registered DEF Dialogue"
		_continuation_offset = start_offset
		_continuation_context["registered_definition_registry"] = registry
		_continuation_context["registered_definition_controller_binding"] = (binding_value as Dictionary).duplicate(true)
		continue_button.disabled = false
		return
	if not _catalog_setup_extension_terminal(result).is_empty():
		return
	if _is_catalog_setup_extension_terminal_candidate(result) or _is_catalog_setup_extension_phase_result(result):
		return
	if status == "shared_routine_boundary":
		var shared_boundary := _shared_routine_boundary(result)
		var shared_resume := int(result.get("resume_offset", -1))
		if shared_boundary.is_empty() or shared_resume < 0 or shared_resume >= int(_document.get("header", {}).get("code_size", 0)):
			return
		_continuation_offset = shared_resume
		_continuation_context = {
			"kind": "shared_library",
			"routine_id": int(shared_boundary.routine_id),
			"argument_slots": result.get("argument_slots", {}).duplicate(true),
			"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
		}
		continue_button.disabled = false
		return
	var catalog_setup_native_resume := _catalog_setup_native_stream_resume(result)
	if catalog_setup_native_resume >= 0:
		_continuation_offset = catalog_setup_native_resume
		_continuation_context = {
			"kind": "catalog_setup_native_records_omitted" if status == "native_record_boundary" else "catalog_setup_native_presentation_omitted",
			"argument_slots": result.get("argument_slots", {}).duplicate(true),
			"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
		}
		_continuation_context[
			"native_record_policy" if status == "native_record_boundary" else "native_stream_policy"
		] = "omit_bounded" if status == "native_record_boundary" else "skip_bounded"
		continue_button.disabled = false
		continue_button.text = "Continue (Omit Setup Records)" if status == "native_record_boundary" else "Continue (Omit Setup FX)"
		return
	if _preview_event_session == "catalog_setup" and status in ["native_presentation_boundary", "native_record_boundary"]:
		return
	var def26_native_resume := _def26_native_stream_resume(result)
	if def26_native_resume >= 0:
		_continuation_offset = def26_native_resume
		_continuation_context = {
			"kind": "def26_native_records_omitted",
			"native_record_policy": "omit_bounded",
			"argument_slots": result.get("argument_slots", {}).duplicate(true),
			"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
		}
		continue_button.disabled = false
		continue_button.text = "Continue (Omit Body Records)"
		return
	if status in ["native_presentation_boundary", "native_record_boundary"]:
		return
	var eventd14_definition_resume := _evidence().catalog_setup_definition_resume(result)
	if not eventd14_definition_resume.is_empty():
		_continuation_offset = int(eventd14_definition_resume.resume)
		_continuation_context = {
			"kind": "catalog_setup_registered_definition",
			"definition_id": int(eventd14_definition_resume.definition_id),
			"argument_slots": result.get("argument_slots", {}).duplicate(true),
			"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
		}
		continue_button.disabled = false
		continue_button.text = "Continue (Run %s DEF %d)" % [
			"Setup" if _preview_event_session == "catalog_setup" else "Event",
			int(eventd14_definition_resume.definition_id),
		]
		return
	if status == "definition_invoke_boundary":
		var registry_value = result.get("registered_definition_registry", null)
		var binding_value = result.get("registered_definition_controller_binding", null)
		var start_offset := int(result.get("offset", -1))
		var definition_id := int(result.get("registered_definition_id", -1))
		if (
			not registry_value is Dictionary
			or not binding_value is Dictionary
			or start_offset < 0
			or not (registry_value as Dictionary).has(definition_id)
			or binding_value != _registered_definition_controller_binding(start_offset)
		):
			return
		_continuation_offset = start_offset
		_continuation_context = {
			"kind": "registered_definition_start",
			"registered_definition_id": definition_id,
			"registered_definition_registry": (registry_value as Dictionary).duplicate(true),
			"registered_definition_controller_binding": (binding_value as Dictionary).duplicate(true),
			"argument_slots": result.get("argument_slots", {}).duplicate(true),
			"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
		}
		continue_button.disabled = false
		continue_button.text = "Continue (Run Registered DEF)"
		return
	if status == "library_definition_invoke_boundary":
		var trace: Array = result.get("trace", [])
		var caller_resume := int(result.get("library_caller_resume_offset", -1))
		var definition_id := int(trace[-1].get("definition_id", -1)) if not trace.is_empty() else -1
		if (
			definition_id != 26
			or caller_resume < 0
			or caller_resume >= int(_document.get("header", {}).get("code_size", 0))
			or _audited_def26_registered_definition().is_empty()
		):
			return
		var library_continuation: Dictionary = result.get("library_continuation", {})
		_continuation_offset = caller_resume
		_continuation_context = {
			"kind": "registered_def_library",
			"routine_id": int(library_continuation.get("routine_id", -1)),
			"allow_audited_registered_def": true,
			"argument_slots": result.get("argument_slots", {}).duplicate(true),
			"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
		}
		continue_button.disabled = false
		return
	if status != "dialogue_boundary":
		return
	var resume_offset := int(result.get("resume_offset", -1))
	if resume_offset < 0 or resume_offset >= int(_document.get("header", {}).get("code_size", 0)):
		return
	_continuation_offset = resume_offset
	_continuation_context = {
		"kind": "dialogue",
		"argument_slots": result.get("argument_slots", {}).duplicate(true),
		"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
	}
	continue_button.disabled = false


func _catalog_setup_native_stream_resume(result: Dictionary) -> int:
	var definition := _confirmed_address_catalog(_selected_entry, str(_document.get("entry_sha256", "")))
	if (
		_preview_event_session != "catalog_setup"
		or definition.is_empty()
		or str(_document.get("source", {}).get("resolved_source", "")) != "original_arc"
		or not _active_address_catalog.get("ok", false)
		or int(_active_address_catalog.get("setup_native_offset", -1)) != int(definition.get("setup_native_offset", -2))
		or int(_active_address_catalog.get("setup_native_resume", -1)) != int(definition.get("setup_native_resume", -2))
		or str(_active_address_catalog.get("setup_terminal_status", "")) != str(definition.get("setup_terminal_status", "missing"))
		or int(_active_address_catalog.get("setup_terminal_offset", -1)) != int(definition.get("setup_terminal_offset", -2))
	):
		return -1
	var trace: Array = result.get("trace", [])
	if trace.is_empty():
		return -1
	var record: Dictionary = trace[-1]
	if str(result.get("status", "")) == "native_presentation_boundary":
		var probe: Dictionary = record.get("native_stream_probe", {})
		for untyped_boundary in definition.get("setup_native_presentation_boundaries", []):
			var boundary: Dictionary = untyped_boundary
			if (
				int(result.get("offset", -1)) == int(boundary.get("offset", -2))
				and int(result.get("command_id", -1)) == int(boundary.get("command_id", -2))
				and int(record.get("source_offset", -1)) == int(boundary.get("offset", -2))
				and int(record.get("command_id", -1)) == int(boundary.get("command_id", -2))
				and int(probe.get("consumed_byte_count", -1)) == int(boundary.get("consumed_byte_count", -2))
				and int(probe.get("probe_end_offset", -1)) == int(boundary.get("resume", -2))
				and str(probe.get("stop_reason", "")) == "nul_consumed"
			):
				return int(boundary.resume)
		return -1
	if (
		str(result.get("status", "")) != "native_record_boundary"
		or int(result.get("offset", -1)) != int(definition.get("setup_native_offset", -1))
		or int(result.get("command_id", -1)) != 0x12
		or int(record.get("command_id", -1)) != 0x12
		or int(record.get("source_offset", -1)) != int(definition.setup_native_offset)
		or int(record.get("end_offset", -1)) != int(definition.setup_native_resume)
		or str(record.get("effect", "")) != "native_record_boundary"
		or str(record.get("native_record_consumption", "")) != "typed_record_list_until_zero"
		or int(record.get("native_record_count", -1)) != int(definition.get("setup_native_record_count", -2))
		or not bool(record.get("native_record_terminator_consumed", false))
	):
		return -1
	return int(definition.setup_native_resume)


func _catalog_setup_extension_terminal(result: Dictionary) -> Dictionary:
	var definition := _confirmed_address_catalog(_selected_entry, str(_document.get("entry_sha256", "")))
	if (
		_preview_event_session != "catalog_setup"
		or definition.is_empty()
		or str(_document.get("source", {}).get("resolved_source", "")) != "original_arc"
		or not _active_address_catalog.get("ok", false)
		or str(_active_address_catalog.get("setup_extension_mmo", "")) != str(definition.get("setup_extension_mmo", "missing"))
		or _active_address_catalog.get("setup_extension_terminals", []) != definition.get("setup_extension_terminals", [])
	):
		return {}
	var shared_boundary := _shared_routine_boundary(result)
	var trace: Array = result.get("trace", [])
	if shared_boundary.is_empty() or trace.is_empty():
		return {}
	var terminal_trace: Dictionary = trace[-1]
	for untyped_terminal in definition.get("setup_extension_terminals", []):
		var terminal: Dictionary = untyped_terminal
		if (
			str(result.get("status", "")) == str(terminal.get("status", "missing"))
			and int(result.get("offset", -1)) == int(terminal.get("offset", -2))
			and int(result.get("resume_offset", -1)) == int(terminal.get("resume", -2))
			and int(shared_boundary.get("routine_id", -1)) == int(terminal.get("routine_id", -2))
			and int(terminal_trace.get("source_offset", -1)) == int(terminal.get("offset", -2))
			and int(terminal_trace.get("routine_id", -1)) == int(terminal.get("routine_id", -2))
			and _state.read_value("global_u8", 4000) == int(terminal.get("branch_global_u8_4000", -1))
		):
			var matched := terminal.duplicate(true)
			matched["mmo"] = str(definition.get("setup_extension_mmo", ""))
			return matched
	return {}


func _is_catalog_setup_extension_terminal_candidate(result: Dictionary) -> bool:
	if _preview_event_session != "catalog_setup":
		return false
	var definition: Dictionary = KakyuEventPlayerEvidence.CONFIRMED_ADDRESS_CATALOGS.get(_selected_entry.to_upper(), {})
	for untyped_terminal in definition.get("setup_extension_terminals", []):
		var terminal: Dictionary = untyped_terminal
		if (
			str(result.get("status", "")) == str(terminal.get("status", "missing"))
			and int(result.get("offset", -1)) == int(terminal.get("offset", -2))
		):
			return true
	return false


func _is_catalog_setup_extension_phase_result(result: Dictionary) -> bool:
	if (
		_preview_event_session != "catalog_setup"
		or not _preview_catalog_setup_native_fx_omitted
		or _selected_entry.to_upper() != "EVENTD06.MES"
		or str(result.get("status", "")) != "shared_routine_boundary"
	):
		return false
	for untyped_trace in result.get("trace", []):
		var trace: Dictionary = untyped_trace
		if str(trace.get("effect", "")) == "mmo_resource_marker" and str(trace.get("resource_name", "")).to_upper() == "D07.MMO":
			return true
	return false


func _def26_native_stream_resume(result: Dictionary) -> int:
	var anchor := _confirmed_event_start()
	if (
		_preview_event_session != "def26_isolated_body"
		or _selected_entry != "DEF_MAIN.MES"
		or not _is_catalog_source_entry(str(_document.get("entry_sha256", "")), "DEF_MAIN.MES")
		or str(anchor.get("event_start_kind", "")) != "isolated_body"
		or int(anchor.get("offset", -1)) != AUDITED_DEF26_BODY_OFFSET
		or str(result.get("status", "")) != "native_record_boundary"
		or int(result.get("offset", -1)) != 0x0208
		or int(result.get("command_id", -1)) != 0x12
	):
		return -1
	var trace: Array = result.get("trace", [])
	if trace.is_empty():
		return -1
	var record: Dictionary = trace[-1]
	if (
		int(record.get("command_id", -1)) != 0x12
		or int(record.get("source_offset", -1)) != 0x0208
		or int(record.get("end_offset", -1)) != 0x0216
		or str(record.get("effect", "")) != "native_record_boundary"
		or str(record.get("native_record_consumption", "")) != "typed_record_list_until_zero"
		or int(record.get("native_record_count", -1)) != 4
		or not bool(record.get("native_record_terminator_consumed", false))
	):
		return -1
	return 0x0216


func _catalog_source_entry_sha256(entry: String) -> String:
	return _evidence().catalog_source_entry_sha256(entry)


func _is_catalog_source_entry(entry_sha256: String, entry: String) -> bool:
	return _evidence().is_catalog_source_entry(entry_sha256, entry)


func _shared_routine_boundary(result: Dictionary) -> Dictionary:
	if str(result.get("status", "")) != "shared_routine_boundary" or result.get("trace", []).is_empty():
		return {}
	var trace: Dictionary = result.trace[-1]
	if int(trace.get("command_id", -1)) != 0x1D:
		return {}
	var routine_id := int(trace.get("routine_id", -1))
	return _indexed_routine_boundary(routine_id, "execution_boundary")


func _indexed_routine_boundary(routine_id: int, panel_role: String) -> Dictionary:
	return _evidence().indexed_routine_boundary(routine_id, panel_role)


func _routine40_selection_provenance(result: Dictionary) -> Dictionary:
	if str(result.get("status", "")) != "def_selection_boundary":
		return {}
	var trace: Array = result.get("trace", [])
	if trace.is_empty():
		return {}
	var terminal: Dictionary = trace[-1]
	if int(terminal.get("command_id", -1)) != 0x1D or int(terminal.get("routine_id", -1)) != 40:
		return {}
	var provenance := {
		"routine_id": 40,
		"native_dispatch_audited": false,
		"authoritative": false,
		"native_record_offsets": [],
		"reached_command15_offsets": [],
	}
	if _library_document.is_empty() or _library_index.is_empty():
		return provenance
	var routine: Dictionary = _library_index.get("by_id", {}).get(40, {})
	if routine.is_empty():
		return provenance
	var audit := MesLibraryAuditScript.new().audit(
		_library_document.get("bytecode", PackedByteArray()),
		_library_index,
		[40] as Array[int]
	)
	if not audit.get("ok", false) or (audit.get("routines", []) as Array).size() != 1:
		return provenance
	var audited_routine: Dictionary = audit.routines[0]
	var flow: Dictionary = audited_routine.get("native_dispatch_flow", {})
	var native_record_offsets: Array[int] = []
	for untyped_span in flow.get("native_spans", []):
		var span: Dictionary = untyped_span
		if str(span.get("handler_family", "")) == "native_record_dispatch":
			native_record_offsets.append(int(span.get("source_offset", -1)))
	native_record_offsets.sort()
	var reached_command15_offsets: Array[int] = []
	for untyped_row in flow.get("instructions", []):
		var row: Dictionary = untyped_row
		if int(row.get("command_id", -1)) == 0x15:
			reached_command15_offsets.append(int(row.get("source_offset", -1)))
	reached_command15_offsets.sort()
	provenance.merge({
		"native_dispatch_audited": true,
		"schema": str(audit.get("schema", "")),
		"body_offset": int(audited_routine.get("body_offset", -1)),
		"end_offset": int(audited_routine.get("end_offset", -1)),
		"flow_complete": bool(flow.get("complete", false)),
		"flow_instruction_count": int(flow.get("instruction_count", 0)),
		"flow_edge_count": int(flow.get("edge_count", 0)),
		"native_span_count": (flow.get("native_spans", []) as Array).size(),
		"native_spans": (flow.get("native_spans", []) as Array).duplicate(true),
		"native_record_offsets": native_record_offsets,
		"reached_command15_offsets": reached_command15_offsets,
		"script_envelope_confirmed": KakyuEventPlayerRules.matches_audited_routine40_script_envelope(flow),
		"native_span_envelope_confirmed": KakyuEventPlayerRules.matches_audited_routine40_native_spans(flow.get("native_spans", [])),
	}, true)
	provenance["authoritative"] = (
		_reader.is_open()
		and _reader.get_archive_identity_fingerprint() == KakyuEventPlayerEvidence.AUDITED_MES_ARCHIVE_SHA256
		and str(_library_index.get("source", "")) == "original_arc"
		and _is_catalog_source_entry(str(_library_index.get("entry_sha256", "")), "LIBLARY.LIB")
		and str(audit.get("schema", "")) == ContentCoreVersionScript.MES_LIBRARY_AUDIT_SCHEMA
		and int(provenance.body_offset) == AUDITED_ROUTINE40_BODY_OFFSET
		and int(provenance.end_offset) == AUDITED_ROUTINE40_END_OFFSET
		and bool(provenance.flow_complete)
		and int(provenance.flow_instruction_count) == 35
		and int(provenance.flow_edge_count) == 39
		and int(provenance.native_span_count) == 2
		and bool(provenance.script_envelope_confirmed)
		and bool(provenance.native_span_envelope_confirmed)
		and provenance.native_record_offsets == AUDITED_ROUTINE40_NATIVE_RECORD_OFFSETS
		and (provenance.reached_command15_offsets as Array).is_empty()
	)
	return provenance


func _hex_offset_list(offsets: Array) -> String:
	var parts: Array[String] = []
	for untyped_offset in offsets:
		parts.append("0x%X" % int(untyped_offset))
	return ", ".join(parts) if not parts.is_empty() else "none"


func _populate_shared_routine_tree(boundary: Dictionary) -> void:
	shared_routine_tree.clear()
	if boundary.is_empty() or _library_document.is_empty():
		return
	var decoder := MesInstructionDecoderScript.new()
	var strict_decoded := decoder.decode_region(
		_library_document.bytecode,
		int(boundary.body_offset),
		int(boundary.end_offset)
	)
	var structural_decoded := decoder.decode_region_structural(
		_library_document.bytecode,
		int(boundary.body_offset),
		int(boundary.end_offset)
	)
	var routine_audit := MesLibraryAuditScript.new().audit(
		_library_document.bytecode,
		_library_index,
		[int(boundary.routine_id)] as Array[int]
	)
	var audited_routine: Dictionary = {}
	if routine_audit.ok and not routine_audit.routines.is_empty():
		audited_routine = routine_audit.routines[0]
	var native_flow: Dictionary = audited_routine.get("native_dispatch_flow", {})
	var unreached_by_offset := {}
	for untyped_unreached in native_flow.get("unreached_structural_instructions", []):
		var unreached: Dictionary = untyped_unreached
		unreached_by_offset[int(unreached.get("source_offset", -1))] = unreached
	var root := shared_routine_tree.create_item()
	var structural_only_count := 0
	for instruction in structural_decoded.instructions:
		var item := shared_routine_tree.create_item(root)
		var structural_only := bool(instruction.get("structural_only", false))
		var native_stream_boundary: bool = instruction.has("native_stream_consumption")
		var unreached: Dictionary = unreached_by_offset.get(int(instruction.source_offset), {})
		var shadowed := str(unreached.get("reason", "")) == "native_payload"
		var control_flow_unreached := str(unreached.get("reason", "")) == "control_flow_not_reached"
		if structural_only:
			structural_only_count += 1
		item.set_text(0, "0x%08X" % int(instruction.source_offset))
		item.set_text(
			1,
			"0x%02X %s%s%s%s%s" % [
				int(instruction.command_id),
				str(instruction.op),
				" [structural only]" if structural_only else "",
				" [native stream boundary]" if native_stream_boundary else "",
				" [inside native payload; not dispatcher]" if shadowed else "",
				" [not reached by native dispatch graph]" if control_flow_unreached else "",
			]
		)
		var detail := _library_instruction_detail(instruction)
		if shadowed:
			var owner: Dictionary = unreached
			detail = "stored-order decode only; consumed by native span 0x%X..0x%X; " % [
				int(owner.owning_span_source_offset),
				int(owner.owning_span_end_offset),
			] + detail
		elif control_flow_unreached:
			detail = "stored-order decode only; no edge in the both-branch native dispatch graph reaches this row; " + detail
		if structural_only:
			var stack_effect := _stack_effect.analyze_instruction(instruction)
			var stack_detail := "persistent stack min %d, delta %+d" % [
				int(stack_effect.minimum_incoming),
				int(stack_effect.net_delta),
			]
			detail = "non-executable expression boundary; " + stack_detail + (
				"; " + detail if not detail.is_empty() else ""
			)
		item.set_text(2, detail)
		item.set_text(3, str(instruction.raw_hex))
		item.set_tooltip_text(3, str(instruction.raw_hex))
	if not structural_decoded.ok:
		var diagnostic := shared_routine_tree.create_item(root)
		diagnostic.set_text(0, "0x%08X" % int(structural_decoded.decoded_end_offset))
		diagnostic.set_text(1, "structural decode stop")
		diagnostic.set_text(2, str(structural_decoded.error))
	shared_routine_tree.set_meta("routine_id", int(boundary.routine_id))
	shared_routine_tree.set_meta("body_offset", int(boundary.body_offset))
	shared_routine_tree.set_meta("end_offset", int(boundary.end_offset))
	shared_routine_tree.set_meta("panel_role", str(boundary.get("panel_role", "manual_audit")))
	shared_routine_tree.set_meta("source", str(boundary.get("source", "resolved content")))
	shared_routine_tree.set_meta("decode_complete", bool(strict_decoded.ok))
	shared_routine_tree.set_meta("instruction_count", strict_decoded.instructions.size())
	shared_routine_tree.set_meta("decoded_end_offset", int(strict_decoded.decoded_end_offset))
	shared_routine_tree.set_meta("decode_error", str(strict_decoded.get("error", "")))
	shared_routine_tree.set_meta("structural_decode_complete", bool(structural_decoded.ok))
	shared_routine_tree.set_meta("structural_instruction_count", structural_decoded.instructions.size())
	shared_routine_tree.set_meta("structural_decoded_end_offset", int(structural_decoded.decoded_end_offset))
	shared_routine_tree.set_meta("structural_decode_error", str(structural_decoded.get("error", "")))
	shared_routine_tree.set_meta("structural_only_instruction_count", structural_only_count)
	shared_routine_tree.set_meta("library_audit_schema", str(routine_audit.get("schema", "")))
	shared_routine_tree.set_meta(
		"native_stream_scope",
		str(audited_routine.get("native_stream_scope", ""))
	)
	shared_routine_tree.set_meta(
		"native_stream_boundaries",
		audited_routine.get("native_stream_boundaries", []).duplicate(true)
	)
	shared_routine_tree.set_meta(
		"native_record_scope",
		str(audited_routine.get("native_record_scope", ""))
	)
	shared_routine_tree.set_meta(
		"native_record_boundaries",
		audited_routine.get("native_record_boundaries", []).duplicate(true)
	)
	shared_routine_tree.set_meta(
		"linear_stack_effect_scope",
		str(audited_routine.get("linear_stack_effect_scope", ""))
	)
	shared_routine_tree.set_meta(
		"return_delimited_segments",
		audited_routine.get("return_delimited_segments", []).duplicate(true)
	)
	shared_routine_tree.set_meta("native_dispatch_flow_complete", bool(native_flow.get("complete", false)))
	shared_routine_tree.set_meta("native_dispatch_instruction_count", int(native_flow.get("instruction_count", 0)))
	shared_routine_tree.set_meta("native_dispatch_edge_count", int(native_flow.get("edge_count", 0)))
	shared_routine_tree.set_meta("native_dispatch_span_count", native_flow.get("native_spans", []).size())
	shared_routine_tree.set_meta("native_dispatch_spans", native_flow.get("native_spans", []).duplicate(true))
	shared_routine_tree.set_meta("native_dispatch_return_count", native_flow.get("return_offsets", []).size())
	shared_routine_tree.set_meta("native_dispatch_boundary_count", native_flow.get("boundaries", []).size())
	shared_routine_tree.set_meta("native_dispatch_failure_count", native_flow.get("failures", []).size())
	shared_routine_tree.set_meta(
		"native_dispatch_shadowed_structural_instructions",
		native_flow.get("shadowed_structural_instructions", []).duplicate(true)
	)
	shared_routine_tree.set_meta(
		"native_dispatch_unreached_structural_instructions",
		native_flow.get("unreached_structural_instructions", []).duplicate(true)
	)
	var native_flow_calls := {}
	var native_flow_writes := {}
	for untyped_row in native_flow.get("instructions", []):
		var flow_row: Dictionary = untyped_row
		if flow_row.has("routine_id"):
			var called_routine := int(flow_row.routine_id)
			native_flow_calls[called_routine] = int(native_flow_calls.get(called_routine, 0)) + 1
		if flow_row.has("write_storage") and flow_row.has("write_start"):
			var signature := "%s[0x%X]x%d" % [
				str(flow_row.write_storage),
				int(flow_row.write_start),
				int(flow_row.write_count),
			]
			native_flow_writes[signature] = int(native_flow_writes.get(signature, 0)) + 1
	shared_routine_tree.set_meta("native_dispatch_calls", native_flow_calls)
	shared_routine_tree.set_meta("native_dispatch_writes", native_flow_writes)
	shared_routine_tree.set_meta(
		"native_def_registrations",
		native_flow.get("definition_registrations", []).duplicate(true)
	)
	shared_routine_tree.set_meta(
		"native_def_invocations",
		native_flow.get("definition_invocations", []).duplicate(true)
	)


func _return_segment_summary(segments: Array) -> String:
	var summaries: Array[String] = []
	for untyped_segment in segments:
		var segment: Dictionary = untyped_segment
		var effect: Dictionary = segment.get("stack_effect", {})
		summaries.append(
			"0x%X..0x%X min %d delta %+d%s"
			% [
				int(segment.get("start_offset", -1)),
				int(segment.get("end_offset", -1)),
				int(effect.get("minimum_incoming", 0)),
				int(effect.get("net_delta", 0)),
				" return" if bool(segment.get("ends_in_return", false)) else " open",
			]
		)
	return "; ".join(summaries)


func _library_instruction_detail(instruction: Dictionary) -> String:
	var native_probe_detail := _native_stream_probe_detail(instruction)
	match str(instruction.op):
		"text", "dispatcher_character_text":
			var decoded := _cp932.decode(instruction.operands[0].raw_bytes)
			var presented_text := str(decoded.text) if decoded.ok else "native pair (not CP932 dialogue)"
			return "%s; %s; projection %s" % [
				presented_text,
				native_probe_detail,
				"matches probe" if bool(instruction.get("native_stream_projection_match", false)) else "crosses probe stop",
			]
		"branch_if_not_true":
			return "false -> 0x%X" % int(instruction.operands[1].value)
		"continuation_transfer", "bootstrap_transfer", "library_register_skip":
			return "target 0x%X" % int(instruction.operands[-1].value)
		"script_transfer":
			var routine_id := KakyuEventPlayerRules.instruction_literal_record(instruction)
			return "shared routine %d" % routine_id if routine_id >= 0 else "nonliteral shared routine"
		"script_dispatch":
			return "%s; nested target execution and caller restoration unresolved" % str(instruction.script_target)
		"named_state_transfer":
			var transfer_operand: Dictionary = instruction.get("operands", [{}])[0]
			return "selector %d; relative offsets %s; host record/physical aliases unresolved" % [
				int(transfer_operand.get("transfer_selector", -1)),
				str(transfer_operand.get("mapping_string", "?")),
			]
		"global_u8_write_run":
			return "global_u8[%d]" % int(instruction.operands[0].value)
		"banked_u16_write_run", "banked_i32_write_run":
			return "bank %d" % int(instruction.operands[1].value)
		"ax_resource_marker":
			return "%s; data.arc loads to native destination buffer; AX payload semantics unresolved" % str(
				instruction.operands[0].name
			)
		"ax_presentation_binding":
			var binding_operand: Dictionary = instruction.get("operands", [{}])[0]
			return "native AX buffer bind -> consumer %d cell (%d,%d); subrecord/rendering unresolved" % [
				int(binding_operand.get("consumer_index", -1)),
				int(binding_operand.get("cell_row", -1)),
				int(binding_operand.get("cell_column", -1)),
			]
		"ax_presentation_control":
			var control_operand: Dictionary = instruction.get("operands", [{}])[0]
			return "selector %d; %s; native AX effect omitted" % [
				int(control_operand.get("execution_selector", -1)),
				str(control_operand.get("native_bounded_effect", "AX presentation control")),
			]
		"surface_composition_control":
			var composition_operand: Dictionary = instruction.get("operands", [{}])[0]
			return "mode %d; %s; native surface effect omitted" % [
				int(composition_operand.get("surface_mode", -1)),
				str(composition_operand.get("native_bounded_effect", "surface composition control")),
			]
		"surface_operation":
			var surface_operand: Dictionary = instruction.get("operands", [{}])[0]
			return "mode %d; %s; native pixel effect omitted" % [
				int(surface_operand.get("mode", -1)),
				str(surface_operand.get("native_operation_semantics", "surface operation")),
			]
		"surface_display_refresh":
			var refresh_operand: Dictionary = instruction.get("operands", [{}])[0]
			return "mode %d; conditional attached-display refresh; native host effect omitted" % int(
				refresh_operand.get("mode", -1)
			)
		"surface_dispatch_unresolved":
			var dispatch_operand: Dictionary = instruction.get("operands", [{}])[0]
			var mode_label := str(dispatch_operand.get("mode", -1))
			if str(dispatch_operand.get("mode_source", "")) != "literal":
				mode_label = "native default unresolved"
			return "mode %s; %d typed records; unresolved native effects omitted" % [
				mode_label,
				int(dispatch_operand.get("record_count", 0)),
			]
		"statement_separator":
			return "native character-stream presentation; structural separator only; %s" % native_probe_detail
		"command_02":
			return "native character-stream presentation; Event Runner stops; %s" % native_probe_detail
		"command_12":
			return "native character-stream presentation boundary; %s" % native_probe_detail
		"dispatcher_default_byte", "separator_ff":
			return "native character-stream presentation; %s" % native_probe_detail
		"native_record_dispatch":
			return "%d typed records; native dispatcher effects are not executed" % int(
				instruction.get("native_record_count", 0)
			)
		"command_01":
			return "native double-byte stream; no character consumed before boundary; %s" % native_probe_detail
		_:
			return ""


func _native_stream_probe_detail(instruction: Dictionary) -> String:
	var probe: Dictionary = instruction.get("native_stream_probe", {})
	if probe.is_empty():
		return "native stream probe unavailable"
	return "%d consumed bytes -> 0x%X (%s)" % [
		int(probe.get("consumed_byte_count", 0)),
		int(probe.get("probe_end_offset", -1)),
		str(probe.get("stop_reason", "unknown stop")),
	]


func _catalog_terminal_match_for_result(result: Dictionary) -> Dictionary:
	if not _catalog_playback_active or _catalog_playback_request.is_empty():
		return {}
	var contract_value = _catalog_playback_request.get("terminal_contract", null)
	if not contract_value is Dictionary:
		return {"ok": false, "error": "Catalog playback request has no terminal contract."}
	var contract: Dictionary = contract_value
	var state_values: Array[Dictionary] = []
	var seen_state := {}
	for stage_value in contract.get("stages", []):
		if not stage_value is Dictionary:
			return {"ok": false, "error": "Catalog terminal contract contains an invalid stage."}
		for assertion_value in (stage_value as Dictionary).get("required_state", []):
			if not assertion_value is Dictionary:
				return {"ok": false, "error": "Catalog terminal contract contains an invalid state assertion."}
			var assertion: Dictionary = assertion_value
			var storage := str(assertion.get("storage", ""))
			var bank := int(assertion.get("bank", 0))
			var index := int(assertion.get("index", -1))
			var key := "%s:%d:%d" % [storage, bank, index]
			if seen_state.has(key):
				continue
			seen_state[key] = true
			state_values.append({
				"storage": storage,
				"bank": bank,
				"index": index,
				"value": _state.read_value(storage, index, bank),
			})
	var next_target := ""
	var trace: Array = result.get("trace", [])
	for trace_index in range(trace.size() - 1, -1, -1):
		var trace_value = trace[trace_index]
		if trace_value is Dictionary and not str((trace_value as Dictionary).get("target_entry", "")).is_empty():
			next_target = str((trace_value as Dictionary).get("target_entry", ""))
			break
	return _event_catalog.match_terminal_contract(contract, {
		"owner_entry": _selected_entry,
		"runtime_status": str(result.get("status", "")),
		"offset": int(result.get("offset", -1)),
		"next_target": next_target,
		"state_values": state_values,
	})


func _is_catalog_terminal_coordinate(result: Dictionary) -> bool:
	if not _catalog_playback_active or _catalog_playback_request.is_empty():
		return false
	var contract_value = _catalog_playback_request.get("terminal_contract", null)
	if not contract_value is Dictionary:
		return false
	var owner_entry := _selected_entry.to_upper()
	var offset := int(result.get("offset", -1))
	for stage_value in (contract_value as Dictionary).get("stages", []):
		if (
			stage_value is Dictionary
			and str((stage_value as Dictionary).get("owner_entry", "")).to_upper() == owner_entry
			and int((stage_value as Dictionary).get("offset", -1)) == offset
		):
			return true
	return false


func _show_result(result: Dictionary, intro_offset: int) -> void:
	if result.has("detached_definition_preview"):
		_clear_continuation()
	else:
		_capture_continuation(result)
	_clear_choice_projection()
	trace_tree.clear()
	message_tree.clear()
	state_diff_tree.clear()
	script_call_tree.clear()
	shared_routine_tree.clear()
	result_tabs.set_tab_title(4, "Shared Routine")
	_preview_messages.clear()
	_preview_definitions.clear()
	_preview_message_index = -1
	_preview_result_status = str(result.get("status", ""))
	_preview_result_offset = int(result.get("offset", -1))
	_preview_detached_definition_id = int(result.get("detached_definition_preview", {}).get("definition_id", -1))
	_catalog_terminal_match.clear()
	_catalog_terminal_rejected_completion = false
	if _catalog_playback_active:
		var terminal_match := _catalog_terminal_match_for_result(result)
		_catalog_terminal_match = terminal_match.duplicate(true)
		_catalog_terminal_rejected_completion = _is_catalog_terminal_coordinate(result) and not terminal_match.get("ok", false)
		_preview_event_complete = (
			terminal_match.get("ok", false)
			and bool(terminal_match.get("route_ended", false))
		)
	else:
		_preview_event_complete = false
	_preview_completion_shown = false
	var trace_root := trace_tree.create_item()
	for trace in result.trace:
		var item := trace_tree.create_item(trace_root)
		item.set_text(0, str(trace.step))
		item.set_text(1, _trace_coordinate_text(trace))
		item.set_text(2, "0x%02X %s" % [int(trace.command_id), str(trace.op)])
		var effect := str(trace.get("effect", ""))
		if trace.has("write_start"):
			effect += " %s[%d:0x%X] x%d" % [
				str(trace.get("write_storage", "state")),
				int(trace.get("write_bank", 0)),
				int(trace.write_start),
				int(trace.write_count),
			]
			if trace.get("write_wrapped", false):
				effect += " wrap&0x%X" % int(trace.get("write_index_mask", 0))
		if trace.has("resource_name"):
			effect += " %s" % str(trace.resource_name)
			if trace.has("bgm_selector"):
				effect += " (selector %d)" % int(trace.bgm_selector)
		if trace.has("execution_selector"):
			effect += " selector=%d" % int(trace.execution_selector)
		if trace.has("execution_role"):
			effect += " role=%s" % str(trace.execution_role)
		if trace.has("message_record_id"):
			effect += " %d" % int(trace.message_record_id)
		if trace.has("routine_id"):
			effect += " routine=%d" % int(trace.routine_id)
		if trace.has("persistent_expression_stack") and trace.has("routine_id"):
			var call_stack: Array = trace.persistent_expression_stack
			effect += " carry_depth=%d" % call_stack.size()
			if not call_stack.is_empty():
				effect += " top=%d" % int(call_stack[-1])
		if trace.has("definition_id"):
			effect += " def=%d" % int(trace.definition_id)
		if trace.has("external_definition_id"):
			effect += " external DEF %d (%s)" % [
				int(trace.external_definition_id),
				str(trace.get("external_definition_source", "audited body")),
			]
		if trace.has("target_entry"):
			effect += " target=%s" % str(trace.target_entry)
		if trace.has("argument_slot"):
			effect += " arg%d=%d" % [int(trace.argument_slot), int(trace.get("argument_value", 0))]
		if trace.has("internal_vector_selector"):
			effect += " vector=%d" % int(trace.internal_vector_selector)
		if trace.has("internal_record_delta"):
			effect += " manager_record_delta=%d" % int(trace.internal_record_delta)
		if trace.has("record_value"):
			effect += " record_value=%d" % int(trace.record_value)
		if trace.has("record_count"):
			effect += " records=%d text=%d expr=%d" % [
				int(trace.record_count),
				int(trace.get("string_record_count", 0)),
				int(trace.get("expression_record_count", 0)),
			]
		if trace.has("persistent_expression_steps"):
			var stack_parts: Array[String] = []
			for untyped_step in trace.persistent_expression_steps:
				var expression_step: Dictionary = untyped_step
				stack_parts.append("%s:d%d %d>%d%s" % [
					str(expression_step.get("role", "expr")),
					int(expression_step.get("local_depth", 0)),
					int(expression_step.get("stack_depth_before", 0)),
					int(expression_step.get("stack_depth_after", 0)),
					" fallback=0" if expression_step.get("used_empty_fallback", false) else "",
				])
			effect += " stack{" + "; ".join(stack_parts) + "}"
		if trace.has("next_offset"):
			effect += " -> 0x%X" % int(trace.next_offset)
		item.set_text(3, effect)
	var message_root := message_tree.create_item()
	var presentations: Array[Dictionary] = []
	for message in result.messages:
		var presentation := _resolve_message_presentation(message)
		presentations.append(presentation)
		var item := message_tree.create_item(message_root)
		item.set_text(0, "0x%08X" % int(presentation.offset))
		item.set_text(1, _presentation_source_text(presentation))
		item.set_text(2, str(presentation.text))
		item.set_tooltip_text(2, str(presentation.tooltip))
	_preview_messages = _compose_preview_messages(presentations, result)
	for untyped_definition in result.get("definitions", []):
		var definition: Dictionary = untyped_definition
		var text_parts: Array[String] = []
		for untyped_message in definition.get("messages", []):
			var presentation := _resolve_message_presentation(untyped_message)
			text_parts.append(str(presentation.text))
			var item := message_tree.create_item(message_root)
			item.set_text(0, "0x%08X" % int(presentation.offset))
			item.set_text(1, "%s · DEF %d · %s" % [
				str(presentation.source_entry),
				int(definition.definition_id),
				str(presentation.source),
			])
			item.set_text(2, str(presentation.text))
			item.set_tooltip_text(2, str(presentation.tooltip))
		_preview_definitions.append({
			"definition_id": int(definition.definition_id),
			"source_offset": int(definition.source_offset),
			"body_offset": int(definition.get("body_offset", -1)),
			"target_offset": int(definition.target_offset),
			"body_size": int(definition.get("body_size", 0)),
			"body_sha256": str(definition.get("body_sha256", "")),
			"text": "".join(text_parts),
		})
	var state_root := state_diff_tree.create_item()
	for change in result.state_diff:
		var item := state_diff_tree.create_item(state_root)
		item.set_text(0, str(change.storage))
		item.set_text(1, str(change.bank))
		item.set_text(2, str(change.index))
		item.set_text(3, "%d -> %d" % [int(change.before), int(change.after)])
	var script_call_root := script_call_tree.create_item()
	for untyped_call in result.get("script_calls", []):
		var script_call: Dictionary = untyped_call
		var item := script_call_tree.create_item(script_call_root)
		item.set_text(0, str(script_call.get("call_depth", 0)))
		item.set_text(1, "%s · 0x%08X" % [
			str(script_call.get("caller_entry", "unknown")),
			int(script_call.get("call_offset", -1)),
		])
		item.set_text(2, str(script_call.get("callee_entry", "unknown")))
		var return_text := "not returned"
		if script_call.get("returned", false):
			return_text = "returned 0x%08X" % int(script_call.get("return_offset", -1))
		item.set_text(3, "resume 0x%08X · %s" % [
			int(script_call.get("resume_offset", -1)),
			return_text,
		])
	for untyped_call in result.get("registered_definition_calls", []):
		var definition_call: Dictionary = untyped_call
		var caller_definition_id := int(definition_call.get("caller_definition_id", -1))
		var caller_label := _selected_entry if caller_definition_id < 0 else "registered DEF %d" % caller_definition_id
		var item := script_call_tree.create_item(script_call_root)
		item.set_text(0, "%d DEF" % int(definition_call.get("call_depth", 0)))
		item.set_text(1, "%s - 0x%08X" % [
			caller_label,
			int(definition_call.get("call_offset", -1)),
		])
		item.set_text(2, "registered DEF %d - %s" % [
			int(definition_call.get("definition_id", -1)),
			str(definition_call.get("source", "explicit registry")),
		])
		item.set_text(3, "resume 0x%08X - bounded composition" % int(definition_call.get("resume_offset", -1)))
	var lines: Array[String] = [
		"[b]Status:[/b] %s" % str(result.status),
		"[b]Stopped at:[/b] 0x%X" % int(result.offset),
		"[b]Trace steps:[/b] %d" % result.trace.size(),
		"[b]Messages:[/b] %d" % result.messages.size(),
		"[b]Read-only DEF bodies:[/b] %d" % _preview_definitions.size(),
		"[b]Nested MES calls:[/b] %d" % (result.get("script_calls", []) as Array).size(),
		"[b]State diff:[/b] %d" % result.state_diff.size(),
	]
	var result_definition_groups: Dictionary = result.get("definition_groups", {})
	if result_definition_groups.size() > 1:
		var group_counts: Array[String] = []
		for untyped_selector in result.get("definition_group_order", result_definition_groups.keys()):
			var selector := int(untyped_selector)
			group_counts.append("%d:%d" % [selector, (result_definition_groups.get(selector, []) as Array).size()])
		lines.append(
			"[b]Native DEF groups:[/b] %s; fixed-key first stage=%d (%d visible); %d registered rows; native input/caller resume remain unresolved; retained second-stage rows may be inspected only through a disposable analysis preview"
			% [
				", ".join(group_counts),
				int(result.get("selection_definition_group", -1)),
				_preview_definitions.size(),
				int(result.get("registered_definition_count", 0)),
			]
		)
	var reached_library_routine := -1
	if result.has("error"):
		lines.append("[b]Boundary:[/b] %s" % str(result.error))
	if result.has("detached_definition_preview"):
		var detached_preview: Dictionary = result.detached_definition_preview
		lines.append(
			"[b]Detached DEF preview:[/b] explicit tool selection %d; body 0x%X..0x%X; caller resume and native routine-40 result mapping not executed; cloned sandbox discarded"
			% [
				int(detached_preview.definition_id) + 1,
				int(detached_preview.body_offset),
				int(detached_preview.target_offset),
			]
		)
		var detached_registered_calls: Array = result.get("registered_definition_calls", [])
		if not detached_registered_calls.is_empty():
			lines.append(
				"[b]Registered DEF composition:[/b] %d explicit startup-registry call(s); bounded native effects omitted; outer detached body restored; cloned sandbox discarded"
				% detached_registered_calls.size()
			)
	if result.has("choice_projection"):
		var projected_choice: Dictionary = result.choice_projection
		if str(projected_choice.get("kind", "")) == "remake_routine40_result_bridge":
			var gate_summary := ""
			var projected_gate: Dictionary = projected_choice.get("gate", {})
			if not projected_gate.is_empty():
				gate_summary = "; preserved %s[%d]=%d" % [
					str(projected_gate.get("storage", "")),
					int(projected_gate.get("index", -1)),
					int(projected_choice.get("gate_value", -1)),
				]
			lines.append(
				"[b]Routine 40 remake bridge:[/b] explicit option %d wrote caller-visible state_u16[%d] and resumed at 0x%X under %s%s; native helper input and omitted slot-18/slot-13/routine-20/vector effects remain unresolved"
				% [
					int(projected_choice.get("selection", 0)),
					int(projected_choice.get("index", -1)),
					int(projected_choice.get("resume_offset", -1)),
					str(projected_choice.get("contract_schema", "unknown contract")),
					gate_summary,
				]
			)
	if result.has("library_continuation"):
		var library_continuation: Dictionary = result.library_continuation
		reached_library_routine = int(library_continuation.routine_id)
		lines.append(
			"[b]Executed shared library:[/b] routine %d; %d rows, %d nested calls, %d omitted presentation spans, %d decoded surface ops, %d confirmed display refreshes omitted, %d unresolved surface dispatches, %d omitted native record dispatches (sandbox only)"
			% [
				int(library_continuation.routine_id),
				int(library_continuation.trace_count),
				int(library_continuation.call_count),
				int(library_continuation.omitted_native_presentation_count),
				int(library_continuation.get("decoded_surface_operation_count", 0)),
				int(library_continuation.get("decoded_surface_display_refresh_count", 0)),
				int(library_continuation.get("unresolved_surface_dispatch_count", 0)),
				int(library_continuation.get("omitted_native_record_count", 0)),
			]
		)
		lines.append(
			"[b]Shared library state diff:[/b] %s"
			% _state_diff_summary(library_continuation.get("state_diff", []))
		)
		if int(library_continuation.get("external_definition_trace_count", 0)) > 0:
			lines.append(
				"[b]Explicit registered DEF composition:[/b] %d external trace rows; bounded presentation and native record effects omitted; caller resumed in sandbox"
				% int(library_continuation.external_definition_trace_count)
			)
	if result.has("promise_date_route"):
		var promise_route: Dictionary = result.promise_date_route
		lines.append(
			"[b]Isolated PROMIS date route:[/b] %s 0x%X; routine %d; %04d -> %04d; banked field %d at 0x%X; outer gameplay caller unresolved"
			% [
				str(promise_route.entry),
				int(promise_route.intro),
				int(promise_route.routine),
				int(promise_route.input_date),
				int(promise_route.output_date),
				int(promise_route.field),
				int(promise_route.writer),
			]
		)
	if _preview_event_session == "promise_date":
		var active_promise_route := _active_promise_date_route()
		if not active_promise_route.is_empty():
			var promise_location := _state.read_value("global_u8", int(active_promise_route.location_field))
			var option_states: Array[String] = []
			for option in range(1, 11):
				var route_state := _active_promise_option_route_state(option)
				var compact_state := "OK" if route_state == "allowed" else ("GATE" if route_state == "entry_gate" else "NO")
				option_states.append("%02d:%s" % [option + 8, compact_state])
			lines.append(
				"[b]PROMIS selected-location matrix:[/b] global_u8[%d]=%d; paired banked_u16[0][%d]=%04d; %s; static v3 audit, sandbox only"
				% [
					int(active_promise_route.location_field),
					promise_location,
					int(active_promise_route.field) + 1,
					_state.read_value("banked_u16", int(active_promise_route.field) + 1, 0),
					" ".join(option_states),
				]
			)
			if _selected_entry == "A_PROMIS.MES" and _state.read_value("global_u8", 1060) == 0:
				lines.append(
					"[b]A-entry evening gate:[/b] banked_u16[0][201]=%d, global_u8[1060]=0; 16:00-18:00 retry before location acceptance (low: 2 dialogue boundaries; high >=100: 8 boundaries then latch); field meaning and outer seeding unresolved"
					% _state.read_value("banked_u16", 201, 0)
				)
	if str(result.status) == "script_dispatch_boundary" and not result.trace.is_empty():
		lines.append("[b]Nested MES target:[/b] %s (read-only boundary; not executed)" % str(result.trace[-1].get("target_entry", "unknown")))
	if str(result.status) == "script_handoff_boundary" and not result.trace.is_empty():
		lines.append("[b]MES handoff target:[/b] %s (native active-string boundary; host consumer not executed)" % str(result.trace[-1].get("target_entry", "unknown")))
	if str(result.status) == "native_script_execution_boundary" and not result.trace.is_empty():
		var script_execution: Dictionary = result.trace[-1]
		lines.append(
			"[b]Original inline script target:[/b] %s (presentation subcommand 8, selector %d, %s; native load/execute/restore confirmed; isolated preview stopped before execution)"
			% [
				str(script_execution.get("resource_name", "unknown")),
				int(script_execution.get("execution_selector", -1)),
				str(script_execution.get("execution_role", "unknown role")),
			]
		)
	if str(result.status) == "native_state_transfer_boundary" and not result.trace.is_empty():
		var state_transfer: Dictionary = result.trace[-1]
		lines.append(
			"[b]Native state transfer:[/b] subcommand %d selector %d; relative offsets %s; host record contents and physical aliases unresolved"
			% [
				int(state_transfer.get("presentation_subcommand", -1)),
				int(state_transfer.get("transfer_selector", -1)),
				str(state_transfer.get("mapping_string", "?")),
			]
		)
	if result.has("caller_composition"):
		var caller_composition: Dictionary = result.caller_composition
		lines.append(
			"[b]Caller follow-up:[/b] %s 0x%X after callee return 0x%X; %s at 0x%X omitted, audited %s restored as keyed foreground over %s (TIME_C projection at HHMM %04d); sandbox only"
			% [
				str(caller_composition.source_entry),
				int(caller_composition.followup_offset),
				int(caller_composition.callee_return_offset),
				str(caller_composition.restore_entry),
				int(caller_composition.restore_dispatch_offset),
				str(caller_composition.restore_mmo),
				str(caller_composition.background_mmo),
				int(caller_composition.background_hhmm),
			]
		)
	var selection_provenance := _routine40_selection_provenance(result)
	if not selection_provenance.is_empty():
		if bool(selection_provenance.get("authoritative", false)):
			lines.append(
				"[b]Choice input provenance:[/b] authoritative LIBLARY.LIB routine 40 0x%X..0x%X; native dispatch %d coordinates / %d edges; command 0x12 typed-record lists are %s and reached command 0x15 is none. Bytes resembling command 0x15 are expression literals, not MES command rows. The visible choice is explicit remake input; the original one-based result encoding is confirmed, while native presentation and effects remain unresolved"
				% [
					int(selection_provenance.body_offset),
					int(selection_provenance.end_offset),
					int(selection_provenance.flow_instruction_count),
					int(selection_provenance.flow_edge_count),
					_hex_offset_list(selection_provenance.native_record_offsets),
				]
			)
			lines.append(
				"[b]Routine 40 script envelope:[/b] state_u16[18] -> [21]; zero loops; nonzero values below 17 enter a second native record dispatch; 0xFFFF or later nonzero slot 18 is copied to slot 13; routine 20 follows, then vector-clear records 1..17. Slot 18/21 and the second slot-13 result use one-based selected-record indices. The dynamic second-stage list remains unresolved. EXE audit v81 confirms routine 20's conditional local (0,0) 544x60 attached-display refresh and the following manager-vector cleanup; the tool omits the refresh because attached backing content/lifetime and final composition remain unresolved"
			)
			lines.append(
				"[b]Routine 40 native records:[/b] 0x1C95..0x1CA0 command 0x12: 3 expression records + list terminator; 0x1CC4..0x1CD0 command 0x12: 3 expression records + list terminator. Typed extents are confirmed; record-dispatch state and presentation effects are not executed"
			)
			lines.append(
				"[b]Slot 18 native writer audit:[/b] original EXE audits confirm that routine 40 records [1, 21, third expression] route through helper mode 1. The native control converts its zero-based selected row to a one-based result, the modal runner returns that value unchanged, and an empty list yields 0xFFFF. A nonzero second result is copied to slot 13. Audit v68 retains v67's Return/Escape/direction, three-row navigation, pointer, mouse-latch, and fixed-region toggle bindings while adding the separate surface-1 producer-family evidence used by presentation diagnostics. Embedded EXE AREA resources contain only modal IDs {0x0000,0x0001} and {0x0100,0x0101,0x0102,0x0103}; none is a choice row, and 0x0100/0x0102 are clamped window deltas -1/+1. Choice rows instead use the selected control's dynamic hit table: a zero high byte and low-byte visible-row ordinal are combined with the visible-window start, bounds-checked against the total count, mapped through the mode-0 host row lookup, then made one-based. The selected-control window contains exactly three rows; Up/Down scroll one row at ordinals 0/2 only while another record exists, absolute ends do not wrap, and the selected dynamic row rectangle centers the native cursor. Held directions are level-triggered once per completed modal iteration; the active-window message pump uses Sleep(0), so wall-clock repeat rate remains host-scheduler dependent rather than a fixed native interval. WM_LBUTTONDOWN captures the window when needed and sets the application key object's left-button latch; while modal AREA ID 0 is active, modal update dispatches confirm, invokes the selected control's +4 confirm function, copies its one-based result, and stops the modal. WM_LBUTTONUP clears the latch. AREA ID 1 is conditional: with flags +0x3DF/+0x3E0/+0x3E1 all zero it calls native helper 0x00435850 and returns without directly copying a modal result or stopping the modal; otherwise it falls through to the selected-control confirm path. The complete helper toggles display mode +0x43D, activates fixed document rectangle (34,316)-(578,376) or restores the rectangle saved at +0x414, and performs 640x400 surface/document updates. It is a nonterminal presentation-region toggle, not cancel or a choice row; its visible native label remains unresolved. Primary AREA IDs 0x0101/0x0103 instead take exact native control/presentation-update branches and neither directly copies a modal result nor stops the modal. Those paths now bind document-region preparation, a temporary document latch, update flag 0x10, rectangle forwarding, and a shared current-document virtual-slot-0x3C tail dispatch. Their final user-facing meanings, Escape meaning, remaining native effects, and independent non-unique writers remain unresolved"
			)
		elif bool(selection_provenance.get("native_dispatch_audited", false)):
			lines.append(
				"[b]Choice input provenance:[/b] resolved routine 40 audit marks command-0x12 typed-record lists at %s; reached command-0x15 operations: %s. The visible choice is explicit tool input; one-based result and keyboard callback wiring are confirmed, while mouse, cadence, presentation, and callback effects remain unresolved"
				% [
					_hex_offset_list(selection_provenance.native_record_offsets),
					_hex_offset_list(selection_provenance.reached_command15_offsets),
				]
			)
		else:
			lines.append(
				"[b]Choice input provenance:[/b] routine 40 reached with read-only DEF bodies. The visible choice is explicit tool input; one-based result and keyboard callback wiring are confirmed, while mouse, cadence, presentation, and callback effects remain unresolved"
			)
	var shared_boundary := _shared_routine_boundary(result)
	var displayed_routine_boundary := shared_boundary
	var shows_choice_audit := false
	if shared_boundary.is_empty() and bool(selection_provenance.get("native_dispatch_audited", false)):
		displayed_routine_boundary = _indexed_routine_boundary(40, "choice_provenance")
		shows_choice_audit = not displayed_routine_boundary.is_empty()
	if not displayed_routine_boundary.is_empty():
		_populate_shared_routine_tree(displayed_routine_boundary)
		if shows_choice_audit:
			result_tabs.set_tab_title(4, "Routine 40 Audit")
			if bool(selection_provenance.get("authoritative", false)):
				shared_routine_tree.set_meta("exe_audit_schema", "kakyu_ai5_mes_exe_audit/v106")
				shared_routine_tree.set_meta("native_slot18_writer_scope", "selected_routes_not_exhaustive")
				shared_routine_tree.set_meta("native_slot18_routine40_reachability", "command_12_records_primary_1_secondary_21_confirmed_to_slot18_writer_selected_intro_execution_unresolved")
				shared_routine_tree.set_meta("native_slot18_result_semantics", "helper_mode1_one_based_selected_record_index_empty_list_ffff")
			lines.append(
				"[b]Choice audit panel:[/b] routine 40, body 0x%X..0x%X (%s); open Routine 40 Audit for stored rows, native spans, and both-branch graph metadata. This panel does not execute the routine"
				% [
					int(displayed_routine_boundary.body_offset),
					int(displayed_routine_boundary.end_offset),
					str(displayed_routine_boundary.source),
				]
			)
		else:
			lines.append(
				"[b]Shared library:[/b] routine %d, body 0x%X..0x%X (%s; indexed, execution unresolved)"
				% [
					int(displayed_routine_boundary.routine_id),
					int(displayed_routine_boundary.body_offset),
					int(displayed_routine_boundary.end_offset),
					str(displayed_routine_boundary.source),
				]
			)
		if not bool(shared_routine_tree.get_meta("decode_complete", false)):
			lines.append(
				"[b]Routine disassembly:[/b] %d strict-prefix rows, stopped at 0x%X (%s)"
				% [
					int(shared_routine_tree.get_meta("instruction_count", 0)),
					int(shared_routine_tree.get_meta("decoded_end_offset", -1)),
					str(shared_routine_tree.get_meta("decode_error", "unknown decoder boundary")),
				]
			)
		var structural_complete := bool(shared_routine_tree.get_meta("structural_decode_complete", false))
		lines.append(
			"[b]Structural-only view:[/b] %d rows through 0x%X; %d non-executable rows%s"
			% [
				int(shared_routine_tree.get_meta("structural_instruction_count", 0)),
				int(shared_routine_tree.get_meta("structural_decoded_end_offset", -1)),
				int(shared_routine_tree.get_meta("structural_only_instruction_count", 0)),
				"; complete boundary" if structural_complete else "; stopped (%s)" % str(
					shared_routine_tree.get_meta("structural_decode_error", "unknown structural boundary")
				),
			]
		)
		var return_segments: Array = shared_routine_tree.get_meta("return_delimited_segments", [])
		if not return_segments.is_empty():
			lines.append(
				"[b]Return-delimited diagnostics:[/b] %d stored-order segments (not CFG paths): %s"
				% [return_segments.size(), _return_segment_summary(return_segments)]
			)
		var native_stream_boundaries: Array = shared_routine_tree.get_meta("native_stream_boundaries", [])
		if not native_stream_boundaries.is_empty():
			lines.append(
				"[b]Native stream boundary:[/b] %d dispatch tokens; bytes after the first are stored-order diagnostics, not a confirmed execution path"
				% native_stream_boundaries.size()
			)
		var native_record_boundaries: Array = shared_routine_tree.get_meta("native_record_boundaries", [])
		if not native_record_boundaries.is_empty():
			lines.append(
				"[b]Native record boundary:[/b] %d typed record lists; extents confirmed, dispatcher effects not executed"
				% native_record_boundaries.size()
			)
		lines.append(
			"[b]Native dispatch graph:[/b] %d coordinates, %d edges, %d native spans, %d returns; %d boundaries, %d failures%s"
			% [
				int(shared_routine_tree.get_meta("native_dispatch_instruction_count", 0)),
				int(shared_routine_tree.get_meta("native_dispatch_edge_count", 0)),
				int(shared_routine_tree.get_meta("native_dispatch_span_count", 0)),
				int(shared_routine_tree.get_meta("native_dispatch_return_count", 0)),
				int(shared_routine_tree.get_meta("native_dispatch_boundary_count", 0)),
				int(shared_routine_tree.get_meta("native_dispatch_failure_count", 0)),
				"; both branch edges, no effects executed" if bool(shared_routine_tree.get_meta("native_dispatch_flow_complete", false)) else "; incomplete",
			]
		)
		var shadowed_rows: Array = shared_routine_tree.get_meta(
			"native_dispatch_shadowed_structural_instructions",
			[]
		)
		if not shadowed_rows.is_empty():
			var shadowed_counts := {}
			for untyped_shadowed in shadowed_rows:
				var shadowed: Dictionary = untyped_shadowed
				var command_id := int(shadowed.get("command_id", -1))
				shadowed_counts[command_id] = int(shadowed_counts.get(command_id, 0)) + 1
			var shadowed_command_ids: Array = shadowed_counts.keys()
			shadowed_command_ids.sort()
			var shadowed_parts: Array[String] = []
			for command_id in shadowed_command_ids:
				shadowed_parts.append("0x%02X x%d" % [int(command_id), int(shadowed_counts[command_id])])
			lines.append(
				"[b]Stored-order rows inside native payload:[/b] %d (%s); retained for lossless analysis, not dispatcher commands"
				% [shadowed_rows.size(), ", ".join(shadowed_parts)]
			)
		var control_flow_unreached_rows: Array = []
		for untyped_unreached in shared_routine_tree.get_meta(
			"native_dispatch_unreached_structural_instructions",
			[]
		):
			var unreached: Dictionary = untyped_unreached
			if str(unreached.get("reason", "")) == "control_flow_not_reached":
				control_flow_unreached_rows.append(unreached)
		if not control_flow_unreached_rows.is_empty():
			var unreachable_parts: Array[String] = []
			for unreached in control_flow_unreached_rows:
				unreachable_parts.append("0x%X command 0x%02X" % [
					int(unreached.get("source_offset", -1)),
					int(unreached.get("command_id", -1)),
				])
			lines.append(
				"[b]Control-flow-unreached stored rows:[/b] %d (%s); retained for lossless analysis, not dispatcher commands"
				% [control_flow_unreached_rows.size(), ", ".join(unreachable_parts)]
			)
		var native_flow_calls: Dictionary = shared_routine_tree.get_meta("native_dispatch_calls", {})
		var native_flow_writes: Dictionary = shared_routine_tree.get_meta("native_dispatch_writes", {})
		if not native_flow_calls.is_empty() or not native_flow_writes.is_empty():
			lines.append(
				"[b]Native flow effects:[/b] calls %s; write coordinates %s (graph metadata only; not executed)"
				% [_count_map_text(native_flow_calls, "routine "), _count_map_text(native_flow_writes)]
			)
		var native_def_registrations: Array = shared_routine_tree.get_meta("native_def_registrations", [])
		var native_def_invocations: Array = shared_routine_tree.get_meta("native_def_invocations", [])
		if not native_def_registrations.is_empty() or not native_def_invocations.is_empty():
			lines.append(
				"[b]Native DEF coordinates:[/b] registrations %s; invocations %s (graph metadata only; original START bootstrap confirmed, isolated preview does not replay it)"
				% [
					_def_coordinate_summary(native_def_registrations, false),
					_def_coordinate_summary(native_def_invocations, true),
				]
			)
	if (
		reached_library_routine == 25
		or (not shared_boundary.is_empty() and int(shared_boundary.routine_id) == 25)
	):
		var def26_probe := _audited_def26_context_probe()
		if not def26_probe.is_empty():
			var composed_external_rows := int(
				(result.get("library_continuation", {}) as Dictionary).get("external_definition_trace_count", 0)
			)
			lines.append(
				"[b]Authoritative DEF-26 registration:[/b] 1 among %d; DEF_MAIN.MES 0x%X -> body 0x%X..0x%X; LIBLARY.LIB calls 0x1E22/0x1F2E"
				% [
					AUDITED_CONTEXT_REGISTRATIONS,
					int(def26_probe.registration_offset),
					int(def26_probe.body_offset),
					int(def26_probe.skip_target),
				]
			)
			lines.append(
				"[b]Original startup context:[/b] START.MES executes LIBLARY.LIB then DEF_MAIN.MES; the owning manager retains the registry. The read-only projection indexed %d hash-bound definitions without executing their bodies; this explicit event route supplies projected DEF 26 only when routine 25 requests it"
				% int(_startup_context.get("registration_count", 0))
			)
			lines.append(
				"[b]Isolated DEF-26 body probe:[/b] 0x%X -> stop 0x%X at command 0x%02X (%s); %d trace rows, %d dialogue, %d state changes; native caller frame and later body execution unresolved"
				% [
					int(def26_probe.body_offset),
					int(def26_probe.stop_offset),
					int(def26_probe.command_id),
					str(def26_probe.status),
					int(def26_probe.trace_count),
					int(def26_probe.message_count),
					int(def26_probe.state_diff_count),
				]
			)
			lines.append(
				"[b]Native-effects-omitted body audit:[/b] %d source markers + %d bounded presentation spans + %d native record dispatches + return at 0x%X = %d trace rows; %d dialogue, %d state changes; %s"
				% [
					int(def26_probe.source_line_marker_count),
					int(def26_probe.omitted_presentation_count),
					int(def26_probe.omitted_native_record_count),
					int(def26_probe.return_offset),
					int(def26_probe.full_trace_count),
					int(def26_probe.full_message_count),
					int(def26_probe.full_state_diff_count),
					"explicitly composed in this sandbox run" if composed_external_rows > 0 else "analysis-only, not invoked",
				]
			)
	if _continuation_offset >= 0:
		lines.append("[b]Continue:[/b] 0x%X" % _continuation_offset)
	output.text = "\n".join(lines)
	_present_preview_result(result, intro_offset)
	work_tabs.current_tab = 1
	result_tabs.current_tab = 0
	if _preview_completion_shown:
		pass
	elif _is_confirmed_promise_time_choice_boundary(result):
		status_label.text = "PROMIS confirmed time choice ready; selection changes isolated sandbox state only"
	elif not _catalog_setup_extension_terminal(result).is_empty():
		var setup_terminal := _catalog_setup_extension_terminal(result)
		status_label.text = "EVENTD06 setup extension stopped safely before shared routine %d after %s; host activation remains unresolved" % [
			int(setup_terminal.routine_id),
			str(setup_terminal.mmo),
		]
	elif (
		_preview_event_session == "promise_date"
		and str(result.get("status", "")) == "script_return"
		and not _active_promise_date_route().is_empty()
	):
		status_label.text = "PROMIS scheduling prefix returned; selected location/time path ended, but the original outer caller remains unresolved"
	elif shared_boundary.is_empty():
		status_label.text = "%s: %d traced instructions; original ARC and gameplay saves unchanged" % [result.status, result.trace.size()]
	else:
		status_label.text = "shared routine %d boundary: body indexed, execution unresolved; original ARC and saves unchanged" % int(shared_boundary.routine_id)


func _has_authoritative_def26_registry_audit() -> bool:
	return _evidence().has_authoritative_def26_registry_audit()


func _audited_startup_registered_definitions() -> Dictionary:
	return _evidence().audited_startup_registered_definitions()


func _audited_def26_registered_definition() -> Dictionary:
	var registered_definitions := _audited_startup_registered_definitions()
	var definition: Dictionary = registered_definitions.get(26, {})
	if (
		definition.is_empty()
		or int(definition.get("body_offset", -1)) != AUDITED_DEF26_BODY_OFFSET
		or int(definition.get("end_offset", -1)) != AUDITED_DEF26_SKIP_TARGET
		or str(definition.get("source", "")) != "DEF_MAIN.MES:0x1FC"
	):
		return {}
	return definition


func _audited_def26_context_probe() -> Dictionary:
	if not _has_authoritative_def26_registry_audit():
		return {}
	var descriptor := _resolver.resolve("mes.arc", "DEF_MAIN.MES")
	if not descriptor.get("ok", false) or str(descriptor.get("source", "")) != "original_arc":
		return {}
	var data := _resolver.read_resolved(descriptor)
	if data.is_empty() and not _resolver.last_error.is_empty():
		return {}
	var document := _parser.parse(data, {
		"archive": "mes.arc",
		"entry": "DEF_MAIN.MES",
		"resolved_source": descriptor.source,
	})
	if not document.get("ok", false) or not _is_catalog_source_entry(str(document.get("entry_sha256", "")), "DEF_MAIN.MES"):
		return {}
	var index := MesContextIndexScript.new().build(document, [AUDITED_DEF26_REGISTRATION_OFFSET])
	var matches: Array = index.get("by_id", {}).get(26, [])
	if matches.size() != 1:
		return {}
	var registration: Dictionary = matches[0]
	if (
		int(registration.get("registration_offset", -1)) != AUDITED_DEF26_REGISTRATION_OFFSET
		or int(registration.get("body_offset", -1)) != AUDITED_DEF26_BODY_OFFSET
		or int(registration.get("skip_target", -1)) != AUDITED_DEF26_SKIP_TARGET
	):
		return {}
	var result := MesEventRunnerScript.new().run(
		document.bytecode,
		AUDITED_DEF26_BODY_OFFSET,
		SandboxStateScript.new(1),
		AUDITED_DEF26_SKIP_TARGET
	)
	var trace: Array = result.get("trace", [])
	var messages: Array = result.get("messages", [])
	var state_diff: Array = result.get("state_diff", [])
	if (
		str(result.get("status", "")) != "native_record_boundary"
		or int(result.get("offset", -1)) != 0x0208
		or trace.size() != 2
		or int(trace[-1].get("command_id", -1)) != 0x12
		or not messages.is_empty()
		or not state_diff.is_empty()
	):
		return {}
	var omitted_result := MesEventRunnerScript.new().run(
		document.bytecode,
		AUDITED_DEF26_BODY_OFFSET,
		SandboxStateScript.new(1),
		AUDITED_DEF26_SKIP_TARGET,
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{
			"native_stream_policy": "skip_bounded",
			"native_record_policy": "omit_bounded",
		}
	)
	var omitted_trace: Array = omitted_result.get("trace", [])
	var omitted_presentations := 0
	var omitted_native_records := 0
	var source_line_markers := 0
	for record in omitted_trace:
		match str(record.get("effect", "")):
			"native_presentation_omitted":
				omitted_presentations += 1
			"native_record_effects_omitted":
				omitted_native_records += 1
			"source_line_marker":
				source_line_markers += 1
	if (
		not omitted_result.get("ok", false)
		or str(omitted_result.get("status", "")) != "script_return"
		or int(omitted_result.get("offset", -1)) != 0x042C
		or omitted_trace.size() != 54
		or int(omitted_trace[-1].get("command_id", -1)) != 0x00
		or omitted_presentations != 0
		or omitted_native_records != 32
		or source_line_markers != 21
		or not (omitted_result.get("messages", []) as Array).is_empty()
		or not (omitted_result.get("state_diff", []) as Array).is_empty()
	):
		return {}
	return {
		"registration_offset": AUDITED_DEF26_REGISTRATION_OFFSET,
		"body_offset": AUDITED_DEF26_BODY_OFFSET,
		"skip_target": AUDITED_DEF26_SKIP_TARGET,
		"stop_offset": int(result.offset),
		"command_id": int(trace[-1].command_id),
		"status": str(result.status),
		"trace_count": trace.size(),
		"message_count": messages.size(),
		"state_diff_count": state_diff.size(),
		"return_offset": int(omitted_result.offset),
		"full_trace_count": omitted_trace.size(),
		"source_line_marker_count": source_line_markers,
		"omitted_presentation_count": omitted_presentations,
		"omitted_native_record_count": omitted_native_records,
		"full_message_count": (omitted_result.messages as Array).size(),
		"full_state_diff_count": (omitted_result.state_diff as Array).size(),
	}


func _state_diff_summary(diff: Array) -> String:
	if diff.is_empty():
		return "none"
	var parts: Array[String] = []
	for untyped_change in diff:
		var change: Dictionary = untyped_change
		parts.append(
			"%s[%d:%d] %d -> %d"
			% [
				str(change.get("storage", "state")),
				int(change.get("bank", 0)),
				int(change.get("index", -1)),
				int(change.get("before", 0)),
				int(change.get("after", 0)),
			]
		)
	return ", ".join(parts)


func _def_coordinate_summary(records: Array, include_matches: bool) -> String:
	if records.is_empty():
		return "none"
	var parts: Array[String] = []
	var sorted_records := records.duplicate(true)
	sorted_records.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return int(left.get("source_offset", -1)) < int(right.get("source_offset", -1))
	)
	for untyped_record in sorted_records:
		var record: Dictionary = untyped_record
		var value := "DEF %d @ 0x%X" % [
			int(record.get("definition_id", -1)),
			int(record.get("source_offset", -1)),
		]
		if include_matches:
			var matches: Array = record.get("matching_registration_offsets", [])
			value += " (local matches %d)" % matches.size()
		parts.append(value)
	return ", ".join(parts)


func _count_map_text(counts: Dictionary, prefix := "") -> String:
	if counts.is_empty():
		return "none"
	var keys: Array = counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s%s x%d" % [prefix, str(key), int(counts[key])])
	return ", ".join(parts)


func _resolve_message_presentation(message: Dictionary) -> Dictionary:
	var message_offset := int(message.source_offset)
	var source_entry := str(message.get("source_entry", _selected_entry)).to_upper()
	if message.has("dynamic_kind"):
		var resolved := bool(message.get("resolved", false))
		var text := str(message.get("text", "〈主人公名〉"))
		return {
			"offset": message_offset,
			"source_entry": source_entry,
			"source": "preview name" if resolved else "dynamic placeholder",
			"text": text,
			"tooltip": "%s\nDynamic field: %s" % [text, str(message.dynamic_kind)],
			"dynamic_kind": str(message.dynamic_kind),
		}
	var decoded := _cp932.decode(message.raw_bytes)
	if not bool(decoded.ok):
		return {
			"offset": message_offset,
			"source_entry": source_entry,
			"source": "native bytes diagnostic",
			"text": "Native presentation bytes (not CP932 dialogue)",
			"tooltip": (
				"Native presentation bytes are retained for lossless analysis.\n"
				+ "Raw bytes (hex): %s\nCP932 diagnostic: %s"
			) % [str(message.raw_hex), str(decoded.get("error", "invalid sequence"))],
		}
	var raw_hash := ContractValues.sha256(message.raw_bytes)
	var selected_source := source_entry.is_empty() or source_entry == _selected_entry.to_upper()
	var projection: Dictionary = _text_messages.get(message_offset, {}) if selected_source else {}
	if not projection.is_empty() and projection.raw_sha256 == raw_hash:
		return {
			"offset": message_offset,
			"source_entry": source_entry,
			"source": "UTF-8 cache",
			"text": str(projection.text),
			"tooltip": "%s\nCP932 bytes: %s" % [str(projection.text), str(message.raw_hex)],
		}
	var text := str(decoded.text)
	return {
		"offset": message_offset,
		"source_entry": source_entry,
		"source": "original CP932",
		"text": text,
		"tooltip": "%s\nCP932 bytes: %s" % [text, str(message.raw_hex)],
	}


func _compose_preview_messages(presentations: Array[Dictionary], result: Dictionary) -> Array[Dictionary]:
	var reached_cursor_control := false
	for record in result.get("trace", []):
		if str(record.get("effect", "")) == "message_cursor_no_advance":
			reached_cursor_control = true
			break
	if not reached_cursor_control:
		return presentations
	var has_dynamic_name := false
	for presentation in presentations:
		if str(presentation.get("dynamic_kind", "")) == "protagonist_name":
			has_dynamic_name = true
			break
	if not has_dynamic_name or presentations.is_empty():
		return presentations
	var text_parts: Array[String] = []
	var tooltip_parts: Array[String] = []
	for presentation in presentations:
		text_parts.append(str(presentation.text))
		tooltip_parts.append(str(presentation.tooltip))
	return [{
		"offset": int(presentations[0].offset),
		"source_entry": str(presentations[0].get("source_entry", _selected_entry)).to_upper(),
		"source": "composed original + preview name",
		"text": "".join(text_parts),
		"tooltip": "\n---\n".join(tooltip_parts),
	}]


func _trace_coordinate_text(trace: Dictionary) -> String:
	var source_entry := str(trace.get("source_entry", _selected_entry)).to_upper()
	var coordinate := "0x%08X" % int(trace.get("source_offset", -1))
	return coordinate if source_entry.is_empty() else "%s · %s" % [source_entry, coordinate]


func _presentation_source_text(presentation: Dictionary) -> String:
	var source_entry := str(presentation.get("source_entry", _selected_entry)).to_upper()
	var text_source := str(presentation.get("source", "unknown"))
	return text_source if source_entry.is_empty() else "%s · %s" % [source_entry, text_source]


func _setup_game_preview() -> void:
	game_preview.set_input_forwarding_enabled(true)
	game_preview.preview_input.connect(_on_game_preview_input)
	var root := game_preview.get_overlay_root()

	var dialogue_backdrop := ColorRect.new()
	dialogue_backdrop.position = Vector2(16, 286)
	dialogue_backdrop.size = Vector2(608, 98)
	dialogue_backdrop.color = Color(0.025, 0.025, 0.04, 0.92)
	dialogue_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dialogue_backdrop)

	_preview_message_label = _create_preview_label(root, Vector2(30, 296), Vector2(580, 62), 16)
	_preview_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_footer_label = _create_preview_label(root, Vector2(30, 360), Vector2(580, 18), 11)
	_preview_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reset_game_preview()


func _create_preview_label(parent: Control, position: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _reset_game_preview(entry_name := "") -> void:
	_preview_messages.clear()
	_preview_definitions.clear()
	_preview_message_index = -1
	_preview_result_status = ""
	_preview_result_offset = -1
	_preview_detached_definition_id = -1
	_preview_catalog_confirmed_bootstrap = false
	_clear_preview_route_identity()
	_clear_choice_projection()
	if not is_instance_valid(_preview_entry_label):
		return
	_preview_entry_label.text = entry_name if not entry_name.is_empty() else "No MES entry selected"
	_clear_preview_media_state()
	_preview_background_label.text = "MMO presentation not reached | AX metadata not reached | BGM request not reached | MES voice marker not reached"
	_preview_message_label.text = "Select an entry and run from a code-relative intro coordinate."
	_preview_footer_label.text = "Preview input: click to focus · Esc releases"


func _clear_preview_media_state() -> void:
	game_preview.set_preview_texture(null)
	game_preview.clear_foreground()
	_preview_surface_compositor.clear()
	_preview_surface_background_checkpoint.clear()
	_preview_mmo_name = ""
	_preview_mmo_status = ""
	_preview_dat_pal_name = ""
	_preview_dat_pal_status = ""
	_preview_foreground_mmo_name = ""
	_preview_foreground_mmo_status = ""
	_preview_ax_name = ""
	_preview_ax_status = ""
	_preview_ax_binding_table.clear()
	_preview_displayed_visible = {"background": "", "foreground": ""}
	_effective_media_identities.clear()
	preview_audio.stop()
	preview_audio.stream = null
	_preview_bgm_name = ""
	_preview_bgm_stream = null
	preview_effect_audio.stop()
	preview_effect_audio.stream = null
	_preview_effect_name = ""
	_preview_effect_stream = null
	_event_audio_state.reset()
	_sync_bgm_button()
	_clear_voice_preview(false)


func _clear_preview_route_identity() -> void:
	_preview_event_session = ""
	_catalog_timeline_steps.clear()
	_catalog_timeline_unclassified.clear()
	_catalog_terminal_match.clear()
	_catalog_terminal_rejected_completion = false
	_preview_source_row_index = -1
	_preview_catalog_fragment_index = -1
	_preview_catalog_setup_native_fx_omitted = false
	_preview_event_complete = false
	_preview_completion_shown = false
	_nested_promise_context.clear()
	_nested_promise_reached_boundary = false


func _present_preview_result(result: Dictionary, intro_offset: int) -> void:
	if _preview_event_session == "source_row" and _preview_source_row_index >= 0:
		_preview_entry_label.text = "%s · source row #%04d · intro 0x%X · stopped 0x%X" % [
			_selected_entry,
			_preview_source_row_index,
			intro_offset,
			int(result.offset),
		]
	else:
		_preview_entry_label.text = "%s · intro 0x%X · stopped 0x%X" % [_selected_entry, intro_offset, int(result.offset)]
	_preview_background_label.text = " | ".join([
		_present_latest_mmo_resource(result.trace, str(result.status)),
		_present_latest_ax_resource(result.trace),
		_present_latest_bgm_resource(result.trace),
		_present_latest_voice_marker(result.trace),
	])
	var identity_summary := _effective_identity_summary()
	if not identity_summary.is_empty():
		_preview_background_label.text += " | Effective: %s" % identity_summary
	if str(result.status) == "def_selection_boundary" and not _preview_definitions.is_empty():
		if _activate_confirmed_promise_time_choice(result):
			_show_confirmed_choice_options()
		elif _activate_confirmed_nested_promise_choice(result):
			_show_confirmed_choice_options()
		elif _preview_event_session == "source_row" and _activate_detached_definition_preview(result, intro_offset):
			_show_confirmed_choice_options()
		elif _activate_routine40_result_bridge(result, intro_offset):
			_show_confirmed_choice_options()
		elif _activate_detached_definition_preview(result, intro_offset):
			_show_confirmed_choice_options()
		else:
			var option_lines: Array[String] = []
			for definition in _preview_definitions:
				option_lines.append("%d. %s" % [int(definition.definition_id) + 1, str(definition.text)])
			_preview_message_label.text = "\n".join(option_lines)
			_preview_footer_label.text = "%d original DEF bodies · read-only · selection input unresolved" % _preview_definitions.size()
		return
	if result.has("detached_definition_preview") and _preview_messages.is_empty():
		var detached_preview: Dictionary = result.detached_definition_preview
		_preview_message_label.text = "Detached DEF %d reached %s without dialogue." % [
			int(detached_preview.definition_id) + 1,
			str(result.get("status", "a boundary")).replace("_", " "),
		]
		_preview_footer_label.text = "explicit tool preview; cloned sandbox discarded; caller and native routine-40 result mapping not executed"
		return
	if _preview_messages.is_empty():
		if _preview_event_complete:
			_show_event_complete()
			return
		var setup_terminal := _catalog_setup_extension_terminal(result)
		var setup_terminal_candidate := _is_catalog_setup_extension_terminal_candidate(result) or _is_catalog_setup_extension_phase_result(result)
		var shared_boundary := _shared_routine_boundary(result)
		if not setup_terminal.is_empty():
			_preview_message_label.text = "EVENTD06 setup extension reached %s and stopped safely before shared routine %d." % [
				str(setup_terminal.mmo),
				int(setup_terminal.routine_id),
			]
			_preview_footer_label.text = "source-table setup analysis only ﾂｷ branch global_u8[4000]=%d ﾂｷ host activation and fragment order unresolved ﾂｷ no further continuation" % int(
				setup_terminal.branch_global_u8_4000
			)
		elif setup_terminal_candidate:
			_preview_message_label.text = "EVENTD06 setup extension no longer matches its audited terminal contract. Stopped fail-closed."
			_preview_footer_label.text = "source-table setup analysis only ﾂｷ terminal coordinate/resume/state/trace mismatch ﾂｷ no continuation"
		elif not shared_boundary.is_empty():
			_preview_message_label.text = "Stopped before shared routine %d. Its original library body is indexed for bounded continuation." % int(shared_boundary.routine_id)
			_preview_footer_label.text = "LIBLARY.LIB 0x%X..0x%X · %s · click / Space / Enter / right: Continue (sandbox only)" % [
				int(shared_boundary.body_offset),
				int(shared_boundary.end_offset),
				str(shared_boundary.source),
			]
		elif str(result.status) == "native_selection_boundary":
			var selection_record: Dictionary = result.trace[-1]
			_preview_message_label.text = "Native selection input reached. The original input loop is not simulated."
			_preview_footer_label.text = "%d records (%d text / %d expressions) · sandbox unchanged" % [
				int(selection_record.get("record_count", 0)),
				int(selection_record.get("string_record_count", 0)),
				int(selection_record.get("expression_record_count", 0)),
			]
		elif str(result.status) == "native_script_execution_boundary":
			var script_execution: Dictionary = result.trace[-1]
			_preview_message_label.text = "Original startup would execute %s here." % str(
				script_execution.get("resource_name", "an unknown script")
			)
			_preview_footer_label.text = "subcommand 8 · selector %d · %s · native load/execute/restore confirmed · isolated preview stopped" % [
				int(script_execution.get("execution_selector", -1)),
				str(script_execution.get("execution_role", "unknown role")),
			]
		elif str(result.status) == "native_state_transfer_boundary":
			var state_transfer: Dictionary = result.trace[-1]
			_preview_message_label.text = (
				"Original host-state transfer reached. Relative offset slots %s would be restored from a native record."
				% str(state_transfer.get("mapping_string", "?"))
			)
			_preview_footer_label.text = (
				"subcommand %d · selector %d · offsets only · record contents/physical aliases unresolved · sandbox unchanged"
				% [
					int(state_transfer.get("presentation_subcommand", -1)),
					int(state_transfer.get("transfer_selector", -1)),
				]
			)
		elif str(result.status) == "native_record_boundary":
			var native_record: Dictionary = result.trace[-1]
			_preview_message_label.text = "Native typed-record dispatch reached. State and presentation effects are not executed."
			_preview_footer_label.text = "%d records -> 0x%X · sandbox unchanged" % [
				int(native_record.get("native_record_count", 0)),
				int(native_record.get("end_offset", int(result.offset) + 1)),
			]
			if _continuation_offset >= 0:
				_preview_footer_label.text += " | Continue explicitly omits unresolved native record effects"
		elif str(result.status) == "native_presentation_boundary":
			var presentation_record: Dictionary = result.trace[-1]
			var native_probe: Dictionary = presentation_record.get("native_stream_probe", {})
			var handler_family := str(presentation_record.get("native_handler_family", ""))
			_preview_message_label.text = (
				"Native double-byte character-stream presentation reached. Display and cursor effects are not simulated."
				if handler_family == "double_byte_character_stream_presentation"
				else "Native character-stream presentation reached. Display and cursor effects are not simulated."
			)
			_preview_footer_label.text = "%d probed bytes -> 0x%X (%s) · sandbox unchanged" % [
				int(native_probe.get("consumed_byte_count", 0)),
				int(native_probe.get("probe_end_offset", int(result.offset) + 1)),
				str(native_probe.get("stop_reason", "unknown stop")),
			]
			if _continuation_offset >= 0:
				_preview_footer_label.text += " | Continue omits remaining bounded presentation effects"
		elif str(result.status) in ["definition_invoke_boundary", "library_definition_invoke_boundary"]:
			var definition_record: Dictionary = result.trace[-1]
			_preview_message_label.text = "Native registered DEF invocation reached. The original registered-body caller frame is not simulated."
			_preview_footer_label.text = "DEF %d · registered body/caller context required · sandbox unchanged" % int(
				definition_record.get("definition_id", -1)
			)
			if _continuation_offset >= 0:
				_preview_footer_label.text += " | click / Space / Enter / right: Continue with audited DEF body (presentation effects omitted)"
		elif str(result.status) == "script_dispatch_boundary":
			var dispatch_record: Dictionary = result.trace[-1]
			_preview_message_label.text = "Nested MES dispatch reached: %s" % str(dispatch_record.get("target_entry", "unknown"))
			_preview_footer_label.text = "target script and caller restoration not simulated · sandbox unchanged"
		elif str(result.status) == "script_handoff_boundary":
			var handoff_record: Dictionary = result.trace[-1]
			_preview_message_label.text = "MES handoff marker reached: %s" % str(handoff_record.get("target_entry", "unknown"))
			_preview_footer_label.text = "native active string retained · host-side consumer not simulated · sandbox unchanged"
		elif str(result.status) == "script_return":
			if _preview_event_session == "catalog_setup":
				if str(_active_address_catalog.get("setup_start_kind", "")) == "source_table_entry":
					_preview_message_label.text = "Catalog setup preview ended.\nNo event fragment was selected. Host activation remains unresolved."
					_preview_footer_label.text = (
						"CATALOG SETUP END · source-table analysis · native setup record effects omitted · sandbox changes remain isolated"
						if _preview_catalog_setup_native_fx_omitted
						else "CATALOG SETUP END · source-table analysis · sandbox changes remain isolated"
					)
				else:
					_preview_message_label.text = "Catalog setup preview ended.\nNo event fragment was selected."
					_preview_footer_label.text = (
						"CATALOG SETUP END · native setup record effects omitted · sandbox changes remain isolated"
						if _preview_catalog_setup_native_fx_omitted
						else "CATALOG SETUP END · bounded setup preview · sandbox changes remain isolated"
					)
			elif _preview_event_session == "catalog_fragment" and _preview_catalog_fragment_index > 0:
				_preview_message_label.text = "Fragment preview ended.\nThis source-table row returned without establishing native event order."
				_preview_footer_label.text = "Fragment #%04d of %d · sandbox only · use Prev/Next Row to inspect table order" % [
					_preview_catalog_fragment_index,
					int(_active_address_catalog.get("fragment_count", 0)),
				]
			elif _preview_event_session == "promise_date" and not _active_promise_date_route().is_empty():
				var promise_route := _active_promise_date_route()
				var promise_location := _state.read_value("global_u8", int(promise_route.location_field))
				_preview_message_label.text = "PROMIS scheduling prefix ended.\nThe selected location/time path returned; the original outer caller is not simulated."
				_preview_footer_label.text = "PROMIS PREFIX END · location %d · sandbox state only · event completion unresolved" % promise_location
			else:
				_preview_message_label.text = "Selected MES callee returned. The original caller is not simulated."
				_preview_footer_label.text = "Preview complete · sandbox state only · Esc releases"
		else:
			_preview_message_label.text = "No dialogue was reached before this execution boundary."
			_preview_footer_label.text = "0 messages · click frame to focus · Esc releases"
		return
	_preview_message_index = 0
	_show_preview_message()
	if _continuation_offset >= 0 and _preview_messages.size() == 1:
		_preview_footer_label.text += "  |  click / Space / Enter / right: Continue"


func _is_confirmed_promise_time_choice_boundary(result: Dictionary) -> bool:
	var route := _confirmed_event_start()
	if (
		_preview_event_session != "promise_date"
		or str(route.get("event_start_kind", "")) != PROMISE_DATE_ROUTE_KIND
		or str(_document.get("source", {}).get("resolved_source", "")) != "original_arc"
		or str(result.get("status", "")) != "def_selection_boundary"
		or int(result.get("offset", -1)) != int(route.get("choice_boundary", -2))
		or _state.read_value("state_u16", 10) != _state.read_value("banked_u16", int(route.get("field", -1)), 0)
		or _preview_definitions.size() != 10
	):
		return false
	var trace: Array = result.get("trace", [])
	if (
		trace.is_empty()
		or int(trace[-1].get("routine_id", -1)) != 40
		or int(route.get("choice_resume", -1)) != int(route.get("choice_boundary", -1)) + 5
		or not _promise_choice_resume_reads_state21(route)
	):
		return false
	var expected_ids: Array[int] = []
	for definition_id in range(10):
		expected_ids.append(definition_id)
	var ids: Array[int] = []
	var targets: Array[int] = []
	for definition in _preview_definitions:
		ids.append(int(definition.definition_id))
		targets.append(int(definition.target_offset))
	for target in targets:
		if target < 0 or target >= int(_document.get("header", {}).get("code_size", 0)):
			return false
	return ids == expected_ids


func _promise_choice_resume_reads_state21(route: Dictionary) -> bool:
	var decoder := MesInstructionDecoderScript.new()
	var cursor := int(route.get("choice_resume", -1))
	var limit := int(_document.get("header", {}).get("code_size", 0))
	for _marker_index in range(8):
		var instruction: Dictionary = decoder.decode_at(_document.bytecode, cursor, limit)
		if not instruction.get("ok", false):
			return false
		if str(instruction.get("op", "")) != "source_line_marker":
			if str(instruction.get("op", "")) != "branch_if_not_true":
				return false
			var operands: Array = instruction.get("operands", [])
			if operands.size() < 1:
				return false
			var ast: Dictionary = operands[0].get("value", {}).get("ast", {})
			var lhs: Dictionary = ast.get("lhs", {})
			var rhs: Dictionary = ast.get("rhs", {})
			return (
				str(ast.get("type", "")) == "binary"
				and str(ast.get("op", "")) == "equal"
				and str(lhs.get("type", "")) == "state_ref"
				and str(lhs.get("storage", "")) == "state_u16"
				and str(lhs.get("index", {}).get("type", "")) == "literal"
				and int(lhs.get("index", {}).get("value", -1)) == 21
				and str(rhs.get("type", "")) == "literal"
				and int(rhs.get("value", -1)) == 1
			)
		cursor = int(instruction.get("end_offset", -1))
	return false


func _present_latest_mmo_resource(trace: Array, boundary_status: String) -> String:
	var resource_name := ""
	var resource_names: Array[String] = []
	var resource_trace_by_name: Dictionary = {}
	for record in trace:
		if str(record.get("effect", "")) == "mmo_resource_marker":
			resource_name = str(record.get("resource_name", ""))
			var normalized_resource_name := resource_name.to_upper()
			resource_names.append(normalized_resource_name)
			resource_trace_by_name[normalized_resource_name] = (record as Dictionary).duplicate(true)
	if resource_name.is_empty():
		var retained_layers: Array[String] = []
		if not _preview_dat_pal_name.is_empty():
			retained_layers.append("DAT/PAL unchanged · %s · retained world-map frame" % _preview_dat_pal_status)
		if not _preview_mmo_name.is_empty():
			if _preview_mmo_status.contains("unavailable:"):
				retained_layers.append("MMO unresolved | %s | frame remains empty" % _preview_mmo_status)
			else:
				retained_layers.append("MMO unchanged · %s · retained background" % _preview_mmo_status)
		if not _preview_foreground_mmo_name.is_empty():
			retained_layers.append("foreground unchanged · %s · retained keyed layer" % _preview_foreground_mmo_status)
		if not retained_layers.is_empty():
			return " | ".join(retained_layers)
		game_preview.set_preview_texture(null)
		game_preview.clear_foreground()
		_preview_surface_compositor.clear()
		_preview_surface_background_checkpoint.clear()
		return "%s boundary · no confirmed MMO resource reached" % boundary_status
	if _is_audited_d_pic_standing(resource_name):
		return _present_mmo_foreground(
			resource_name,
			"audited D_PIC standing-only inspection; caller background unresolved",
			false
		)
	return _present_mmo_resource(resource_name, "traced at runtime boundary")


func _present_mmo_resource(resource_name: String, origin: String) -> String:
	_preview_dat_pal_name = ""
	_preview_dat_pal_status = ""
	var resolved := _resolve_mmo_image(resource_name)
	if not resolved.ok:
		_preview_mmo_name = resource_name
		_preview_mmo_status = "%s | %s | unavailable: %s" % [resource_name, origin, str(resolved.error)]
		game_preview.set_preview_texture(null)
		game_preview.clear_foreground()
		_preview_surface_compositor.clear()
		_preview_surface_background_checkpoint.clear()
		_preview_foreground_mmo_name = ""
		_preview_foreground_mmo_status = ""
		return _preview_mmo_status
	var composited := _set_preview_surface_background(resolved.image)
	if not composited.get("ok", false):
		# EP-10 unit 4: NATIVE_CENTERED does not scale, so a picture larger
		# than the 640x400 logical frame is centered past the clipped
		# viewport bounds and its edges are lost. FIT (the game preview's
		# default content mode) scales it down to fit, keeping aspect.
		var oversized := (
			int(resolved.image.get_width()) > ContentToolGamePreview.LOGICAL_SIZE.x
			or int(resolved.image.get_height()) > ContentToolGamePreview.LOGICAL_SIZE.y
		)
		game_preview.set_frame_content_mode(
			ContentToolGamePreview.FrameContentMode.FIT if oversized
			else ContentToolGamePreview.FrameContentMode.NATIVE_CENTERED
		)
		game_preview.set_preview_image(resolved.image)
		_preview_surface_compositor.clear()
		_preview_surface_background_checkpoint.clear()
	game_preview.clear_foreground()
	_preview_foreground_mmo_name = ""
	_preview_foreground_mmo_status = ""
	_preview_mmo_name = resource_name
	var presentation_status := (
		"native subcommand-9 default-origin load confirmed; bound to shared logical surface 0"
		if composited.get("ok", false)
		else "native subcommand-9 default-origin load confirmed; active surface/composition not simulated"
	)
	_preview_mmo_status = "%s · %s · %s · %d×%d tool preview · %s" % [
		resource_name,
		str(resolved.source),
		origin,
		int(resolved.width),
		int(resolved.height),
		presentation_status,
	]
	_preview_mmo_status += " | Effective identity: %s" % str(resolved.identity.label)
	_preview_mmo_status += " | MMO header: %s · effective %s" % [
		str(resolved.header_profile), str(resolved.identity.compatibility),
	]
	return _preview_mmo_status


func _set_preview_surface_background(image: Image) -> Dictionary:
	_preview_surface_compositor.clear()
	_preview_surface_background_checkpoint.clear()
	if image == null or image.is_empty() or image.get_width() != 640 or image.get_height() != 400:
		return {"ok": false, "error": "Event background is not one logical 640x400 surface."}
	var registered := _preview_surface_compositor.register_surface(0, image, "background")
	if not registered.get("ok", false):
		return registered
	var checkpoint := _preview_surface_compositor.capture_checkpoint()
	if not checkpoint.get("ok", false):
		_preview_surface_compositor.clear()
		return checkpoint
	var presented := game_preview.present_compositor_surface(_preview_surface_compositor)
	if not presented.get("ok", false):
		_preview_surface_compositor.clear()
		return presented
	_preview_surface_background_checkpoint = checkpoint.duplicate(true)
	return presented


func _compose_preview_surface_layer(
	source_image: Image,
	source_rect: Rect2i,
	destination: Vector2i,
	retain_as_background := false
) -> Dictionary:
	if _preview_surface_background_checkpoint.is_empty():
		return {"ok": false, "error": "Event compositor background checkpoint is unavailable."}
	var restored := _preview_surface_compositor.restore_checkpoint(_preview_surface_background_checkpoint)
	if not restored.get("ok", false):
		return restored
	var registered := _preview_surface_compositor.register_surface(1, source_image, "source")
	if not registered.get("ok", false):
		return registered
	var applied := _preview_surface_compositor.apply_operations_in_order([{
		"mode": 1,
		"source_surface_index": 1,
		"source_x": source_rect.position.x,
		"source_y": source_rect.position.y,
		"inclusive_right": source_rect.end.x - 1,
		"inclusive_bottom": source_rect.end.y - 1,
		"destination_surface_index": 0,
		"destination_x": destination.x,
		"destination_y": destination.y,
		"rgb_key": Color(0, 1, 0),
	}])
	if not applied.get("ok", false):
		return applied
	var presented := game_preview.present_compositor_surface(_preview_surface_compositor)
	if not presented.get("ok", false):
		return presented
	if retain_as_background:
		var checkpoint := _preview_surface_compositor.capture_checkpoint()
		if not checkpoint.get("ok", false):
			return checkpoint
		_preview_surface_background_checkpoint = checkpoint.duplicate(true)
	return presented


func _restore_preview_surface_background() -> void:
	if _preview_surface_background_checkpoint.is_empty():
		return
	var restored := _preview_surface_compositor.restore_checkpoint(_preview_surface_background_checkpoint)
	if restored.get("ok", false):
		game_preview.present_compositor_surface(_preview_surface_compositor)


func _present_composited_mmo_foreground(resource_name: String, origin: String) -> String:
	var resolved := _resolve_mmo_image(resource_name)
	if not resolved.ok:
		_preview_foreground_mmo_name = ""
		_preview_foreground_mmo_status = ""
		return "%s · %s · %s" % [resource_name, origin, str(resolved.error)]
	var composed := _compose_preview_surface_layer(
		resolved.image,
		Rect2i(0, 0, int(resolved.width), int(resolved.height)),
		Vector2i.ZERO,
		true
	)
	if not composed.get("ok", false):
		_preview_foreground_mmo_name = ""
		_preview_foreground_mmo_status = ""
		return "%s · %s · compositor rejected: %s" % [resource_name, origin, str(composed.get("error", "unknown error"))]
	_preview_foreground_mmo_name = resource_name
	_preview_foreground_mmo_status = "%s · %s · %s · %d×%d RGB-key layer · shared logical compositor" % [
		resource_name,
		str(resolved.source),
		origin,
		int(resolved.width),
		int(resolved.height),
	]
	_preview_foreground_mmo_status += " | Effective identity: %s" % str(resolved.identity.label)
	_preview_foreground_mmo_status += " | MMO header: %s · effective %s" % [
		str(resolved.header_profile), str(resolved.identity.compatibility),
	]
	return _preview_foreground_mmo_status


func _present_mmo_foreground(resource_name: String, origin: String, preserve_background := true) -> String:
	if not preserve_background:
		game_preview.set_preview_texture(null)
		_preview_mmo_name = ""
		_preview_mmo_status = ""
	var resolved := _resolve_mmo_image(resource_name)
	if not resolved.ok:
		_preview_foreground_mmo_name = ""
		_preview_foreground_mmo_status = ""
		game_preview.clear_foreground()
		return "%s · %s · %s" % [resource_name, origin, str(resolved.error)]
	var material := ShaderMaterial.new()
	material.shader = LegacyGreenChromaKeyShader
	material.set_shader_parameter("chroma_key", Color(0, 1, 0))
	game_preview.set_foreground_image(resolved.image, material)
	_preview_foreground_mmo_name = resource_name
	_preview_foreground_mmo_status = "%s · %s · %s · %d×%d green-key foreground · native compositor unresolved" % [
		resource_name,
		str(resolved.source),
		origin,
		int(resolved.width),
		int(resolved.height),
	]
	_preview_foreground_mmo_status += " | Effective identity: %s" % str(resolved.identity.label)
	_preview_foreground_mmo_status += " | MMO header: %s · effective %s" % [
		str(resolved.header_profile), str(resolved.identity.compatibility),
	]
	return _preview_foreground_mmo_status


func _is_audited_d_pic_standing(resource_name: String) -> bool:
	return (
		_selected_entry == "D_PIC.MES"
		and _is_catalog_source_entry(str(_document.get("entry_sha256", "")), "D_PIC.MES")
		and resource_name.to_upper() in AUDITED_D_PIC_STANDING_RESOURCES
	)


func _resolve_mmo_image(resource_name: String) -> Dictionary:
	if not _content_set.is_open() or not _content_set.has_archive("mmo.arc"):
		return {"ok": false, "error": "open ELFIMAGE with mmo.arc to preview"}
	var found := _content_set.find_entry(resource_name, ["mmo.arc"])
	if not found.ok or str(found.archive) != "mmo.arc":
		return {"ok": false, "error": "entry missing from mmo.arc"}
	var descriptor := _resolver.resolve("mmo.arc", resource_name)
	if not descriptor.ok:
		return {"ok": false, "error": "resolver rejected: %s" % str(descriptor.error)}
	var data := _resolver.read_resolved(descriptor)
	if data.is_empty() and not _resolver.last_error.is_empty():
		return {"ok": false, "error": "resolved read failed: %s" % _resolver.last_error}
	var decoded := _mmo_codec.decode_image(data)
	if not decoded.ok:
		return {"ok": false, "error": "MMO decode rejected: %s" % str(decoded.error)}
	var identity := _classify_effective_media("mmo.arc", resource_name, descriptor, data, "image", {
		"ok": true,
		"schema": "kakyu_mmo_image_interface/v1",
		"width": int(decoded.width),
		"height": int(decoded.height),
		"header_schema": str(decoded.header_schema),
		"header_profile": str(decoded.header_profile),
	})
	if not identity.ok:
		return {"ok": false, "error": "content identity rejected: %s" % str(identity.error)}
	return {
		"ok": true,
		"source": str(descriptor.source),
		"image": decoded.image,
		"width": int(decoded.width),
		"height": int(decoded.height),
		"header_profile": str(decoded.header_profile),
		"header_schema": str(decoded.header_schema),
		"identity": identity,
	}


func _classify_effective_media(
	archive_name: String,
	entry_name: String,
	descriptor: Dictionary,
	data: PackedByteArray,
	content_kind: String,
	interface_validation: Dictionary
) -> Dictionary:
	if not _content_set.is_open() or not _content_set.has_archive(archive_name):
		return {"ok": false, "error": "selected original archive is unavailable"}
	var original_reader: KakyuArcReader = _content_set.get_reader(archive_name)
	if original_reader == null:
		return {"ok": false, "error": "selected original reader is unavailable"}
	var original_entry := original_reader.get_entry(entry_name)
	if original_entry.is_empty():
		return {"ok": false, "error": "selected original entry is unavailable"}
	var canonical_entry := str(original_entry.name)
	var identity := _content_identity.classify({
		"archive": archive_name.to_lower(),
		"entry": canonical_entry,
		"original_archive_sha256": original_reader.get_archive_identity_fingerprint(),
		"original_entry_sha256": original_reader.get_entry_fingerprint(canonical_entry),
		"content_kind": content_kind,
	}, original_reader, descriptor, data, interface_validation)
	if identity.ok:
		_effective_media_identities["%s/%s" % [archive_name.to_lower(), canonical_entry.to_upper()]] = identity.duplicate(true)
	return identity


func _present_latest_ax_resource(trace: Array) -> String:
	var resource_name := ""
	var binding_reached := false
	var binding_row := -1
	var binding_column := -1
	for record in trace:
		if str(record.get("effect", "")) == "ax_resource_marker":
			resource_name = str(record.get("resource_name", ""))
		elif str(record.get("effect", "")) == "ax_presentation_binding":
			binding_reached = true
			binding_row = int(record.get("cell_row", -1))
			binding_column = int(record.get("cell_column", -1))
	if resource_name.is_empty():
		var retained_binding_status := _ax_binding_status(
			_preview_ax_binding_table,
			binding_reached,
			binding_row,
			binding_column
		)
		if not _preview_ax_name.is_empty():
			return "AX unchanged | %s%s" % [_preview_ax_status, retained_binding_status]
		if binding_reached:
			return "AX buffer native bind cell (%d,%d) confirmed; loaded AX identity and draw unresolved" % [
				binding_row,
				binding_column,
			]
		return "No confirmed AX metadata reached"
	if not _content_set.is_open() or not _content_set.has_archive("data.arc"):
		_preview_ax_name = ""
		_preview_ax_status = ""
		_preview_ax_binding_table.clear()
		return "%s | open ELFIMAGE with data.arc to inspect" % resource_name
	var found := _content_set.find_entry(resource_name, ["data.arc"])
	if not found.ok or str(found.archive) != "data.arc":
		_preview_ax_name = ""
		_preview_ax_status = ""
		_preview_ax_binding_table.clear()
		return "%s | confirmed Data loader target is missing from the selected data.arc" % resource_name
	var descriptor := _resolver.resolve("data.arc", resource_name)
	if not descriptor.ok:
		_preview_ax_name = ""
		_preview_ax_status = ""
		_preview_ax_binding_table.clear()
		return "%s | resolver rejected: %s" % [resource_name, str(descriptor.error)]
	var data := _resolver.read_resolved(descriptor)
	if data.is_empty() and not _resolver.last_error.is_empty():
		_preview_ax_name = ""
		_preview_ax_status = ""
		_preview_ax_binding_table.clear()
		return "%s | resolved read failed: %s" % [resource_name, _resolver.last_error]
	var inspected := _ax_dword_stream.inspect(data)
	if not inspected.ok:
		_preview_ax_name = ""
		_preview_ax_status = ""
		_preview_ax_binding_table.clear()
		return "%s | AX structure rejected: %s" % [resource_name, str(inspected.error)]
	var animation := _ax_animation_reader.inspect(data)
	if not animation.ok:
		_preview_ax_name = ""
		_preview_ax_status = ""
		_preview_ax_binding_table.clear()
		return "%s | AX animation rejected: %s" % [resource_name, str(animation.error)]
	var binding_table: Dictionary = animation.binding_table
	var identity := _classify_effective_media("data.arc", resource_name, descriptor, data, "animation", {
		"ok": true,
		"schema": "kakyu_ax_animation_interface/v1",
		"row_count": int(binding_table.get("row_count", 0)),
		"column_count": int(binding_table.get("column_count", 0)),
	})
	if not identity.ok:
		_preview_ax_name = ""
		_preview_ax_status = ""
		_preview_ax_binding_table.clear()
		return "%s | content identity rejected: %s" % [resource_name, str(identity.error)]
	_preview_ax_name = resource_name
	_preview_ax_binding_table = binding_table
	_preview_ax_status = "%s | %s | %d raw tokens | 320 cell streams / %d shared draw records bounded | surface 8 (2688x864) -> surface 0 (640x400)" % [
		resource_name,
		str(descriptor.source),
		int(inspected.token_count),
		int(animation.shared_record_count),
	]
	_preview_ax_status += " | Effective identity: %s" % str(identity.label)
	return _preview_ax_status + _ax_binding_status(
		binding_table,
		binding_reached,
		binding_row,
		binding_column
	)


func _ax_binding_status(binding_table: Dictionary, reached: bool, row: int, column: int) -> String:
	if not reached:
		return ""
	if not binding_table.get("ok", false):
		return " | native bind cell (%d,%d) confirmed; loaded AX identity and draw unresolved" % [row, column]
	if row < 0 or row >= int(binding_table.row_count) or column < 0 or column >= int(binding_table.column_count):
		return " | native bind cell (%d,%d) is outside the inspected AX table; draw unresolved" % [row, column]
	var index := row * int(binding_table.column_count) + column
	var target: Dictionary = binding_table.entries[index]
	return " | native bind cell (%d,%d) -> stream 0x%X, start opcode 0x%02X; surface-8 content/tick not simulated" % [
		row,
		column,
		int(target.target_offset),
		int(target.target_first_byte),
	]


func _present_latest_bgm_resource(trace: Array) -> String:
	var resource_name := ""
	var selector := -1
	for record in trace:
		if str(record.get("effect", "")) == "bgm_request":
			resource_name = str(record.get("resource_name", ""))
			selector = int(record.get("bgm_selector", -1))
	if resource_name.is_empty():
		if not _preview_bgm_name.is_empty() and (_preview_bgm_stream != null or KakyuEventPlayerRules.is_headless_display()):
			var retained_status := "playing" if preview_audio.playing else "loaded"
			return "BGM unchanged · %s remains %s" % [_preview_bgm_name, retained_status]
		return "No confirmed BGM request reached"
	return _present_bgm_resource(resource_name, selector)


# EP-10 unit 4: the BGM path `_present_latest_bgm_resource` scans a trace
# for, factored so the group-route presentation timeline can play a
# specific `bgm_request` row's resource without re-scanning a trace for it.
func _present_bgm_resource(resource_name: String, selector: int) -> String:
	if not _content_set.is_open() or not _content_set.has_archive("bgm.arc"):
		return "BGM %d · %s traced · open ELFIMAGE with bgm.arc to preview" % [selector, resource_name]
	var found := _content_set.find_entry(resource_name, ["bgm.arc"])
	if not found.ok or str(found.archive) != "bgm.arc":
		return "BGM %d · %s traced · entry missing from bgm.arc" % [selector, resource_name]
	var resolved := _resolve_audio_payload("bgm.arc", resource_name)
	if not resolved.ok:
		return "BGM %d · %s rejected: %s" % [selector, resource_name, str(resolved.error)]
	var validation: Dictionary = resolved.validation
	var data: PackedByteArray = resolved.data
	var audio_identity := _event_audio_identity(resolved)
	if not audio_identity.ok:
		return "BGM %d · %s rejected: %s" % [selector, resource_name, str(audio_identity.error)]
	var previous_audio_state: Dictionary = _event_audio_state.snapshot()
	var transition: Dictionary = _event_audio_state.request_bgm(audio_identity.identity)
	if not transition.ok:
		return "BGM %d · %s rejected: %s" % [selector, resource_name, str(transition.error)]
	if str(transition.action) == "retain_bgm" and (_preview_bgm_stream != null or KakyuEventPlayerRules.is_headless_display()):
		var retained_status := "playing" if preview_audio.playing else "loaded"
		return "BGM %d · %s · %s (unchanged)" % [selector, resource_name, retained_status]
	if KakyuEventPlayerRules.is_headless_display():
		_preview_bgm_name = resource_name
		_sync_bgm_button()
		return "BGM %d · %s · %s · %d Hz / %d ch · full payload validated (headless)" % [
			selector,
			resource_name,
			str(resolved.source),
			int(validation.sample_rate),
			int(validation.channels),
		]
	var stream := AudioStreamWAV.load_from_buffer(data)
	if stream == null:
		_event_audio_state.stop_bgm()
		var previous_bgm: Dictionary = previous_audio_state.get("bgm", {})
		if not previous_bgm.is_empty():
			_event_audio_state.request_bgm(previous_bgm)
		return "BGM %d · %s passed header validation but Godot decode failed" % [selector, resource_name]
	preview_audio.stop()
	_preview_bgm_name = resource_name
	_preview_bgm_stream = stream
	preview_audio.stream = stream
	preview_audio.play()
	_sync_bgm_button()
	return "BGM %d · %s · %s · %d Hz / %d ch · %s" % [
		selector,
		resource_name,
		str(resolved.source),
		int(validation.sample_rate),
		int(validation.channels),
		"playing",
	]


func _on_bgm_toggle_pressed() -> void:
	if _preview_bgm_stream == null:
		status_label.text = "No decoded event BGM is available for playback."
		return
	if preview_audio.playing:
		preview_audio.stop()
		status_label.text = "Stopped Event Player BGM preview; event state is unchanged."
	else:
		preview_audio.play()
		status_label.text = "Playing %s from the traced event route." % _preview_bgm_name
	_sync_bgm_button()


func _sync_bgm_button() -> void:
	if not is_instance_valid(bgm_toggle_button):
		return
	if _preview_bgm_name.is_empty():
		bgm_toggle_button.disabled = true
		bgm_toggle_button.text = "BGM: —"
	elif _preview_bgm_stream == null:
		bgm_toggle_button.disabled = true
		bgm_toggle_button.text = "BGM validated"
	else:
		bgm_toggle_button.disabled = false
		bgm_toggle_button.text = "Stop BGM" if preview_audio.playing else "Play BGM"


func _present_latest_voice_marker(trace: Array) -> String:
	var resource_name := ""
	for record in trace:
		if str(record.get("effect", "")) == "voice_marker":
			resource_name = str(record.get("resource_name", ""))
	if resource_name.is_empty():
		if not _preview_voice_name.is_empty() and (_preview_voice_stream != null or KakyuEventPlayerRules.is_headless_display()):
			var retained_status := "playing" if preview_voice.playing else "loaded"
			return "Voice %s | %s tool preview retained | native DirectSound Play dispatch confirmed; device output not observed" % [_preview_voice_name, retained_status]
		return "MES voice marker not reached"
	return _present_voice_resource(resource_name)


# EP-10 unit 4: factored the same way as `_present_bgm_resource`, so the
# group-route presentation timeline can play a specific `voice_marker` row's
# resource without re-scanning a trace for it.
func _present_voice_resource(resource_name: String) -> String:
	if not _content_set.is_open():
		_clear_voice_preview()
		return "MES voice marker · %s traced · open ELFIMAGE to preview" % resource_name
	var matching_archives: Array[String] = []
	for archive_name in ["voice.arc", "tina1.arc", "tina2.arc"]:
		if not _content_set.has_archive(archive_name):
			continue
		var candidate_reader: KakyuArcReader = _content_set.get_reader(archive_name)
		if not candidate_reader.get_entry(resource_name).is_empty():
			matching_archives.append(archive_name)
	if matching_archives.is_empty():
		_clear_voice_preview()
		return "MES voice marker · %s traced · entry missing from voice/Tina archives" % resource_name
	var archive_name := matching_archives[0]
	var resolved := _resolve_audio_payload(archive_name, resource_name)
	if not resolved.ok:
		_clear_voice_preview()
		return "MES voice marker · %s rejected: %s" % [resource_name, str(resolved.error)]
	var validation: Dictionary = resolved.validation
	var data: PackedByteArray = resolved.data
	var audio_identity := _event_audio_identity(resolved)
	if not audio_identity.ok:
		_clear_voice_preview()
		return "MES voice marker · %s rejected: %s" % [resource_name, str(audio_identity.error)]
	var bank_note := ""
	if matching_archives.size() > 1:
		bank_note = " · first of %d matching Tina banks" % matching_archives.size()
	if KakyuEventPlayerRules.is_headless_display():
		var transition: Dictionary = _event_audio_state.submit_voice(audio_identity.identity, "replace")
		if not transition.ok:
			_clear_voice_preview()
			return "MES voice marker · %s rejected: %s" % [resource_name, str(transition.error)]
		_preview_voice_name = resource_name
		_preview_voice_archive = archive_name
		return "Voice %s | %s | %s | %d Hz / %d ch | full payload validated (headless)%s | native DirectSound Play dispatch confirmed; device output not observed" % [
			resource_name,
			archive_name,
			str(resolved.source),
			int(validation.sample_rate),
			int(validation.channels),
			bank_note,
		]
	var stream := AudioStreamOggVorbis.load_from_buffer(data)
	if stream == null:
		_clear_voice_preview()
		return "MES voice marker · %s passed header validation but Godot decode failed" % resource_name
	var transition: Dictionary = _event_audio_state.submit_voice(audio_identity.identity, "replace")
	if not transition.ok:
		_clear_voice_preview()
		return "MES voice marker · %s rejected: %s" % [resource_name, str(transition.error)]
	if str(transition.action) == "retain_voice" and _preview_voice_stream != null:
		var retained_status := "playing" if preview_voice.playing else "loaded"
		return "Voice %s | %s | %s tool preview | native DirectSound Play dispatch confirmed; device output not observed" % [resource_name, archive_name, retained_status]
	_clear_voice_preview(false)
	_preview_voice_name = resource_name
	_preview_voice_archive = archive_name
	_preview_voice_stream = stream
	preview_voice.stream = stream
	preview_voice.play()
	return "Voice %s | %s | %s | %d Hz / %d ch | playing tool preview%s | native DirectSound Play dispatch confirmed; device output not observed" % [
		resource_name,
		archive_name,
		str(resolved.source),
		int(validation.sample_rate),
		int(validation.channels),
		bank_note,
	]


func _clear_voice_preview(clear_state: bool = true) -> void:
	if is_instance_valid(preview_voice):
		preview_voice.stop()
		preview_voice.stream = null
	_preview_voice_name = ""
	_preview_voice_archive = ""
	_preview_voice_stream = null
	if clear_state:
		_event_audio_state.clear_voices()


func _event_audio_identity(resolved: Dictionary) -> Dictionary:
	var classified: Dictionary = resolved.get("identity", {})
	var effective: Dictionary = classified.get("effective", {})
	for key in ["archive", "entry", "source", "sha256"]:
		if str(effective.get(key, "")).is_empty():
			return {"ok": false, "error": "effective audio identity is incomplete: %s" % key}
	return {
		"ok": true,
		"identity": {
			"archive": str(effective.archive),
			"entry": str(effective.entry),
			"source": str(effective.source),
			"sha256": str(effective.sha256),
		},
	}


func _resolve_audio_payload(archive_name: String, entry_name: String) -> Dictionary:
	var descriptor := _resolver.resolve(archive_name, entry_name)
	if not descriptor.ok:
		return {"ok": false, "error": str(descriptor.error)}
	var validation: Dictionary
	if str(descriptor.source) == "original_arc":
		var reader: KakyuArcReader = _content_set.get_reader(archive_name)
		if reader == null:
			return {"ok": false, "error": "Resolved original ARC is unavailable in the content set."}
		var entry := reader.get_entry(entry_name)
		if entry.is_empty():
			return {"ok": false, "error": "Resolved original entry is unavailable in the content set."}
		var header := reader.read_entry_range(int(entry.index), 0, mini(64 * 1024, int(entry.size)))
		validation = AudioValidatorScript.validate(entry_name, header, int(entry.size))
		if not validation.ok:
			return {"ok": false, "error": str(validation.error)}
	var data := _resolver.read_resolved(descriptor)
	if data.is_empty() and not _resolver.last_error.is_empty():
		return {"ok": false, "error": _resolver.last_error}
	if str(descriptor.source) != "original_arc":
		validation = AudioValidatorScript.validate(entry_name, data, data.size())
		if not validation.ok:
			return {"ok": false, "error": str(validation.error)}
	var identity := _classify_effective_media(archive_name, entry_name, descriptor, data, "audio", {
		"ok": true,
		"schema": "kakyu_audio_stream_interface/v1",
		"container": str(validation.get("container", "")),
		"codec": str(validation.get("codec", "")),
		"sample_rate": int(validation.get("sample_rate", 0)),
		"channels": int(validation.get("channels", 0)),
	})
	if not identity.ok:
		return {"ok": false, "error": "content identity rejected: %s" % str(identity.error)}
	return {
		"ok": true,
		"source": str(descriptor.source),
		"data": data,
		"validation": validation,
		"identity": identity,
	}


func _effective_identity_summary() -> String:
	var keys: Array = _effective_media_identities.keys()
	keys.sort()
	var parts: Array[String] = []
	for untyped_key in keys:
		var key := str(untyped_key)
		var identity: Dictionary = _effective_media_identities[key]
		parts.append("%s=%s" % [key, str(identity.get("label", "Unsupported"))])
	return ", ".join(parts)


func _show_preview_message() -> void:
	if _preview_message_index < 0 or _preview_message_index >= _preview_messages.size():
		return
	_preview_completion_shown = false
	var message := _preview_messages[_preview_message_index]
	_preview_message_label.text = str(message.text)
	var final_event_message := (
		_preview_event_complete
		and _preview_message_index == _preview_messages.size() - 1
	)
	var final_catalog_message := (
		_preview_event_session == "catalog_fragment"
		and _preview_catalog_fragment_index > 0
		and _preview_result_status == "script_return"
		and _preview_message_index == _preview_messages.size() - 1
	)
	var nested_promise_boundary := (
		_preview_event_session == "nested_promise"
		and _nested_promise_reached_boundary
		and _preview_result_status == "script_dispatch_boundary"
		and _preview_message_index == _preview_messages.size() - 1
	)
	var action_hint := "click / Space / ← →"
	if _preview_detached_definition_id >= 0:
		action_hint = "DETACHED DEF %d %s · explicit tool preview · cloned sandbox discarded · caller not resumed" % [
			_preview_detached_definition_id + 1,
			"COMPLETE" if _preview_result_status == "detached_definition_complete" else "BOUNDARY",
		]
	elif final_event_message:
		action_hint = "EVENT COMPLETE · click / Space / Enter: finish · ←: previous"
	elif nested_promise_boundary:
		action_hint = "L_PROMIS.MES BOUNDARY REACHED - nested choice returned to caller - PROMIS body not executed"
	elif final_catalog_message:
		action_hint = "FRAGMENT END · source-table row only · use Prev/Next Row"
	_preview_footer_label.text = "%d/%d · %s · %s" % [
		_preview_message_index + 1,
		_preview_messages.size(),
		str(message.source),
		action_hint,
	]


func _step_preview_message(delta: int) -> void:
	if _preview_messages.is_empty():
		if delta > 0 and _continuation_offset >= 0:
			_on_continue_pressed()
		return
	if _preview_completion_shown:
		if delta < 0:
			_preview_message_index = _preview_messages.size() - 1
			_apply_timeline_step_for_current_index(false)
			_show_preview_message()
		elif delta > 0 and _continuation_offset >= 0:
			_on_continue_pressed()
		return
	if delta > 0 and _preview_message_index == _preview_messages.size() - 1 and _preview_event_complete:
		if _catalog_playback_active and _view_mode == VIEW_MODE_PLAYBACK and _continuation_offset >= 0:
			_on_continue_pressed()
			return
		_show_event_complete()
		return
	if delta > 0 and _preview_message_index == _preview_messages.size() - 1 and _continuation_offset >= 0:
		_on_continue_pressed()
		return
	var previous_index := _preview_message_index
	_preview_message_index = clampi(_preview_message_index + delta, 0, _preview_messages.size() - 1)
	# Round 2 code review, item 2: a forward press that clamps to the same
	# index (nothing left to advance to) must never re-fire that step's
	# effects or BGM.
	if _preview_message_index != previous_index:
		_apply_timeline_step_for_current_index(delta >= 0)
	_show_preview_message()


## When `_play_group_route` has loaded a presentation timeline, applies the
## step at the current `_preview_message_index` as the shown message
## changes. A no-op for every other preview session (an empty
## `_catalog_timeline_steps`).
func _apply_timeline_step_for_current_index(forward: bool) -> void:
	if _catalog_timeline_steps.is_empty():
		return
	if _preview_message_index < 0 or _preview_message_index >= _preview_messages.size():
		return
	var presentation: Dictionary = _preview_messages[_preview_message_index]
	var step_index := int(presentation.get("_timeline_step_index", -1))
	if step_index < 0 or step_index >= _catalog_timeline_steps.size():
		return
	_apply_timeline_step(_catalog_timeline_steps[step_index], forward)


func _show_event_complete() -> void:
	# Round 2 code review, item 1: the timeline's closing step (rows after
	# the last message, or the only step of a run with no message at all)
	# is applied exactly once, when the last line is passed - never on a
	# later re-entry (`_preview_completion_shown` was already true).
	var already_shown := _preview_completion_shown
	_preview_message_index = _preview_messages.size()
	_preview_completion_shown = true
	if not already_shown and not _catalog_timeline_steps.is_empty():
		var closing_step: Dictionary = _catalog_timeline_steps[-1]
		if bool(closing_step.get("closing", false)):
			_apply_timeline_step(closing_step, true)
	if _show_catalog_terminal_result():
		if not _preview_messages.is_empty():
			_preview_footer_label.text += " · ←: last dialogue"
		return
	_preview_message_label.text = "Event complete.\nNo further confirmed dialogue remains in this event route."
	_preview_footer_label.text = "Confirmed script return reached · sandbox only"
	status_label.text = "Confirmed event complete; original ARC and gameplay saves unchanged"
	if not _preview_messages.is_empty():
		_preview_footer_label.text += " · ←: last dialogue"


func _show_catalog_terminal_result() -> bool:
	if not _catalog_playback_active or not _catalog_terminal_match.get("ok", false):
		return false
	# Round 2 code review, item 2: a group-route play (a loaded presentation
	# timeline) renders its matched terminal stage regardless of
	# `route_ended` - the run ended there whatever its outcome, including
	# an `analysis_boundary` stage with an unresolved outcome, which is a
	# legitimate ending for a group route, not an incomplete one. Every
	# other catalog playback session keeps requiring `route_ended`.
	var is_group_route_play := not _catalog_timeline_steps.is_empty()
	if not is_group_route_play and not bool(_catalog_terminal_match.get("route_ended", false)):
		return false
	# EP-12 gallery (2026-10-04): a matched `callee_return_only` terminal of a
	# row that also declares where its flow goes next is phrased by the row's
	# route outcome, not as an undeclared continuation.
	var outcome := KakyuEventOutcomeVocabulary.matched_terminal_outcome(_catalog_terminal_match, _catalog_playback_request.get("terminals", []))
	var phrase := KakyuEventOutcomeVocabulary.phrase(outcome)
	if is_group_route_play:
		var ended_at_boundary := str(_catalog_terminal_match.get("kind", "")) == "analysis_boundary"
		_preview_message_label.text = "%s\n%s" % [
			"Route ended at a boundary." if ended_at_boundary else "Route complete.",
			phrase,
		]
	else:
		var display := str(_catalog_terminal_match.get("display", ""))
		match display:
			"event_complete":
				_preview_message_label.text = "Event complete.\n%s" % phrase
			"event_ended_early":
				_preview_message_label.text = "Event ended early.\n%s" % phrase
			"event_rejected":
				_preview_message_label.text = "Event rejected.\n%s" % phrase
			_:
				return false
	var next_target := str(_catalog_terminal_match.get("next_target", ""))
	var host_note := ""
	if str(_catalog_terminal_match.get("phase", "")) == "outer_host_handoff":
		host_note = " · outer host not executed"
	_preview_footer_label.text = "%s · %s · %s:%s@0x%X%s · sandbox only" % [
		str(_catalog_playback_request.get("title", _catalog_playback_request.get("event_id", "Catalog event"))),
		phrase,
		str(_catalog_terminal_match.get("kind", "terminal")),
		str(_catalog_terminal_match.get("owner_entry", "unknown")),
		int(_catalog_terminal_match.get("offset", -1)),
		(" → %s" % next_target if not next_target.is_empty() else "") + host_note,
	]
	status_label.text = "%s: %s; original ARC and gameplay saves unchanged" % [
		str(_catalog_playback_request.get("title", "Catalog event")),
		phrase,
	]
	return true


func _activate_confirmed_promise_time_choice(result: Dictionary) -> bool:
	if not _is_confirmed_promise_time_choice_boundary(result):
		return false
	var route := _confirmed_event_start()
	_choice_projection = {
		"kind": "promise_time",
		"anchor_offset": int(route.choice_boundary),
		"resume_offset": int(route.choice_resume),
		"state_index": 21,
	}
	_choice_index = 0
	return true


func _activate_confirmed_nested_promise_choice(result: Dictionary) -> bool:
	var validation: Dictionary = result.get("nested_promise_validation", {})
	if (
		_preview_event_session != "nested_promise"
		or not validation.get("ok", false)
		or str(validation.get("phase", "")) != "choice"
		or _nested_promise_context.is_empty()
	):
		return false
	_choice_projection = {
		"kind": "nested_promise",
		"anchor_offset": int(_nested_promise_context.get("route", {}).get("intro", -1)),
	}
	_choice_index = 0
	return true


func _activate_routine40_result_bridge(result: Dictionary, intro_offset: int) -> bool:
	if not _document.get("bytecode", null) is PackedByteArray:
		return false
	var code_size := int(_document.get("header", {}).get("code_size", 0))
	var contract := MesRoutine40ChoiceContractScript.new().build(
		_document.bytecode,
		code_size,
		result,
		_routine40_source_identity()
	)
	if not contract.get("ok", false):
		return false
	var gate: Dictionary = contract.get("gate", {})
	var gate_value := -1
	if not gate.is_empty():
		var gate_values: Array = gate.get("values", [])
		if str(gate.get("storage", "")) != "global_u8" or gate_values.is_empty():
			return false
		gate_value = _state.read_value("global_u8", int(gate.get("index", -1)))
		if not gate_values.has(gate_value):
			return false
	_choice_projection = {
		"kind": "routine40_result_bridge",
		"anchor_offset": intro_offset,
		"resume_offset": int(contract.resume_offset),
		"state_index": int(contract.result_index),
		"argument_slots": result.get("argument_slots", {}).duplicate(true),
		"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
		"contract": contract.duplicate(true),
		"gate": gate.duplicate(true),
		"gate_value": gate_value,
	}
	_choice_index = 0
	return true


func _routine40_source_identity() -> Dictionary:
	return {
		"entry": _selected_entry,
		"entry_sha256": str(_document.get("entry_sha256", "")),
		"resolved_source": str(_document.get("source", {}).get("resolved_source", "")),
		"archive": str(_document.get("source", {}).get("archive", "mes.arc")),
	}


func _activate_detached_definition_preview(result: Dictionary, intro_offset: int) -> bool:
	if str(result.get("status", "")) != "def_selection_boundary" or _preview_definitions.is_empty():
		return false
	var trace: Array = result.get("trace", [])
	if trace.is_empty() or int(trace[-1].get("routine_id", -1)) != 40:
		return false
	var code_size := int(_document.get("header", {}).get("code_size", 0))
	if code_size <= 0 or not _document.get("bytecode", null) is PackedByteArray:
		return false
	for definition in _preview_definitions:
		var body_offset := int(definition.get("body_offset", -1))
		var target_offset := int(definition.get("target_offset", -1))
		if (
			body_offset < 0
			or target_offset <= body_offset
			or target_offset > code_size
			or int(definition.get("body_size", 0)) != target_offset - body_offset
			or str(definition.get("body_sha256", "")).length() != 64
		):
			return false
	var projection := {
		"kind": "detached_def_preview",
		"anchor_offset": intro_offset,
		"definition_group_order": (result.get("definition_group_order", []) as Array).duplicate(),
		"selection_definition_group": int(result.get("selection_definition_group", -1)),
		"registered_definition_count": int(result.get("registered_definition_count", _preview_definitions.size())),
	}
	if (result.get("definition_groups", {}) as Dictionary).size() > 1:
		var group_contract := MesRoutine40GroupPreviewContractScript.new().build(
			_document.bytecode,
			code_size,
			result,
			_routine40_source_identity()
		)
		if group_contract.get("ok", false):
			var preview_groups := {}
			for untyped_selector in group_contract.get("group_order", []):
				var selector := int(untyped_selector)
				var preview_rows: Array[Dictionary] = []
				for untyped_definition in (result.get("definition_groups", {}) as Dictionary).get(selector, []):
					preview_rows.append(_preview_definition_descriptor(untyped_definition))
				preview_groups[selector] = preview_rows
			projection.merge({
				"kind": "routine40_group_analysis_preview",
				"stage": "first",
				"contract": group_contract.duplicate(true),
				"group_previews": preview_groups,
			}, true)
	_choice_projection = projection
	_choice_index = 0
	return true


func _preview_definition_descriptor(untyped_definition: Variant) -> Dictionary:
	if not untyped_definition is Dictionary:
		return {}
	var definition: Dictionary = untyped_definition
	var text_parts: Array[String] = []
	for untyped_message in definition.get("messages", []):
		text_parts.append(str(_resolve_message_presentation(untyped_message).text))
	return {
		"definition_id": int(definition.get("definition_id", -1)),
		"source_offset": int(definition.get("source_offset", -1)),
		"body_offset": int(definition.get("body_offset", -1)),
		"target_offset": int(definition.get("target_offset", -1)),
		"body_size": int(definition.get("body_size", 0)),
		"body_sha256": str(definition.get("body_sha256", "")),
		"text": "".join(text_parts),
	}


func _show_confirmed_choice_options() -> void:
	if _choice_projection.is_empty() or _preview_definitions.is_empty():
		return
	var option_lines: Array[String] = []
	for index in _visible_choice_indices():
		var definition: Dictionary = _preview_definitions[index]
		var marker := ">" if index == _choice_index else " "
		var route_tag := ""
		if str(_choice_projection.get("kind", "")) == "promise_time":
			route_tag = _promise_option_route_tag(index + 1)
		var display_number := (
			index + 1
			if str(_choice_projection.get("kind", "")) == "routine40_result_bridge"
			else int(definition.definition_id) + 1
		)
		option_lines.append("%s %d. %s%s" % [marker, display_number, str(definition.text), route_tag])
	_preview_message_label.text = "\n".join(option_lines)
	var event_name := str(_choice_projection.get("kind", "confirmed event")).to_upper()
	var number_hint := "1-%d" % _preview_definitions.size() if _preview_definitions.size() <= 9 else "1-9/0"
	if str(_choice_projection.get("kind", "")) == "detached_def_preview":
		if (_choice_projection.get("definition_group_order", []) as Array).size() > 1:
			_preview_footer_label.text = "Explicit grouped DEF preview · first-stage group %d · option %d/%d · Up/Down: select · Enter or %s: inspect body · %d total registered rows; second-stage input/result not executed" % [
				int(_choice_projection.get("selection_definition_group", -1)),
				_choice_index + 1,
				_preview_definitions.size(),
				number_hint,
				int(_choice_projection.get("registered_definition_count", 0)),
			]
			return
		_preview_footer_label.text = "Explicit detached DEF preview · option %d/%d · Up/Down: select · Enter or %s: inspect body · caller/result mapping not executed" % [
			_choice_index + 1,
			_preview_definitions.size(),
			number_hint,
		]
		return
	if str(_choice_projection.get("kind", "")) == "routine40_group_analysis_preview":
		var grouped_stage := str(_choice_projection.get("stage", "first"))
		if grouped_stage == "second":
			var consumer_hint := _routine40_group_consumer_hint(
				_choice_projection, _choice_index + 1
			)
			_preview_footer_label.text = "Routine 40 grouped analysis · first result %d -> group %d · second option %d/%d · %s · Up/Down: select · Enter or %s: inspect body · cloned sandbox only; consumer and caller resume not executed" % [
				int(_choice_projection.get("first_result", -1)),
				int(_choice_projection.get("group_selector", -1)),
				_choice_index + 1,
				_preview_definitions.size(),
				consumer_hint,
				number_hint,
			]
		else:
			_preview_footer_label.text = "Routine 40 grouped analysis · first-stage group 0 · option %d/%d · Up/Down: select · Enter or %s: inspect mapped second-stage group · %d retained rows; no gameplay state or caller resume" % [
				_choice_index + 1,
				_preview_definitions.size(),
				number_hint,
				int(_choice_projection.get("registered_definition_count", 0)),
			]
		return
	if str(_choice_projection.get("kind", "")) == "routine40_result_bridge":
		var gate_hint := ""
		var bridge_gate: Dictionary = _choice_projection.get("gate", {})
		if not bridge_gate.is_empty():
			gate_hint = " · preserve %s[%d]=%d" % [
				str(bridge_gate.get("storage", "")),
				int(bridge_gate.get("index", -1)),
				int(_choice_projection.get("gate_value", -1)),
			]
		_preview_footer_label.text = "Routine 40 remake bridge · option %d/%d%s · Up/Down: select · Enter or %s: write caller-visible result and resume · native helper input/effects unresolved" % [
			_choice_index + 1,
			_preview_definitions.size(),
			gate_hint,
			number_hint,
		]
		return
	var route_hint := ""
	if str(_choice_projection.get("kind", "")) == "promise_time":
		var route := _active_promise_date_route()
		if not route.is_empty():
			route_hint = " · L%d: OK/NO/GATE" % _state.read_value(
				"global_u8", int(route.location_field)
			)
	_preview_footer_label.text = "Confirmed %s projection · option %d/%d%s · Up/Down: select · Enter or %s: confirm · sandbox only" % [
		event_name,
		_choice_index + 1,
		_preview_definitions.size(),
		route_hint,
		number_hint,
	]


func _visible_choice_indices() -> Array[int]:
	var indices: Array[int] = []
	if _preview_definitions.size() <= 3:
		for index in range(_preview_definitions.size()):
			indices.append(index)
		return indices
	var first := clampi(_choice_index - 1, 0, _preview_definitions.size() - 3)
	for index in range(first, first + 3):
		indices.append(index)
	return indices


func _move_confirmed_choice(delta: int) -> void:
	if _choice_projection.is_empty() or _preview_definitions.is_empty():
		return
	if str(_choice_projection.get("kind", "")) in ["routine40_result_bridge", "routine40_group_analysis_preview"]:
		_choice_index = clampi(_choice_index + delta, 0, _preview_definitions.size() - 1)
	else:
		_choice_index = wrapi(_choice_index + delta, 0, _preview_definitions.size())
	_show_confirmed_choice_options()


func _confirm_projected_choice(index: int = -1) -> void:
	if _choice_projection.is_empty() or _preview_definitions.is_empty():
		return
	if index >= 0:
		_choice_index = clampi(index, 0, _preview_definitions.size() - 1)
	if _choice_index < 0 or _choice_index >= _preview_definitions.size():
		return
	var projection := _choice_projection.duplicate(true)
	var selection := _choice_index + 1
	if str(projection.get("kind", "")) == "routine40_group_analysis_preview":
		_confirm_grouped_routine40_analysis(_choice_index, projection)
		return
	if str(projection.get("kind", "")) == "detached_def_preview":
		var detached_index := _choice_index
		_clear_choice_projection()
		_run_detached_definition_preview(detached_index, projection)
		return
	if str(projection.get("kind", "")) == "nested_promise":
		var definition_id := int(_preview_definitions[_choice_index].definition_id)
		_clear_choice_projection()
		_run_nested_promise_route(definition_id)
		if _nested_promise_reached_boundary:
			status_label.text = "Nested L_TALK30 choice %d returned to %s and reached the audited L_PROMIS.MES boundary; PROMIS body not executed" % [
				definition_id + 1,
				str(_nested_promise_context.get("root_entry", "caller")),
			]
		return
	if str(projection.get("kind", "")) == "routine40_result_bridge":
		var contract: Dictionary = projection.get("contract", {})
		var validation := MesRoutine40ChoiceContractScript.new().validate(
			_document.get("bytecode", PackedByteArray()),
			int(_document.get("header", {}).get("code_size", 0)),
			contract
		)
		if (
			not validation.get("ok", false)
			or contract.get("source_identity", {}) != _routine40_source_identity()
		):
			_clear_choice_projection()
			status_label.text = "Routine 40 remake bridge rejected a changed source or result consumer before state mutation."
			return
		var gate: Dictionary = contract.get("gate", {})
		if not gate.is_empty():
			var current_gate := _state.read_value("global_u8", int(gate.get("index", -1)))
			if (
				str(gate.get("storage", "")) != "global_u8"
				or not (gate.get("values", []) as Array).has(current_gate)
				or current_gate != int(projection.get("gate_value", -1))
			):
				_clear_choice_projection()
				status_label.text = "Routine 40 remake bridge rejected a changed or unsupported result gate before state mutation."
				return
	var before := _state.snapshot()
	_state.write_value("state_u16", int(projection.state_index), selection)
	_clear_choice_projection()
	var result := _runner.run(
		_document.bytecode,
		int(projection.resume_offset),
		_state,
		int(_document.header.code_size),
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{
			"protagonist_name": protagonist_name_edit.text,
			"address_table_offsets": _document.get("header", {}).get("entry_offsets", []).duplicate(),
			"native_record_policy": "stop",
			"argument_slots": projection.get("argument_slots", {}).duplicate(true),
			"persistent_expression_stack": projection.get("persistent_expression_stack", []).duplicate(),
			"registered_definitions": {},
		}
	)
	_attach_registered_definition_context(result, _audited_startup_registered_definitions())
	result["state_diff"] = _state.diff(before)
	var projection_kind := str(projection.get("kind", "event"))
	result["choice_projection"] = {
		"kind": "remake_routine40_result_bridge" if projection_kind == "routine40_result_bridge" else "confirmed_%s" % projection_kind,
		"selection": selection,
		"storage": "state_u16",
		"index": int(projection.state_index),
		"resume_offset": int(projection.resume_offset),
	}
	if projection_kind == "routine40_result_bridge":
		var bridge_contract: Dictionary = projection.get("contract", {})
		result.choice_projection.merge({
			"contract_schema": str(bridge_contract.get("schema", "")),
			"input_policy": str(bridge_contract.get("input_policy", "")),
			"native_input_semantics": str(bridge_contract.get("native_input_semantics", "")),
			"omitted_native_effects": (bridge_contract.get("omitted_native_effects", []) as Array).duplicate(),
			"consumer_kind": str(bridge_contract.get("consumer_kind", "")),
			"gate": (bridge_contract.get("gate", {}) as Dictionary).duplicate(true),
			"gate_value": int(projection.get("gate_value", -1)),
		}, true)
	_show_result(result, int(projection.anchor_offset))
	status_label.text = (
		"Routine 40 remake choice %d wrote caller-visible state_u16[21] and resumed the exact MES consumer%s; native helper input/effects remain unresolved"
		% [
			selection,
			(
				" while preserving global_u8[%d]=%d" % [
					int((projection.get("gate", {}) as Dictionary).get("index", -1)),
					int(projection.get("gate_value", -1)),
				]
				if not (projection.get("gate", {}) as Dictionary).is_empty()
				else ""
			),
		]
		if projection_kind == "routine40_result_bridge"
		else "%s choice %d projected in isolated sandbox; original ARC and gameplay saves unchanged" % [projection_kind.to_upper(), selection]
	)
	_continue_catalog_playback_if_needed()


func _confirm_grouped_routine40_analysis(index: int, projection: Dictionary) -> void:
	var contract: Dictionary = projection.get("contract", {})
	var validation := MesRoutine40GroupPreviewContractScript.new().validate(
		_document.get("bytecode", PackedByteArray()),
		int(_document.get("header", {}).get("code_size", 0)),
		contract
	)
	if (
		not validation.get("ok", false)
		or contract.get("source_identity", {}) != _routine40_source_identity()
	):
		_clear_choice_projection()
		status_label.text = "Routine 40 grouped analysis rejected changed source bytes or group topology; sandbox unchanged."
		return
	if str(projection.get("stage", "first")) == "first":
		var first_result := index + 1
		var second_rows: Array = (projection.get("group_previews", {}) as Dictionary).get(first_result, [])
		if second_rows.is_empty():
			var empty_plan := _routine40_group_consumer_plan(
				projection.merged({"first_result": first_result}, true), 0xFFFF
			)
			if (
				not empty_plan.get("ok", false)
				or str(empty_plan.get("execution", {}).get("mode", ""))
					!= "stop_at_empty_list_boundary"
			):
				_clear_choice_projection()
				status_label.text = "Routine 40 grouped analysis rejected an unqualified empty-list result; sandbox unchanged."
				return
			_clear_choice_projection()
			_preview_definitions.clear()
			_preview_message_label.text = "First result %d selects empty group %d. The native second list returns 0xFFFF." % [first_result, first_result]
			_preview_footer_label.text = "Routine 40 grouped analysis stopped at the confirmed empty-list boundary · state_u16[21]/[13], post-return dispatch, and caller resume not executed · sandbox unchanged"
			status_label.text = "Routine 40 grouped analysis reached empty group %d; native 0xFFFF boundary retained without gameplay-state mutation" % first_result
			return
		projection["stage"] = "second"
		projection["first_result"] = first_result
		projection["group_selector"] = first_result
		_choice_projection = projection
		_preview_definitions = second_rows.duplicate(true)
		_choice_index = 0
		_show_confirmed_choice_options()
		status_label.text = "Routine 40 first result %d maps to retained group %d; choose a row for disposable body inspection" % [first_result, first_result]
		return
	var first_result := int(projection.get("first_result", -1))
	var second_result := index + 1
	var consumer_plan := _routine40_group_consumer_plan(projection, second_result)
	if (
		not consumer_plan.get("ok", false)
		or str(consumer_plan.get("execution", {}).get("mode", ""))
			!= "run_source_qualified_consumer"
	):
		_clear_choice_projection()
		status_label.text = "Routine 40 grouped analysis rejected a changed or unqualified consumer before sandbox mutation."
		return
	var consumer_hint := _routine40_group_consumer_hint_from_plan(consumer_plan)
	_clear_choice_projection()
	_run_detached_definition_preview(index, projection)
	_preview_footer_label.text += " | grouped analysis result %d/%d · %s; consumer not executed; caller dispatch not resumed" % [first_result, second_result, consumer_hint]
	status_label.text = "Routine 40 grouped analysis inspected result %d/%d in a cloned sandbox; %s retained structurally; state_u16[21]/[13] and caller remain unchanged" % [first_result, second_result, consumer_hint]


func _routine40_group_consumer_hint(projection: Dictionary, second_result: int) -> String:
	return _routine40_group_consumer_hint_from_plan(
		_routine40_group_consumer_plan(projection, second_result)
	)


func _routine40_group_consumer_plan(
	projection: Dictionary, second_result: int
) -> Dictionary:
	if not _document.get("bytecode", null) is PackedByteArray:
		return {"ok": false, "error": "No active MES bytecode."}
	return EventPlayerRoutine40ConsumerPlanScript.new().build(
		_document.bytecode,
		int(_document.get("header", {}).get("code_size", 0)),
		projection.get("contract", {}),
		int(projection.get("first_result", -1)),
		second_result
	)


func _routine40_group_consumer_hint_from_plan(plan: Dictionary) -> String:
	if not plan.get("ok", false):
		return "consumer coordinate unresolved"
	var route: Dictionary = plan.get("route", {})
	match str(route.get("resolution", "")):
		"stored_consumer_coordinate":
			return "consumer 0x%X" % int(route.get("destination_offset", -1))
		"stored_default_continuation":
			return "unmatched -> fallback 0x%X (meaning unresolved)" % int(
				route.get("destination_offset", -1)
			)
		"native_empty_list_boundary":
			return "empty-list result 0xFFFF"
	return "consumer coordinate unresolved"


func _run_detached_definition_preview(index: int, projection: Dictionary) -> void:
	if index < 0 or index >= _preview_definitions.size():
		status_label.text = "Detached DEF preview selection is outside the available body list."
		return
	var definition: Dictionary = _preview_definitions[index]
	var code: PackedByteArray = _document.get("bytecode", PackedByteArray())
	var result := _detached_definition_preview.run(
		code,
		definition,
		_state,
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{
			"address_table_offsets": _document.get("header", {}).get("entry_offsets", []),
			"protagonist_name": protagonist_name_edit.text,
			"registered_definitions": _audited_startup_registered_definitions(),
		}
	)
	_show_result(result, int(projection.get("anchor_offset", int(definition.get("body_offset", -1)))))
	if result.get("ok", false):
		status_label.text = "Detached DEF %d preview complete with %d messages; cloned sandbox discarded, caller not resumed" % [
			int(definition.definition_id) + 1,
			(result.get("messages", []) as Array).size(),
		]
	else:
		status_label.text = "Detached DEF %d preview stopped at %s; cloned sandbox discarded, caller not resumed" % [
			int(definition.definition_id) + 1,
			str(result.get("terminal_status", result.get("status", "unknown"))),
		]


func _on_game_preview_input(event: InputEvent, logical_position: Vector2) -> void:
	if not _choice_projection.is_empty():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if logical_position.y >= 286.0 and logical_position.y < 360.0:
				var visible_indices := _visible_choice_indices()
				var row_height := 74.0 / float(visible_indices.size())
				var visible_row := clampi(
					int((logical_position.y - 286.0) / row_height),
					0,
					visible_indices.size() - 1
				)
				_confirm_projected_choice(visible_indices[visible_row])
			return
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_UP, KEY_LEFT:
					_move_confirmed_choice(-1)
				KEY_DOWN, KEY_RIGHT:
					_move_confirmed_choice(1)
				KEY_SPACE, KEY_ENTER:
					_confirm_projected_choice()
				KEY_1:
					_confirm_projected_choice(0)
				KEY_2:
					_confirm_projected_choice(1)
				KEY_3:
					_confirm_projected_choice(2)
				KEY_4:
					_confirm_projected_choice(3)
				KEY_5:
					_confirm_projected_choice(4)
				KEY_6:
					_confirm_projected_choice(5)
				KEY_7:
					_confirm_projected_choice(6)
				KEY_8:
					_confirm_projected_choice(7)
				KEY_9:
					_confirm_projected_choice(8)
				KEY_0:
					_confirm_projected_choice(9)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_step_preview_message(1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER, KEY_RIGHT:
				_step_preview_message(1)
			KEY_LEFT:
				_step_preview_message(-1)
