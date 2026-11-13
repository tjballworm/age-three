// Client <-> server messages. Every message has a `type` discriminator.

import type {
  BattleResult,
  BuildingType,
  AllianceInfo,
  AllianceRank,
  ChatMessage,
  City,
  FortType,
  Ladder,
  LordCity,
  Mail,
  MarketResource,
  MarketView,
  MarchMission,
  MedalCounts,
  MedalId,
  Player,
  PolicyId,
  QuestStatus,
  ReportSummary,
  ResourceType,
  TechId,
  TimedTask,
  TroopType,
} from '@age3/core';

export const PROTOCOL_VERSION = 1;

export interface Envelope<T extends string = string, P = unknown> {
  type: T;
  /** Correlates a server reply with the client request that caused it. */
  id?: number;
  payload: P;
}

// ---------- client -> server ----------

/** Log in with a username and password. The welcome reply carries a token to keep for next time. */
export type LoginMessage = Envelope<'login', { version: number; username: string; password: string }>;
/** Log back in on a new connection with the token from an earlier login. */
export type HelloMessage = Envelope<'hello', { version: number; token: string }>;
export type PingMessage = Envelope<'ping', { at: number }>;
/** Ask for the player's full state (player and cities). */
export type GetStateMessage = Envelope<'getState', Record<string, never>>;

/**
 * Build on a slot, or upgrade what stands there. `slot` is a town plot (0–31), 'townhall', 'walls', or an
 * outskirts field as 'f0'–'f12'. `type` names the building for an empty slot; leave it out to upgrade.
 * The reply is a `state` message.
 */
export type BuildMessage = Envelope<
  'build',
  { cityId: string; slot: number | 'townhall' | 'walls' | `f${number}`; type?: BuildingType }
>;
/** Stop a construction and get its whole cost back. The reply is a `state` message. */
export type CancelBuildMessage = Envelope<'cancelBuild', { cityId: string; taskId: string }>;
/**
 * Research the next level of a tech in the city's Academy, paying now. One research at a time per Academy, and
 * the Academy can't be upgraded meanwhile. The reply is a `state` message; the player's new level arrives with
 * taskDone.
 */
export type ResearchMessage = Envelope<'research', { cityId: string; tech: TechId }>;
/** Stop a research and get its whole cost back. The reply is a `state` message. */
export type CancelResearchMessage = Envelope<'cancelResearch', { cityId: string; taskId: string }>;
/**
 * Train `count` troops in the Barracks on town plot `slot`, paying and taking the idle population now. The batch
 * joins the end of that Barracks' queue (as many batches as its level). The reply is a `state` message; the
 * troops arrive in the city's `troops` with taskDone.
 */
export type TrainMessage = Envelope<
  'train',
  { cityId: string; slot: number; troop: TroopType; count: number }
>;
/** Stop a training batch (running or waiting) and get its cost and people back. The reply is a `state` message. */
export type CancelTrainMessage = Envelope<'cancelTrain', { cityId: string; taskId: string }>;
/**
 * Spend a hero's stat points (from levelling up): each field is how many to add to that stat, all of them at most
 * the hero's `points`. A mayor's Politics adds 1% production per point and speeds up building (x0.995 per point),
 * Attack speeds up training (x0.9986), Intelligence research (x0.995). The reply is a `state` message.
 */
export type AssignPointsMessage = Envelope<
  'assignPoints',
  { cityId: string; heroId: string; politics?: number; attack?: number; intelligence?: number }
>;
/**
 * Build `count` of a wall fortification (trap, abatis, tower, log, trebuchet). Each takes wall space (the walls
 * give 1,000 at Lv1 up to 55,000 at Lv10), costs resources now and needs a walls level and research. The batch
 * joins the end of the walls' queue (as many batches as the walls level). The reply is a `state` message.
 */
export type BuildFortMessage = Envelope<'buildFort', { cityId: string; fort: FortType; count: number }>;
/** Stop a fortification batch (running or waiting) and get its cost back. The reply is a `state` message. */
export type CancelFortMessage = Envelope<'cancelFort', { cityId: string; taskId: string }>;
/**
 * Finishes a building's construction or upgrade for free when it has FREE_SPEEDUP_MS (5 minutes) or less left.
 * Research, training and walls can't be sped up (no_free_speedup). Replies with state.
 */
export type SpeedUpMessage = Envelope<'speedUp', { cityId: string; taskId: string }>;
/** Hire one of the Inn's offers (`offerId` from `city.inn.offers`) into the Feasting Hall, paying its fee. Replies with state. */
export type HireMessage = Envelope<'hire', { cityId: string; offerId: string }>;
/** The Inn's free refresh: swaps its offers for a new set now. The timed refresh (`inn.refreshAt`) stays. Replies with state. */
export type RefreshInnMessage = Envelope<'refreshInn', { cityId: string }>;
/** Send an idle hero away for good; their salary stops. Replies with state. */
export type DismissMessage = Envelope<'dismiss', { cityId: string; heroId: string }>;
/** Make an idle hero the city's mayor (the old one goes back to idle), or `heroId: null` for none. Replies with state. */
export type SetMayorMessage = Envelope<'setMayor', { cityId: string; heroId: string | null }>;
/** Chooses the hero who leads the city's defence (any free hero, the mayor too), or nobody. Replies with state. */
export type SetDefenderMessage = Envelope<'setDefender', { cityId: string; heroId: string | null }>;
/**
 * Rewards a hero for loyalty (max 100), once per hero every 15 minutes: `kind: 'gold'` pays 100 x the hero's level
 * from the city for +5; `kind: 'medal'` spends one of the player's `medal` medals for its loyalty (Cross 5 ...
 * Nation 60). Replies with state.
 */
export type RewardHeroMessage = Envelope<
  'rewardHero',
  { cityId: string; heroId: string; kind: 'gold' | 'medal'; medal?: MedalId }
>;
/** Renames a hero: 1-20 letters, digits, spaces and ' - . (like city names). Replies with state. */
export type RenameHeroMessage = Envelope<'renameHero', { cityId: string; heroId: string; name: string }>;
/**
 * Gives back every stat point spent on the hero (`hero.added`) as unspent points, for level x 1,000 gold, once a
 * day. Replies with state.
 */
export type ResetPointsMessage = Envelope<'resetPoints', { cityId: string; heroId: string }>;
/** Persuades a captive hero (from a captured city) to join for their hiring fee in gold. Release one with dismiss. */
export type PersuadeMessage = Envelope<'persuade', { cityId: string; heroId: string }>;
/** Opens or closes the Rally Spot's gate. Closed, the troops stay out of battles. Replies with state. */
export type SetGateMessage = Envelope<'setGate', { cityId: string; open: boolean }>;
/**
 * Heals wounded troops in the Rally Spot's Medic Camp, at once, for gold (healGold in core); they rejoin the city's
 * troops. Errors: not_enough_wounded, not_enough_resources. Replies with state.
 */
export type HealMessage = Envelope<'heal', { cityId: string; troops: Partial<Record<TroopType, number>> }>;
/**
 * Send a march from a city to x, y. `mission` (default 'attack'):
 * - 'attack': an NPC, lord's town, historic city, another player's city or a valley (a win takes it); needs an
 *   idle hero. `camp` is the camp wave: seconds (0 to 24 hours) the army waits at the target before it attacks.
 * - 'scout': anything but your own cities; needs scouts, a hero is optional (their Intelligence helps).
 * - 'transport': any player's city, your own too; `cargo` is what it delivers (up to the troops' load).
 * - 'reinforce': one of your cities (the troops move there), or an ally's whose Embassy takes garrisons.
 * - 'found': an empty flat; takes 250 workers and 10,000 of each resource and builds a city there.
 * The troops, hero, cargo and the trip's food (marchFood) leave now; the mission happens when the march arrives
 * (a taskDone with `march.won`) and a report follows. Needs a Rally Spot (10,000 troops per level, one march out
 * at a time per level). Replies with state.
 */
export type MarchMessage = Envelope<
  'march',
  {
    cityId: string;
    x: number;
    y: number;
    heroId?: string | null;
    troops: Partial<Record<TroopType, number>>;
    mission?: MarchMission;
    camp?: number;
    cargo?: Partial<Record<ResourceType, number>>;
  }
>;
/**
 * Turn a march around before it attacks (on its way or camping); it takes as long to come home as it has been on
 * the road, at most one trip's time. Troops stationed in an ally's city come the whole way home. Replies with state.
 */
export type RecallMessage = Envelope<'recall', { cityId: string; taskId: string }>;
/**
 * A historic city you hold (cityId) imposes a policy on another lord's city at x, y in its draft area
 * (historicInRange); needs the Earl title or above and a use left today (policiesLeft). Replies with state.
 */
export type ImposePolicyMessage = Envelope<
  'imposePolicy',
  { cityId: string; x: number; y: number; policy: PolicyId }
>;
/** Gives up a valley the city holds (and its bonus). Replies with state. */
export type AbandonValleyMessage = Envelope<'abandonValley', { cityId: string; x: number; y: number }>;
/** The Embassy's "let allies garrison this city" box. Replies with state. */
export type SetGarrisonMessage = Envelope<'setGarrison', { cityId: string; allow: boolean }>;
/** The latest battle reports, newest first. Replies with `reports`. */
export type GetReportsMessage = Envelope<'getReports', Record<string, never>>;
/** Buy items from the shop with a city's gold. The reply is a `state` message (player.items). */
export type BuyItemMessage = Envelope<'buyItem', { cityId: string; item: string; count: number }>;
/** Use one item in a city: a speed-up on one of its tasks (taskId), or a resource item. Replies with `state`. */
export type UseItemMessage = Envelope<'useItem', { cityId: string; item: string; taskId?: string }>;
/** The routine quests. Replies with `quests`. */
export type GetQuestsMessage = Envelope<'getQuests', Record<string, never>>;
/** Claim a done quest's reward into a city (once). Replies with `state`. */
export type ClaimQuestMessage = Envelope<'claimQuest', { cityId: string; questId: string }>;
/** The top 100 of a leaderboard. Replies with `leaderboard`. */
export type GetLeaderboardMessage = Envelope<'getLeaderboard', { board: 'player' | 'hero' | 'alliance' }>;
/** The Marketplace from a city. Replies with `market`. */
export type GetMarketMessage = Envelope<'getMarket', { cityId: string }>;
/**
 * Buy or sell a resource for gold. price is thousandths of a gold per unit (50 = 0.05). Pays up front (the
 * resource, or amount * price / 1000 gold), trades at once with the orders that meet it at their price, and
 * leaves the rest open (as many open orders per city as its Marketplace level). Sellers pay a 0.5% fee. The reply
 * is a `state` message; the trade partners' games are told.
 */
export type MarketOrderMessage = Envelope<
  'marketOrder',
  { cityId: string; side: 'buy' | 'sell'; resource: MarketResource; amount: number; price: number }
>;
/** Cancel an open order; what it holds comes back. The reply is a `state` message. */
export type CancelOrderMessage = Envelope<'cancelOrder', { cityId: string; orderId: string }>;
/** The latest world and alliance chat lines. Replies with `chatHistory`. */
export type GetChatMessage = Envelope<'getChat', Record<string, never>>;
/**
 * Say something in the world or your alliance's channel (200 characters, one line a second). Replies with
 * `chat` (the line); the line is also pushed to every game it reaches, yours included.
 */
export type SendChatMessage = Envelope<'chat', { channel: 'world' | 'alliance'; text: string }>;
/** Your inbox and sent mail. Replies with `mail`. */
export type GetMailMessage = Envelope<'getMail', Record<string, never>>;
/** Mail a player by name. Replies with `mail`; the receiver's game is told (unreadMail goes up). */
export type SendMailMessage = Envelope<'sendMail', { to: string; subject: string; body: string }>;
/** Mark a received mail read, or delete your copy of one. Replies with `mail`. */
export type ReadMailMessage = Envelope<'readMail' | 'deleteMail', { mailId: string }>;
/** The Alliance window's contents. Replies with `alliance`. */
export type GetAllianceMessage = Envelope<'getAlliance', Record<string, never>>;
/**
 * One alliance action; replies with `alliance` (or an error). Founding pays 10,000 gold from a city with Embassy
 * Lv2; joining needs an Embassy. Officers and up invite and accept, Presbyters and up remove lower ranks, Vice
 * Hosts and up set lower ranks, diplomacy and the description; the Host hands over (rank 'host') or disbands.
 */
export type AllianceActionMessage = Envelope<
  'alliance',
  | { action: 'create'; cityId: string; name: string }
  | { action: 'apply'; name: string }
  | { action: 'cancel' | 'accept' | 'reject'; requestId: string }
  | { action: 'invite' | 'kick'; player: string }
  | { action: 'setRank'; player: string; rank: AllianceRank }
  | { action: 'diplomacy'; name: string; status: 'friendly' | 'neutral' | 'hostile' }
  | { action: 'describe'; text: string }
  | { action: 'leave' | 'disband' }
>;
/** One report with the whole battle; marks it read. Replies with `report`. */
export type GetReportMessage = Envelope<'getReport', { reportId: string }>;
/** Marks every report read. Replies with state (the player's unread counts). */
export type ReadAllReportsMessage = Envelope<'readAllReports', Record<string, never>>;
/**
 * One step up the rank or title ladder (nextPromotion in core shows what it needs). The gold comes from the city
 * (whose Town Hall counts for ranks), the medals from the player. Replies with state.
 */
export type PromoteMessage = Envelope<'promote', { cityId: string; ladder: Ladder }>;
/**
 * Comforts a city's people (COMFORTS and comfortEffect in core), once every 15 minutes per city: Disaster Relief
 * pays food and Praying gold, each the population limit, to raise loyalty and lower grievance; Blessing turns gold
 * into food; Population Raising turns food into people. Replies with state.
 */
export type ComfortMessage = Envelope<
  'comfort',
  { cityId: string; kind: 'relief' | 'pray' | 'bless' | 'raise' }
>;
/**
 * A levy from the Town Hall (levyAmount in core): takes one resource from the people at once, up to the cap, for
 * 20 loyalty. Once every 15 minutes per city. Replies with state.
 */
export type LevyMessage = Envelope<'levy', { cityId: string; resource: ResourceType }>;
/** Renames one of your cities: 1 to 20 letters, digits, spaces and ' - . Replies with state. */
export type RenameCityMessage = Envelope<'renameCity', { cityId: string; name: string }>;
/**
 * Takes the building on a slot down one level through the build queue (demolishPlan in core): half its build time,
 * half its cost back when done, an empty plot after Lv1. Cancel it with cancelBuild. Replies with state.
 */
export type DemolishMessage = Envelope<'demolish', { cityId: string; slot: number | string }>;
/**
 * Abandons a city for good. Its heroes move to moveHeroesTo (another of your cities) while its Feasting Hall has
 * room; the rest leave. Not a historic city, and not while troops are out or an attack is on its way. Replies with
 * state.
 */
export type AbandonCityMessage = Envelope<'abandonCity', { cityId: string; moveHeroesTo: string }>;
/** Sets a city's tax rate, a whole number from 0 to 100. Gold per hour changes from now on. Replies with state. */
export type SetTaxMessage = Envelope<'setTax', { cityId: string; taxRate: number }>;

/**
 * A testing command. Target one of your cities with `cityId`, or every city of any player (and their research)
 * with `player` (a username). There is no permission check: every tester can cheat, on any account. Replies with
 * your own state; the other player's open game is pushed theirs as a `state` message with no id.
 */
export type CheatMessage = Envelope<'cheat', CheatTarget & CheatAction>;
export type CheatTarget = { cityId: string; player?: never } | { player: string; cityId?: never };
export type CheatAction =
  /** Adds to each resource (negative takes away, never below 0). May go over the storage limit. */
  | { action: 'addResources'; amounts: Partial<Record<ResourceType, number>> }
  /** Every resource up to the storage limit. */
  | { action: 'fillResources' }
  /** Adds troops (negative takes away, never below 0). */
  | { action: 'addTroops'; troops: Partial<Record<TroopType, number>> }
  /** Adds wounded to the Rally Spot, past its cap (negative takes away, never below 0). */
  | { action: 'addWounded'; troops: Partial<Record<TroopType, number>> }
  /** The population, from 0 up to the city's limit (cottages raise the limit). */
  | { action: 'setPopulation'; amount: number }
  /** loyalty and/or grievance, 0-100 each; also clears the comfort cooldown */
  | { action: 'setLoyalty'; loyalty?: number; grievance?: number }
  /** Every construction, research and training batch in the city finishes now. */
  | { action: 'finishAll' }
  /** The building on a slot at any level, free and with no requirements. Leave out type to keep what is there; level 0 removes it. */
  | {
      action: 'setBuilding';
      slot: number | 'townhall' | 'walls' | `f${number}`;
      type?: BuildingType;
      level: number;
    }
  /** Every building and field in the city at this level (constructions in progress are dropped). */
  | { action: 'levelAll'; level: number }
  /**
   * Replaces the city's buildings with a maxed-out layout, all Lv10: Town Hall, walls, one of every other town
   * building, 6 cottages, Barracks on every plot left, and one of each field. Constructions and training are dropped.
   */
  | { action: 'maxTown' }
  /** One tech at a level (0 forgets it). Research only counts up to each city's Academy level. */
  | { action: 'setResearch'; tech: TechId; level: number }
  /** Every tech at a level. */
  | { action: 'researchAll'; level: number }
  /** Exp for every hero in the city; they level up as far as it covers. */
  | { action: 'heroExp'; amount: number }
  /**
   * One hero's level (1-100), stats (0-9,999) and gear stars (0-15), set straight. Only the fields sent change; a new level starts at
   * 0 exp. The hero has to be in the target's cities (error `hero_not_found`).
   */
  | {
      action: 'setHero';
      heroId: string;
      level?: number;
      points?: number;
      politics?: number;
      attack?: number;
      intelligence?: number;
      stars?: number;
    }
  /** Back to a new city: Town Hall and walls Lv1, starting resources, no troops, heroes or tasks. */
  | { action: 'resetCity' }
  /** The player's marches take a second each way (on) or the normal time (off). */
  | { action: 'instantMarch'; on: boolean }
  /** Adds medals to the player (negative takes away, never below 0). */
  | { action: 'addMedals'; medals: MedalCounts }
  /** The player's rank and/or title (ids from RANKS / TITLES), set straight with nothing paid. */
  | { action: 'setTitle'; rank?: string; title?: string }
  /** A free historic city at x, y: set its loyalty (0-100) and/or empty its garrison and fortifications. */
  | { action: 'setHistoric'; x: number; y: number; loyalty?: number; empty?: boolean };

export type ClientMessage =
  | LoginMessage
  | HelloMessage
  | PingMessage
  | GetStateMessage
  | BuildMessage
  | CancelBuildMessage
  | SpeedUpMessage
  | SetTaxMessage
  | ComfortMessage
  | LevyMessage
  | RenameCityMessage
  | DemolishMessage
  | AbandonCityMessage
  | ResearchMessage
  | CancelResearchMessage
  | TrainMessage
  | CancelTrainMessage
  | BuildFortMessage
  | AssignPointsMessage
  | CancelFortMessage
  | HireMessage
  | RefreshInnMessage
  | DismissMessage
  | SetMayorMessage
  | SetDefenderMessage
  | PersuadeMessage
  | RewardHeroMessage
  | RenameHeroMessage
  | ResetPointsMessage
  | SetGateMessage
  | HealMessage
  | MarchMessage
  | RecallMessage
  | AbandonValleyMessage
  | SetGarrisonMessage
  | ImposePolicyMessage
  | GetReportsMessage
  | GetReportMessage
  | ReadAllReportsMessage
  | GetAllianceMessage
  | AllianceActionMessage
  | BuyItemMessage
  | UseItemMessage
  | GetQuestsMessage
  | ClaimQuestMessage
  | GetLeaderboardMessage
  | GetMarketMessage
  | MarketOrderMessage
  | CancelOrderMessage
  | GetChatMessage
  | SendChatMessage
  | GetMailMessage
  | SendMailMessage
  | ReadMailMessage
  | PromoteMessage
  | CheatMessage;

// ---------- server -> client ----------

/** Reply to login and hello. `token` is only sent after a login. */
export type WelcomeMessage = Envelope<
  'welcome',
  { version: number; playerId: string; serverTime: number; token?: string }
>;
export type PongMessage = Envelope<'pong', { at: number; serverTime: number }>;
export interface GameState {
  player: Player;
  cities: City[];
  /** Running tasks in all the player's cities. */
  tasks: TimedTask[];
  /** Every other player's city, for the world map. Missing from older servers. */
  lords?: LordCity[];
  serverTime: number;
  /**
   * Only on a push with no id: why the game changed. 'cheat' (someone cheated on this account), 'attacked' (an
   * attack on one of the player's cities arrived), 'march' (the player's march reached another player's city),
   * 'incoming' (another lord's march set out for one of the player's cities and its Beacon Tower saw it).
   */
  reason?: 'cheat' | 'attacked' | 'march' | 'incoming' | 'mail' | 'trade';
}
/** The reply to getState and commands; also pushed with no id when someone else changed this game (see reason). */
export type StateMessage = Envelope<'state', GameState>;
/** Pushed (no id) when one of the player's tasks finishes, with the whole new state. */
export type TaskDoneMessage = Envelope<'taskDone', GameState & { task: TimedTask }>;
export type ErrorMessage = Envelope<'error', { code: ErrorCode; message: string }>;
export type ReportsMessage = Envelope<'reports', { reports: ReportSummary[] }>;
/** result is null for a policy report (no battle). */
export type ReportMessage = Envelope<'report', { report: ReportSummary & { result: BattleResult | null } }>;

export type AllianceReply = Envelope<'alliance', AllianceInfo>;
/** A chat line: the reply to `chat`, and pushed (no id) to every game it reaches. */
export type ChatLineMessage = Envelope<'chat', ChatMessage>;
export type ChatHistoryMessage = Envelope<'chatHistory', { messages: ChatMessage[] }>;
export type MailboxMessage = Envelope<'mail', { inbox: Mail[]; sent: Mail[] }>;
export type MarketMessage = Envelope<'market', MarketView>;
export type QuestsMessage = Envelope<'quests', { quests: QuestStatus[] }>;
/** Rows ranked from 1: players (prestige), heroes (level) or alliances (members' prestige). */
export type LeaderboardMessage = Envelope<
  'leaderboard',
  {
    board: 'player' | 'hero' | 'alliance';
    rows: (Record<string, string | number | null> & { rank: number })[];
  }
>;

export type ServerMessage =
  | WelcomeMessage
  | PongMessage
  | StateMessage
  | TaskDoneMessage
  | ErrorMessage
  | ReportsMessage
  | ReportMessage
  | AllianceReply
  | ChatLineMessage
  | ChatHistoryMessage
  | MailboxMessage
  | MarketMessage
  | LeaderboardMessage
  | QuestsMessage;

export type ErrorCode =
  | 'bad_message'
  | 'version_mismatch'
  | 'not_logged_in'
  /** wrong username or password */
  | 'bad_login'
  /** the saved token is unknown or too old: log in again */
  | 'session_expired'
  | 'server_error'
  | 'not_enough_resources'
  | 'queue_busy'
  | 'requirement_not_met'
  | 'bad_slot'
  | 'max_level'
  /** speedUp with more than 5 minutes left */
  | 'too_early'
  /** speedUp on research, training or walls */
  | 'no_free_speedup'
  /** research in a city without an Academy */
  | 'no_academy'
  /** the Academy is being upgraded (no research), or is researching (no upgrade) */
  | 'academy_busy'
  /** this city's Academy is already researching something */
  | 'research_busy'
  /** the same tech is already being researched in another city */
  | 'already_researching'
  /** the Barracks already has as many batches queued as its level */
  | 'train_queue_full'
  /** not enough idle population for the batch */
  | 'not_enough_population'
  /** a cheat named a player who doesn't exist */
  | 'player_not_found'
  /** hire in a city without an Inn */
  | 'no_inn'
  /** hire in a city without a Feasting Hall */
  | 'no_hall'
  /** the Feasting Hall already holds as many heroes as its level */
  | 'hall_full'
  /** the offer was hired already, or the Inn's offers changed since */
  | 'offer_gone'
  /** the hero isn't idle (mayor or marching) */
  | 'hero_busy'
  /** march from a city without a Rally Spot */
  | 'no_rally_spot'
  /** more troops than 10,000 per Rally Spot level */
  | 'too_many_troops'
  /** the city already has as many marches out as its Rally Spot level */
  | 'too_many_marches'
  /** the city doesn't have the troops */
  | 'not_enough_troops'
  /** a march with no troops */
  | 'no_troops'
  /** a march with no hero, or one not in the city */
  | 'no_hero'
  /** a setHero cheat for a hero that isn't in the target's cities */
  | 'hero_not_found'
  /** nothing that can be attacked there (or no lord's city there for a policy) */
  | 'bad_target'
  /** a policy from a city that isn't a historic city you hold */
  | 'not_historic'
  /** a policy without the Earl title or above */
  | 'title_too_low'
  /** a policy on a city outside the historic city's draft area */
  | 'out_of_range'
  /** a historic city that has used all its policies today (they come back at 00:00 UTC) */
  | 'no_policies_left'
  /** recall on a march already coming home */
  | 'already_returning'
  /** a promotion without the medals it needs */
  | 'not_enough_medals'
  /** a title whose rank the player hasn't reached */
  | 'rank_too_low'
  /** comfort less than 15 minutes after the last one in that city */
  | 'comfort_cooldown'
  /** a levy less than 15 minutes after the last one in that city */
  | 'levy_cooldown'
  /** Population Raising in a city already at its population limit */
  | 'population_full'
  /** a city name that is empty, too long or has other characters */
  | 'bad_city_name'
  /** a hero name that is empty, too long or has other characters */
  | 'bad_hero_name'
  /** rewarding a hero less than 15 minutes after their last reward */
  | 'reward_cooldown'
  /** rewarding a hero whose loyalty is already 100 */
  | 'loyalty_full'
  /** resetting a hero who has no tracked spent points */
  | 'nothing_to_reset'
  /** resetting a hero's points less than a day after the last reset */
  | 'reset_cooldown'
  /** demolishing the Town Hall, or walls at Lv1 */
  | 'cant_demolish'
  /** demolishing a Barracks with troops in training */
  | 'barracks_busy'
  /** abandoning a historic city */
  | 'historic_city'
  /** abandoning a city with troops out or an attack on its way to it */
  | 'troops_out'
  /** a march to one of your own cities */
  | 'own_city'
  /** a scout march with no scouts */
  | 'no_scouts'
  /** a Found City march without 250 workers */
  | 'not_enough_workers'
  /** a transport carrying more than its troops' load */
  | 'too_much_cargo'
  /** attacking a valley one of your cities holds */
  | 'own_valley'
  /** the city already holds as many valleys as its Town Hall level */
  | 'valley_cap'
  /** founding a city when your title allows no more */
  | 'city_cap'
  /** reinforcing someone who isn't an ally, or whose Embassy doesn't take (more) garrisons */
  | 'not_allied'
  /** fortifications that don't fit in the space the walls have left */
  | 'no_wall_space'
  /** the walls' fortification queue already has as many batches as the walls level */
  | 'fort_queue_full'
  /** spending more stat points than the hero has */
  | 'not_enough_points'
  /** joining or founding an alliance while in one */
  | 'already_in_alliance'
  /** joining an alliance without an Embassy */
  | 'no_embassy'
  /** an alliance that doesn't exist, or an alliance action while in none */
  | 'no_alliance'
  /** an alliance name that isn't 3 to 20 letters, digits, spaces, - or _ */
  | 'bad_name'
  | 'name_taken'
  /** the alliance has as many members as the host's Embassy allows (10 per level) */
  | 'alliance_full'
  | 'not_a_member'
  /** attacking or scouting your own alliance, or one yours calls friendly */
  | 'friendly'
  /** more than one chat line a second */
  | 'too_fast'
  /** a city with as many open orders as its Marketplace level */
  | 'market_full'
  /** using an item the player doesn't have */
  | 'no_item'
  /** a speed-up on a training or fortification batch still waiting its turn */
  | 'not_started'
  /** a quest reward claimed before */
  | 'already_claimed';
