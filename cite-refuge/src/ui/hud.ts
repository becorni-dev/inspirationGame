// L'interface : écran titre, barre du haut (saison, heure, vitesse), outils de construction, fiche.
import type { CalendarView } from "../engine/calendar";
import { BUILDINGS, BUILDING_ORDER, type CityState, type Slot, ZONES, population } from "../engine/city";

interface Callbacks {
  onPlay: () => void;
  onSpeed: (i: number) => void;
  onTool: (t: string) => void;
  onSkipSeason: () => void;
}

const SEASON_MOOD: Record<string, string> = {
  printemps: "Les réfugiés arrivent par la route du sud.",
  ete: "Le temps de bâtir et de cultiver.",
  automne: "Rentrer les récoltes, réparer les remparts.",
  hiver: "L'Ombre est aux portes. Tenir.",
};

export class Hud {
  root: HTMLElement;
  cb: Callbacks;
  title: HTMLElement;
  top: HTMLElement;
  tools: HTMLElement;
  hint: HTMLElement;
  info: HTMLElement;
  toastEl: HTMLElement;
  clockEl!: HTMLElement;
  barEl!: HTMLElement;
  popEl!: HTMLElement;
  moodEl!: HTMLElement;
  speedBtns: HTMLButtonElement[] = [];
  toolBtns = new Map<string, HTMLButtonElement>();
  private toastTimer = 0;

  constructor(root: HTMLElement, cb: Callbacks) {
    this.root = root;
    this.cb = cb;
    this.title = this.el("div", "panel title-card", `
      <div class="sub">PROTOTYPE · ANNÉE DE L'OMBRE</div>
      <h1>La Cité-Refuge</h1>
      <p>Hautbourg est la dernière cité libre au pied des Monts Gris. Chaque hiver, l'Ombre avance et des peuples entiers frappent à tes portes.</p>
      <p><i>Accueille-les. Loge-les. Tiens jusqu'au printemps.</i></p>`);
    const play = document.createElement("button");
    play.className = "btn";
    play.textContent = "Entrer dans Hautbourg";
    play.onclick = () => cb.onPlay();
    this.title.appendChild(play);

    this.top = this.el("div", "panel top hidden", `
      <span class="brand">HAUTBOURG</span>
      <span class="season"><span class="clock"></span><span class="season-bar"><i></i></span></span>
      <span class="stat mood"></span>
      <span class="spacer"></span>
      <span class="stat">Habitants <b class="pop">0</b></span>`);
    this.clockEl = this.top.querySelector(".clock")!;
    this.barEl = this.top.querySelector(".season-bar i")!;
    this.popEl = this.top.querySelector(".pop")!;
    this.moodEl = this.top.querySelector(".mood")!;
    ["II", "▶", "▶▶", "▶▶▶"].forEach((label, i) => {
      const b = document.createElement("button");
      b.className = "btn";
      b.textContent = label;
      b.title = ["Pause (Espace)", "Normal", "Rapide", "Très rapide"][i];
      b.onclick = () => cb.onSpeed(i);
      this.top.appendChild(b);
      this.speedBtns.push(b);
    });
    const skip = document.createElement("button");
    skip.className = "btn";
    skip.textContent = "Saison suivante";
    skip.onclick = () => cb.onSkipSeason();
    this.top.appendChild(skip);

    this.tools = this.el("div", "panel tools hidden", "");
    for (const t of BUILDING_ORDER) {
      const def = BUILDINGS[t];
      const b = document.createElement("button");
      b.className = "btn tool";
      const where = def.zones.map((z) => ZONES[z].name.replace(/^(La |Les )/, "")).join(", ");
      b.innerHTML = `<span class="k">${def.key}</span><span class="n">${def.name}</span><span class="z">${where}</span>`;
      b.title = def.desc;
      b.onclick = () => cb.onTool(t);
      this.tools.appendChild(b);
      this.toolBtns.set(t, b);
    }
    this.hint = this.el("div", "panel hint hidden", "Glisser pour se déplacer · molette pour zoomer · touches 1 à 6 pour bâtir");
    this.info = this.el("div", "panel info hidden", "");
    this.toastEl = this.el("div", "panel toast hidden", "");
  }

  el(tag: string, cls: string, html: string): HTMLElement {
    const e = document.createElement(tag);
    e.className = cls;
    e.innerHTML = html;
    this.root.appendChild(e);
    return e;
  }

  showGame(): void {
    this.title.classList.add("hidden");
    for (const e of [this.top, this.tools, this.hint]) e.classList.remove("hidden");
  }

  toolByKey(key: string): string | null {
    return BUILDING_ORDER.find((t) => BUILDINGS[t].key === key) ?? null;
  }

  setTool(t: string | null): void {
    for (const [k, b] of this.toolBtns) b.classList.toggle("on", k === t);
    this.hint.textContent = t
      ? `${BUILDINGS[t].name} : choisis un emplacement doré. Clic droit ou Échap pour annuler.`
      : "Glisser pour se déplacer · molette pour zoomer · touches 1 à 6 pour bâtir";
  }

  showInfo(slot: Slot | null, city: CityState): void {
    if (!slot) {
      this.info.classList.add("hidden");
      return;
    }
    const b = city.buildings[slot.id];
    const zone = ZONES[slot.zone];
    this.info.innerHTML = b
      ? `<h3>${BUILDINGS[b.type].name}</h3><p>${BUILDINGS[b.type].desc}</p><p class="muted">${zone.name} · ${zone.desc}</p>${BUILDINGS[b.type].people ? `<p>${BUILDINGS[b.type].people} habitants</p>` : ""}<p class="muted">Suppr pour démolir</p>`
      : `<h3>${zone.name}</h3><p class="muted">${zone.desc}</p><p>Emplacement libre.</p>`;
    this.info.classList.remove("hidden");
  }

  toast(text: string, bad = false): void {
    this.toastEl.textContent = text;
    this.toastEl.style.color = bad ? "var(--bad)" : "var(--fg)";
    this.toastEl.classList.remove("hidden");
    clearTimeout(this.toastTimer);
    this.toastTimer = window.setTimeout(() => this.toastEl.classList.add("hidden"), 2400);
  }

  update(v: CalendarView, city: CityState, speed: number): void {
    const hh = Math.floor(v.hour);
    const mm = Math.floor((v.hour - hh) * 60);
    this.clockEl.innerHTML = `<b>${v.season.name}</b> · an ${v.year}, jour ${v.dayOfSeason} · ${String(hh).padStart(2, "0")}:${String(mm).padStart(2, "0")}`;
    this.barEl.style.width = `${Math.round(v.seasonProgress * 100)}%`;
    this.moodEl.textContent = SEASON_MOOD[v.season.id] ?? "";
    this.popEl.textContent = population(city).toLocaleString("fr-FR");
    this.speedBtns.forEach((b, i) => b.classList.toggle("on", i === speed));
  }
}
