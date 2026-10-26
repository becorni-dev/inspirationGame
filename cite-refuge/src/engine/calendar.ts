// Le temps qui passe : heures, jours, saisons, années. Aucune dépendance à l'affichage.
import calendar from "../data/calendar.json";

export type SeasonId = "printemps" | "ete" | "automne" | "hiver";

export interface Season {
  id: SeasonId;
  name: string;
  sunrise: number;
  sunset: number;
}

export interface Clock {
  hours: number; // heures écoulées depuis le début de la partie
}

export const SEASONS = calendar.seasons as Season[];
export const DAYS_PER_SEASON = calendar.daysPerSeason;
export const SECONDS_PER_HOUR = calendar.secondsPerHour;
export const HOURS_PER_YEAR = 24 * DAYS_PER_SEASON * SEASONS.length;

export function advance(clock: Clock, hours: number): Clock {
  return { hours: clock.hours + Math.max(0, hours) };
}

export interface CalendarView {
  year: number; // à partir de 1
  seasonIndex: number;
  season: Season;
  dayOfSeason: number; // à partir de 1
  hour: number; // 0 à 24
  seasonProgress: number; // 0 au début de la saison, 1 à la fin
  yearProgress: number;
}

export function view(clock: Clock): CalendarView {
  const h = Math.max(0, clock.hours);
  const year = Math.floor(h / HOURS_PER_YEAR);
  const inYear = h - year * HOURS_PER_YEAR;
  const seasonHours = 24 * DAYS_PER_SEASON;
  const seasonIndex = Math.min(SEASONS.length - 1, Math.floor(inYear / seasonHours));
  const inSeason = inYear - seasonIndex * seasonHours;
  return {
    year: year + 1,
    seasonIndex,
    season: SEASONS[seasonIndex],
    dayOfSeason: Math.floor(inSeason / 24) + 1,
    hour: inSeason % 24,
    seasonProgress: inSeason / seasonHours,
    yearProgress: inYear / HOURS_PER_YEAR,
  };
}

// Hauteur du soleil de 0 (nuit) à 1 (midi), selon le lever et le coucher de la saison.
export function daylight(v: CalendarView): number {
  const { sunrise, sunset } = v.season;
  if (v.hour <= sunrise - 1 || v.hour >= sunset + 1) return 0;
  const t = (v.hour - (sunrise - 1)) / (sunset + 1 - (sunrise - 1));
  return Math.max(0, Math.sin(t * Math.PI));
}

// Épaisseur de neige visée (0 à 1) : elle tombe en hiver, fond au printemps.
export function snowCover(v: CalendarView): number {
  switch (v.season.id) {
    case "hiver":
      return Math.min(1, 0.15 + v.seasonProgress * 1.6);
    case "printemps":
      return Math.max(0, 1 - v.seasonProgress * 3);
    case "automne":
      return Math.max(0, (v.seasonProgress - 0.85) * 2);
    default:
      return 0;
  }
}

// Avancée de l'Ombre sur la plaine (0 : au loin, 1 : contre les remparts).
export function shadowReach(v: CalendarView): number {
  const base = [0.25, 0.1, 0.45, 0.85][v.seasonIndex];
  const next = [0.1, 0.45, 0.85, 0.25][v.seasonIndex];
  const t = v.seasonProgress;
  return base + (next - base) * t * t;
}

export function formatClock(v: CalendarView): string {
  const hh = Math.floor(v.hour);
  const mm = Math.floor((v.hour - hh) * 60);
  return `An ${v.year} · ${v.season.name}, jour ${v.dayOfSeason} · ${String(hh).padStart(2, "0")}:${String(mm).padStart(2, "0")}`;
}
