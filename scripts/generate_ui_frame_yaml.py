#!/usr/bin/env python3
"""Generate YAML documentation for UI frames grouped by category."""
from __future__ import annotations

import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence

SOURCE_FILE = Path('DOCU/NOD_Konzept_Funktionsliste.txt')
OUTPUT_DIR = Path('docu/ui_frames')
MAX_ENTRIES_PER_FILE = 500
AUTO_MIN_GROUP_SIZE = 10

@dataclass
class FrameRecord:
    name: str
    type: str

@dataclass
class CategoryRule:
    name: str
    patterns: Sequence[str]
    description: str

MANUAL_RULES: Sequence[CategoryRule] = (
    CategoryRule(
        name='chat',
        patterns=(
            'Chat', 'Whisper', 'Channel', 'Say', 'VoiceChat', 'TextToSpeech',
            'Emote', 'BN', 'Conversation', 'QuickJoin', 'VoiceActivity',
        ),
        description='Chat panels, communication controls, and related voice or text UI.',
    ),
    CategoryRule(
        name='map',
        patterns=(
            'WorldMap', 'Minimap', 'Map', 'ZoneText', 'Waypoint', 'FlightMap',
            'BattlefieldMap', 'QuestMap', 'Navigation', 'ScenarioQueueFrame',
            'AreaPOI', 'ZoneAbility',
        ),
        description='World map, minimap, and navigation related frames and helpers.',
    ),
    CategoryRule(
        name='mail',
        patterns=(
            'Mail', 'SendMail', 'Inbox', 'OpenMail', 'MailFrame', 'MailItem',
            'Postmaster', 'Postal',
        ),
        description='Mailbox interaction, send mail UI, and attachment handling.',
    ),
    CategoryRule(
        name='tooltip',
        patterns=(
            'GameTooltip', 'ItemRefTooltip', 'ShoppingTooltip', 'EmbeddedItemTooltip',
            'Tooltip', 'CompareTooltip', 'Hover', 'AuraTooltip', 'NamePlateTooltip',
            'FloatingBattlePetTooltip', 'BattlePetTooltip', 'WorldMapTooltip',
            'ItemSocketingTooltip',
        ),
        description='Tooltip overlays and comparison tooltip helpers.',
    ),
    CategoryRule(
        name='unitframes',
        patterns=(
            'PlayerFrame', 'TargetFrame', 'FocusFrame', 'PartyFrame', 'PartyMember',
            'Raid', 'CompactRaid', 'CompactUnit', 'Boss', 'Arena', 'PetFrame', 'PetAction',
            'Vehicle', 'HealthBar', 'ManaBar', 'StatusBar', 'PowerBar', 'Rune',
            'Totem', 'MirrorTimer', 'Combo', 'ClassPower', 'MainTank', 'MainAssist',
            'NamePlate', 'AlternatePower', 'MonkHarmony', 'SoulShard', 'TotemFrame',
            'RuneFrame', 'BossTargetFrame', 'ArenaPrepFrame', 'PlayerPowerBar',
            'PaladinPowerBar', 'PriestBar', 'ShardBar', 'BurningEmbers',
        ),
        description='Unit frames for players, parties, raids, bosses, and their resources.',
    ),
    CategoryRule(
        name='castbars',
        patterns=(
            'CastingBar', 'CastBar', 'CastTimer', 'SpellQueue', 'Latency',
            'ChannelBar', 'SpellProgress', 'CastingTimer',
        ),
        description='Cast bar overlays, spell progress indicators, and latency readouts.',
    ),
    CategoryRule(
        name='actionbars',
        patterns=(
            'ActionBar', 'ActionButton', 'MultiBar', 'MultiCast', 'StanceButton', 'PetActionButton',
            'OverrideActionBar', 'PossessButton', 'VehicleMenuBar', 'MicroButtonAndBagsBar',
            'MainMenuBar', 'BonusActionBar', 'PetBattleActionBar', 'StatusTrackingBar',
            'TempEnchant',
        ),
        description='Action bar layouts, stance bars, and vehicle/override controls.',
    ),
    CategoryRule(
        name='combatlog',
        patterns=(
            'CombatLog', 'CombatText', 'ScrollingCombatText', 'CombatConfig',
            'DamageTaken', 'EventParser', 'MissType', 'LogScroll', 'DeathRecap',
        ),
        description='Combat log panels, parsing helpers, and scrolling combat text widgets.',
    ),
    CategoryRule(
        name='config',
        patterns=(
            'InterfaceOptions', 'VideoOptions', 'AudioOptions', 'Options', 'Settings',
            'Slider', 'CheckButton', 'ColorPicker', 'SavedVariable', 'Preference',
            'Binding', 'KeyBinding', 'MacroOptions', 'Profile', 'UIPanelOptions', 'Addon',
        ),
        description='Configuration panels, settings sliders, and persistent profile helpers.',
    ),
    CategoryRule(
        name='debug',
        patterns=(
            'Debug', 'DevTools', 'Error', 'Bug', 'Trace', 'EventTrace', 'ScriptErrors',
        ),
        description='Developer tooling, debug overlays, error handlers, and trace logs.',
    ),
    CategoryRule(
        name='inventory',
        patterns=(
            'ContainerFrame', 'Bag', 'BankFrame', 'ReagentBank', 'Backpack', 'Inventory',
            'CharacterBag', 'ItemButton', 'ItemSlot', 'EquipmentManager', 'PaperDoll',
            'EquipmentFlyout', 'Wardrobe', 'Heirlooms',
        ),
        description='Inventory, bag, bank, and equipment management frames.',
    ),
    CategoryRule(
        name='character',
        patterns=(
            'CharacterFrame', 'Character', 'Inspect', 'PaperDollFrame', 'ReputationFrame',
            'TokenFrame', 'ArtifactFrame', 'Transmogrify', 'Soulbind', 'Covenant',
        ),
        description='Character sheet, inspection, reputation, and covenant panels.',
    ),
    CategoryRule(
        name='quests',
        patterns=(
            'Quest', 'Campaign', 'AdventureJournal', 'QuestLog', 'QuestMap', 'QuestFrame',
            'QuestTimer', 'QuestPOI', 'QuestChoice', 'WatchFrame',
        ),
        description='Quest log panels, campaign trackers, and quest reward dialogs.',
    ),
    CategoryRule(
        name='guild',
        patterns=(
            'Guild', 'GuildControl', 'GuildBank', 'GuildFrame', 'GuildRoster', 'CommunitiesGuild',
            'CommunitiesFrame', 'Petition',
        ),
        description='Guild roster, bank, and rank management frames.',
    ),
    CategoryRule(
        name='friends',
        patterns=(
            'Friends', 'QuickJoin', 'BattleTagInvite', 'RecruitAFriend', 'AddFriend', 'WhoFrame',
        ),
        description='Friends list, quick-join, and recruit-a-friend panels.',
    ),
    CategoryRule(
        name='achievements',
        patterns=(
            'Achievement', 'Criteria', 'Comparison',
        ),
        description='Achievement summary, progress, and comparison frames.',
    ),
    CategoryRule(
        name='pvp',
        patterns=(
            'PVP', 'Honor', 'Conquest', 'Arena', 'WarGame', 'WorldState', 'Battleground',
            'PvP',
        ),
        description='PvP scoreboards, honor/conquest panels, and battleground status.',
    ),
    CategoryRule(
        name='professions',
        patterns=(
            'TradeSkill', 'Craft', 'Profession', 'PrimaryProfession', 'SecondaryProfession',
            'Archaeology', 'BlackMarket',
        ),
        description='Profession craft windows, archaeology, and related trade skills.',
    ),
    CategoryRule(
        name='lfg',
        patterns=(
            'LFG', 'LFD', 'LFR', 'RaidFinder', 'GroupFinder', 'QueueStatus', 'ScenarioQueue',
            'PremadeGroups', 'DungeonReadyDialog', 'PVEFrame',
        ),
        description='Looking-for-group tools, dungeon/raid finder panels, and queue dialogs.',
    ),
    CategoryRule(
        name='talents',
        patterns=(
            'Talent', 'Specialization', 'PvpTalent', 'PetTalent', 'Glyph', 'ClassTalent',
        ),
        description='Talent trees, specialization pickers, and glyph panels.',
    ),
    CategoryRule(
        name='spellbook',
        patterns=(
            'SpellBook', 'Spellbook', 'SpellFlyout', 'SpellBookFrame', 'SpellBookSkillLine',
        ),
        description='Spellbook tabs, flyouts, and skill line frames.',
    ),
    CategoryRule(
        name='auction',
        patterns=(
            'Auction', 'AuctionHouse',
        ),
        description='Auction house search, listings, and sell tabs.',
    ),
    CategoryRule(
        name='trade',
        patterns=(
            'TradeFrame', 'TradePlayer', 'TradeRecipient', 'TradeSkillMaster',
        ),
        description='Trade window slots and trade partner inventory displays.',
    ),
    CategoryRule(
        name='merchant',
        patterns=(
            'Merchant', 'Vendor',
        ),
        description='Merchant interaction panes and vendor buy/sell controls.',
    ),
    CategoryRule(
        name='pets',
        patterns=(
            'PetJournal', 'PetStable', 'PetBattle', 'MountJournal', 'ToyBox', 'Heirloom',
        ),
        description='Collections journal entries for pets, mounts, toys, and pet battles.',
    ),
    CategoryRule(
        name='loot',
        patterns=(
            'GroupLoot', 'BonusRoll', 'LootFrame', 'LootHistory',
        ),
        description='Loot roll frames, bonus roll dialogs, and loot history panels.',
    ),
    CategoryRule(
        name='levelup',
        patterns=(
            'LevelUpDisplay', 'PlayerChoice',
        ),
        description='Level-up display banners and player choice reward frames.',
    ),
    CategoryRule(
        name='core',
        patterns=(
            'UIParent', 'WorldFrame', 'MainMenuBar', 'ActionBar', 'MultiBar',
            'ExtraActionBar', 'FrameStack', 'ClickBinding', 'EventDispatcher',
            'FrameRegistrar', 'EventRouter', 'SecureHandler', 'Core', 'UIPanel',
            'MicroButton', 'VehicleMenuBar', 'OverrideActionBar', 'StanceBar',
            'PossessBar', 'PetBattleFrame', 'MainMenu', 'StatusTrackingBar',
        ),
        description='Core dispatcher frames, secure handlers, and shared UI infrastructure.',
    ),
)

AUTO_LABEL_OVERRIDES: Dict[str, str] = {
    'containerframe': 'inventory_containers',
    'worldstatescorebutton': 'pvp_scoreboard_buttons',
    'merchantitem': 'merchant_items',
    'addonlistentry': 'addon_list_entries',
    'pvpteamdetailsbutton': 'pvp_team_details_buttons',
    'dropdownlist': 'dropdown_lists',
    'boss': 'boss_frames',
    'staticpopup': 'static_popup_dialogs',
    'partymemberframe': 'party_member_frames',
    'questloglistscrollframebutton': 'quest_log_scroll_buttons',
    'friendsframefriendsscrollframebutton': 'friends_list_scroll_buttons',
    'whoframebutton': 'who_frame_buttons',
    'bankframeitem': 'bank_items',
    'guildframebutton': 'guild_frame_buttons',
    'reputationbar': 'reputation_bars',
    'guildframeguildstatusbutton': 'guild_status_buttons',
    'characterstatspanecategory': 'character_stats_categories',
    'pvpteam': 'pvp_team_frames',
    'questtimer': 'quest_timer_frames',
    'multicastactionbutton': 'multicast_action_buttons',
    'multibarleftbutton': 'multibar_left_buttons',
    'spellbutton': 'spellbook_buttons',
    'multibarbottomrightbutton': 'multibar_bottom_right_buttons',
    'actionbutton': 'action_bar_buttons',
    'skillrankframe': 'skill_rank_frames',
    'multibarrightbutton': 'multibar_right_buttons',
    'openmailattachmentbutton': 'open_mail_attachment_buttons',
    'multibarbottomleftbutton': 'multibar_bottom_left_buttons',
    'secondaryprofession': 'secondary_profession_frames',
    'mailitem': 'mail_item_slots',
    'stancebutton': 'stance_buttons',
    'petactionbutton': 'pet_action_buttons',
    'friendsframeignorebutton': 'friends_ignore_buttons',
    'tradeplayeritem': 'trade_player_items',
    'traderecipientitem': 'trade_recipient_items',
    'sendmailattachment': 'send_mail_attachments',
    'questtitlebutton': 'quest_title_buttons',
    'primaryprofession': 'primary_profession_frames',
    'overrideactionbarbutton': 'override_actionbar_buttons',
    'skilltypelabel': 'skill_type_labels',
    'friendsfriendsbutton': 'friends_of_friends_buttons',
    'compactraidframe': 'compact_raid_frames',
    'tabardframecustomization': 'tabard_customization_options',
    'rune': 'rune_frames',
    'questprogressitem': 'quest_progress_items',
    'partymemberbufftooltipbuff': 'party_buff_tooltips',
    'compactraidframemanagerdisplayframefilteroptionsfiltergroup': 'compact_raid_manager_filters',
    'itemrefshoppingtooltip': 'itemref_shopping_tooltips',
    'worldmapcomparetooltip': 'world_map_compare_tooltips',
    'lootbutton': 'loot_buttons',
    'shoppingtooltip': 'shopping_tooltips',
    'petstableactivepet': 'pet_stable_active_pets',
    'guildcontrolpopupframecheckbox': 'guild_control_checkboxes',
    'worldstatescorecolumn': 'pvp_score_columns',
    'chatconfigcategoryframebutton': 'chat_config_category_buttons',
    'guildbanktabpermissionstab': 'guild_bank_permissions_tabs',
    'totemframetotem': 'totem_frame_totems',
    'spellbookframetabbutton': 'spellbook_tab_buttons',
    'friendstooltipgameaccount': 'friends_tooltip_game_accounts',
    'guildcontroluiranksettingsframecheckbox': 'guild_rank_settings_checkboxes',
    'combatconfigtab': 'combat_config_tabs',
    'petstablestabledpet': 'pet_stable_stabled_pets',
    'tutorialframealertbutton': 'tutorial_alert_buttons',
    'autocompletebutton': 'autocomplete_buttons',
    'petitionframemembername': 'petition_member_names',
    'mirrortimer': 'mirror_timers',
    'tempenchant': 'temporary_weapon_enchants',
    'characterbag': 'character_bags',
    'embeddeditemtooltiptooltiptextleft': 'embedded_item_tooltip_text_left',
    'chatconfigcombatsettingsfiltersbutton': 'chat_config_combat_filter_buttons',
    'itemreftooltiptextright': 'itemref_tooltip_text_right',
    'scenarioqueueframecooldownframename': 'scenario_queue_cooldown_names',
    'levelupdisplaysideunlockframe': 'levelup_display_side_unlock_frames',
    'raidfinderqueueframecooldownframestatus': 'raidfinder_cooldown_status',
    'embeddeditemtooltiptooltiptextright': 'embedded_item_tooltip_text_right',
    'possessbutton': 'possess_buttons',
    'charactertrinket': 'character_trinket_slots',
    'partymemberbufftooltipdebuff': 'party_debuff_tooltips',
    'embeddeditemtooltiptextright': 'embedded_item_tooltip_text_right_alt',
    'gametooltiptextright': 'game_tooltip_text_right',
    'characterfinger': 'character_ring_slots',
    'compactraidframemanagerdisplayframraidmarkersraidmarker': 'raid_marker_buttons',
    'worldmaptooltiptextleft': 'world_map_tooltip_text_left',
    'worldmaptooltiptextright': 'world_map_tooltip_text_right',
    'embeddeditemtooltiptextleft': 'embedded_item_tooltip_text_left',
    'grouplootframe': 'group_loot_frames',
    'lfdqueueframecooldownframestatus': 'lfd_cooldown_status',
    'nameplatetooltiptextright': 'nameplate_tooltip_text_right',
    'worldmaptooltiptooltiptextright': 'world_map_tooltip_tooltip_text_right',
    'scenarioqueueframecooldownframestatus': 'scenario_queue_cooldown_status',
    'friendsframetab': 'friends_frame_tabs',
    'pvpframetab': 'pvp_frame_tabs',
    'characterframetab': 'character_frame_tabs',
    'gametooltiptextleft': 'game_tooltip_text_left',
    'pvpbannerframecustomization': 'pvp_banner_customization',
    'worldmaptooltiptooltiptextleft': 'world_map_tooltip_tooltip_text_left',
    'groupfinderframegroupbutton': 'group_finder_group_buttons',
    'lfdqueueframecooldownframename': 'lfd_cooldown_names',
    'itemreftooltiptextleft': 'itemref_tooltip_text_left',
}

HEADER_COMMENT = '# Auto-generated from DOCU/NOD_Konzept_Funktionsliste.txt'


def parse_records(source: Path) -> List[FrameRecord]:
    text = source.read_text(encoding='utf-8', errors='ignore')
    raw_entries = text.strip()[1:-1].split('},\n{')
    records: List[FrameRecord] = []
    for raw in raw_entries:
        if 'frameDumpText' in raw:
            continue
        name = None
        frame_type = None
        for line in raw.splitlines():
            line = line.strip()
            if line.startswith('["name"]'):
                name = line.split('=', 1)[1].strip().strip(',').strip('"')
            elif line.startswith('["type"]'):
                frame_type = line.split('=', 1)[1].strip().strip(',').strip('"')
        if name and frame_type:
            records.append(FrameRecord(name=name, type=frame_type))
    return records


def match_rule(name: str, patterns: Sequence[str]) -> bool:
    for pattern in patterns:
        if name.startswith(pattern):
            return True
    return False


def assign_manual(records: Iterable[FrameRecord]) -> tuple[Dict[str, List[FrameRecord]], List[FrameRecord]]:
    buckets: Dict[str, List[FrameRecord]] = {rule.name: [] for rule in MANUAL_RULES}
    leftover: List[FrameRecord] = []
    for record in records:
        matched = False
        for rule in MANUAL_RULES:
            if match_rule(record.name, rule.patterns):
                buckets[rule.name].append(record)
                matched = True
                break
        if not matched:
            leftover.append(record)
    return buckets, leftover


def group_by_prefix(records: Iterable[FrameRecord]) -> Dict[str, List[FrameRecord]]:
    groups: Dict[str, List[FrameRecord]] = defaultdict(list)
    for record in records:
        match = re.match(r'([A-Za-z]+)', record.name)
        prefix = match.group(1).lower() if match else 'misc'
        groups[prefix].append(record)
    return groups


def select_auto_groups(groups: Dict[str, List[FrameRecord]]) -> tuple[Dict[str, List[FrameRecord]], List[FrameRecord]]:
    selected: Dict[str, List[FrameRecord]] = {}
    leftover: List[FrameRecord] = []
    for prefix, items in groups.items():
        if len(items) >= AUTO_MIN_GROUP_SIZE:
            selected[prefix] = items
        else:
            leftover.extend(items)
    return selected, leftover


def sanitize_key(name: str) -> str:
    return name.replace("'", "''")


def resolve_auto_label(prefix: str) -> str:
    normalized = prefix.lower()
    if normalized in AUTO_LABEL_OVERRIDES:
        return AUTO_LABEL_OVERRIDES[normalized]
    return normalized


def chunk_entries(entries: Sequence[FrameRecord], max_size: int = MAX_ENTRIES_PER_FILE) -> List[List[FrameRecord]]:
    return [list(entries[i:i + max_size]) for i in range(0, len(entries), max_size)]


def write_yaml_file(path: Path, category_name: str, description: str, entries: Sequence[FrameRecord]) -> None:
    lines: List[str] = [HEADER_COMMENT, f'# Category: {category_name}', f'# Description: {description}', '']
    for record in entries:
        key = sanitize_key(record.name)
        lines.append(f"'{key}':")
        lines.append(f'  type: {record.type}')
        lines.append("  description: ''")
        lines.append('  source: NOD_Konzept_Funktionsliste.txt')
    lines.append('')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('\n'.join(lines), encoding='utf-8')


def main() -> None:
    records = parse_records(SOURCE_FILE)
    manual_buckets, leftover = assign_manual(records)

    groups = group_by_prefix(leftover)
    auto_groups, unsorted_entries = select_auto_groups(groups)

    # Write manual categories first, splitting when necessary.
    for rule in MANUAL_RULES:
        entries = sorted(manual_buckets[rule.name], key=lambda rec: rec.name)
        if not entries:
            # Ensure the file exists even if empty to signal intentional absence.
            write_yaml_file(OUTPUT_DIR / f'{rule.name}.yaml', rule.name, rule.description, [])
            continue
        chunks = chunk_entries(entries)
        if len(chunks) == 1:
            write_yaml_file(OUTPUT_DIR / f'{rule.name}.yaml', rule.name, rule.description, chunks[0])
        else:
            for index, chunk in enumerate(chunks, start=1):
                suffix = f'_{index}'
                write_yaml_file(OUTPUT_DIR / f'{rule.name}{suffix}.yaml', rule.name, rule.description, chunk)

    # Write auto-generated prefix groups.
    for prefix, entries in sorted(auto_groups.items(), key=lambda item: item[0]):
        label = resolve_auto_label(prefix)
        description = f'Auto-generated group for prefix "{prefix}".'
        sorted_entries = sorted(entries, key=lambda rec: rec.name)
        chunks = chunk_entries(sorted_entries)
        if len(chunks) == 1:
            filename = f'{label}.yaml'
            write_yaml_file(OUTPUT_DIR / filename, label, description, chunks[0])
        else:
            for index, chunk in enumerate(chunks, start=1):
                filename = f'{label}_{index}.yaml'
                write_yaml_file(OUTPUT_DIR / filename, label, description, chunk)

    # Write unsorted entries last.
    unsorted_sorted = sorted(unsorted_entries, key=lambda rec: rec.name)
    write_yaml_file(
        OUTPUT_DIR / 'unsorted.yaml',
        'unsorted',
        'Entries without a dominant prefix grouping (<=500).',
        unsorted_sorted,
    )


if __name__ == '__main__':
    main()
