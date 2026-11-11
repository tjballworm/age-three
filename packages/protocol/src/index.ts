// Client <-> server messages. Every message has a `type` discriminator.

import type {
  BattleResult,
  BuildingType,
  City,
  Ladder,
  LordCity,
  MarchMission,
  MedalCounts,
  Player,
  PolicyId,
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
/** Persuades a captive hero (from a captured city) to join for their hiring fee in gold. Release one with dismiss. */
export type PersuadeMessage = Envelope<'persuade', { cityId: string; heroId: string }>;
/** Opens or closes the Rally Spot's gate. Closed, the troops stay out of battles. Replies with state. */
export type SetGateMessage = Envelope<'setGate', { cityId: string; open: boolean }>;
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
/** One report with the whole battle; marks it read. Replies with `report`. */
export type GetReportMessage = Envelope<'getReport', { reportId: string }>;
/**
 * One step up the rank or title ladder (nextPromotion in core shows what it needs). The gold comes from the city
 * (whose Town Hall counts for ranks), the medals from the player. Replies with state.
 */
export type PromoteMessage = Envelope<'promote', { cityId: string; ladder: Ladder }>;
/**
 * Comforts a city's people (COMFORTS in core): Disaster Relief pays food, Praying gold, each the population limit,
 * once every 15 minutes per city. Raises loyalty and lowers grievance. Replies with state.
 */
export type ComfortMessage = Envelope<'comfort', { cityId: string; kind: 'relief' | 'pray' }>;
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
  | ResearchMessage
  | CancelResearchMessage
  | TrainMessage
  | CancelTrainMessage
  | HireMessage
  | RefreshInnMessage
  | DismissMessage
  | SetMayorMessage
  | SetDefenderMessage
  | PersuadeMessage
  | SetGateMessage
  | MarchMessage
  | RecallMessage
  | AbandonValleyMessage
  | SetGarrisonMessage
  | ImposePolicyMessage
  | GetReportsMessage
  | GetReportMessage
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
   * attack on one of the player's cities arrived), 'march' (the player's march reached another player's city).
   */
  reason?: 'cheat' | 'attacked' | 'march';
}
/** The reply to getState and commands; also pushed with no id when someone else changed this game (see reason). */
export type StateMessage = Envelope<'state', GameState>;
/** Pushed (no id) when one of the player's tasks finishes, with the whole new state. */
export type TaskDoneMessage = Envelope<'taskDone', GameState & { task: TimedTask }>;
export type ErrorMessage = Envelope<'error', { code: ErrorCode; message: string }>;
export type ReportsMessage = Envelope<'reports', { reports: ReportSummary[] }>;
/** result is null for a policy report (no battle). */
export type ReportMessage = Envelope<'report', { report: ReportSummary & { result: BattleResult | null } }>;

export type ServerMessage =
  | WelcomeMessage
  | PongMessage
  | StateMessage
  | TaskDoneMessage
  | ErrorMessage
  | ReportsMessage
  | ReportMessage;

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
  | 'not_allied';
