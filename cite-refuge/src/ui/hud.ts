// L'interface : écran titre, barre du haut (saison, ressources), outils, fiche, chronique et décisions.
import type { CalendarView } from "../engine/calendar";
import { BUILDINGS, BUILDING_ORDER, type Slot, ZONES } from "../engine/city";
import {
  type ColumnChoice,
  type Forecast,
  type GameState,
  type Line,
  PEOPLES,
  PEOPLE_NAMES,
  answerColumn,
  dayInfo,
  forecast,
  housing,
  population,
  staffing,
  winterNeeds,
} from "../engine/game";

interface Callbacks {
  onPlay: (resume: boolean) => void;
  onSpeed: (i: number) => void;
  onTool: (t: string) => void;
  onSkipSeason: () => void;
  onColumn: (choice: ColumnChoice) => void;
  onReportDone: () => void;
  onRestart: () => void;
}

const SEASON_MOOD: Record<string, string> = {
  printemps: "Les réfugiés arrivent par la route du sud.",
  ete: "Le temps de bâtir et de cultiver.",
  automne: "Rentrer les récoltes, faire du bois.",
  hiver: "L'Ombre est aux portes. Tenir.",
};

// Nombres au format français
export function fmt(n: number, digits = 0): string {
  return n.toLocaleString("fr-FR", { maximumFractionDigits: digits, minimumFractionDigits: digits });
}
function signed(n: number): string {
  const r = Math.round(n * 10) / 10;
  return `${r > 0 ? "+" : r < 0 ? "−" : ""}${fmt(Math.abs(r), 1)}`;
}
const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
const plural = (n: number, one: string, many: string) => `${fmt(n)} ${n > 1 ? many : one}`;

function lines(title: string, list: Line[], sign: string): string {
  if (!list.length) return "";
  return `<div class="tip-h">${title}</div>${list.map((l) => `<div class="tip-l"><span>${l.label}</span><b>${sign}${fmt(l.value, 1)}</b></div>`).join("")}`;
}

export class Hud {
  root: HTMLElement;
  cb: Callbacks;
  title: HTMLElement;
  top: HTMLElement;
  res: HTMLElement;
  tools: HTMLElement;
  hint: HTMLElement;
  info: HTMLElement;
  chron: HTMLElement;
  modal: HTMLElement;
  tip: HTMLElement;
  toastEl: HTMLElement;
  clockEl!: HTMLElement;
  barEl!: HTMLElement;
  moodEl!: HTMLElement;
  resumeBtn: HTMLButtonElement;
  speedBtns: HTMLButtonElement[] = [];
  toolBtns = new Map<string, HTMLButtonElement>();
  modalKey = "";
  private toastTimer = 0;
  private lastState: GameState | null = null;
  private infoSlot: Slot | null = null;

  constructor(root: HTMLElement, cb: Callbacks) {
    this.root = root;
    this.cb = cb;
    this.title = this.el("div", "panel title-card", `
      <div class="sub">PROTOTYPE · ANNÉE DE L'OMBRE</div>
      <h1>La Cité-Refuge</h1>
      <p>Hautbourg est la dernière cité libre au pied des Monts Gris. Chaque hiver, l'Ombre avance et des peuples entiers frappent à tes portes.</p>
      <p><i>Accueille-les. Loge-les. Tiens jusqu'au printemps.</i></p>`);
    const play = this.button(this.title, "Nouvelle partie", () => cb.onPlay(false));
    play.classList.add("big");
    this.resumeBtn = this.button(this.title, "Reprendre", () => cb.onPlay(true));
    this.resumeBtn.classList.add("big", "hidden-btn");

    this.top = this.el("div", "panel top hidden", `
      <span class="brand">HAUTBOURG</span>
      <span class="season"><span class="clock"></span><span class="season-bar"><i></i></span></span>
      <span class="stat mood"></span>
      <span class="spacer"></span>`);
    this.clockEl = this.top.querySelector(".clock")!;
    this.barEl = this.top.querySelector(".season-bar i")!;
    this.moodEl = this.top.querySelector(".mood")!;
    ["II", "▶", "▶▶", "▶▶▶"].forEach((label, i) => {
      const b = this.button(this.top, label, () => cb.onSpeed(i));
      b.title = ["Pause (Espace)", "Normal", "Rapide", "Très rapide"][i];
      this.speedBtns.push(b);
    });
    this.button(this.top, "Saison suivante", () => cb.onSkipSeason());

    this.res = this.el("div", "panel res hidden", "");
    this.tools = this.el("div", "panel tools hidden", "");
    for (const t of BUILDING_ORDER) {
      const def = BUILDINGS[t];
      const where = def.zones.map((z) => ZONES[z].name.replace(/^(La |Les )/, "")).join(", ");
      const b = this.button(this.tools, "", () => cb.onTool(t));
      b.classList.add("tool");
      b.innerHTML = `<span class="k">${def.key}</span><span class="n">${def.name}</span><span class="z"><b>${def.cost} bois</b></span>`;
      b.dataset.tip = `<div class="tip-h">${def.name} · ${def.cost} bois</div><p>${def.desc}</p><p>Où : ${where.toLowerCase()}.</p>`;
      this.toolBtns.set(t, b);
    }
    this.hint = this.el("div", "panel hint hidden", "");
    this.info = this.el("div", "panel info hidden", "");
    this.chron = this.el("div", "panel chron hidden", "");
    this.modal = this.el("div", "modal-wrap hidden", "");
    this.tip = this.el("div", "panel tip hidden", "");
    this.toastEl = this.el("div", "panel toast hidden", "");
    this.setTool(null);

    // Bulles d'aide : tout élément qui a data-tip
    window.addEventListener("mouseover", (e) => {
      const t = (e.target as HTMLElement).closest<HTMLElement>("[data-tip]");
      if (!t) return this.tip.classList.add("hidden");
      this.tip.innerHTML = t.dataset.tip ?? "";
      const r = t.getBoundingClientRect();
      const below = r.top < window.innerHeight / 2;
      this.tip.style.left = `${Math.min(window.innerWidth - 330, Math.max(8, r.left))}px`;
      this.tip.style.top = below ? `${r.bottom + 8}px` : "";
      this.tip.style.bottom = below ? "" : `${window.innerHeight - r.top + 8}px`;
      this.tip.classList.remove("hidden");
    });
  }

  el(tag: string, cls: string, html: string): HTMLElement {
    const e = document.createElement(tag);
    e.className = cls;
    e.innerHTML = html;
    this.root.appendChild(e);
    return e;
  }

  button(parent: HTMLElement, label: string, onClick: () => void): HTMLButtonElement {
    const b = document.createElement("button");
    b.className = "btn";
    b.textContent = label;
    b.onclick = onClick;
    parent.appendChild(b);
    return b;
  }

  offerResume(label: string | null): void {
    this.resumeBtn.classList.toggle("hidden-btn", !label);
    if (label) this.resumeBtn.textContent = `Reprendre · ${label}`;
  }

  showGame(): void {
    this.title.classList.add("hidden");
    for (const e of [this.top, this.res, this.tools, this.hint, this.chron]) e.classList.remove("hidden");
  }

  toolByKey(key: string): string | null {
    return BUILDING_ORDER.find((t) => BUILDINGS[t].key === key) ?? null;
  }

  setTool(t: string | null): void {
    for (const [k, b] of this.toolBtns) b.classList.toggle("on", k === t);
    this.hint.textContent = t
      ? `${BUILDINGS[t].name} (${BUILDINGS[t].cost} bois) : choisis un emplacement doré. Clic droit ou Échap pour annuler.`
      : "Glisser pour se déplacer · molette pour zoomer · touches 1 à 8 pour bâtir · clic sur un bâtiment pour sa fiche";
  }

  // --- Fiche d'un emplacement ou d'un bâtiment ---
  showInfo(slot: Slot | null, state: GameState): void {
    this.infoSlot = slot;
    if (!slot) {
      this.info.classList.add("hidden");
      return;
    }
    this.renderInfo(state);
    this.info.classList.remove("hidden");
  }

  private renderInfo(state: GameState): void {
    const slot = this.infoSlot;
    if (!slot) return;
    const b = state.city.buildings[slot.id];
    const zone = ZONES[slot.zone];
    if (!b) {
      this.info.innerHTML = `<h3>${zone.name}</h3><p class="muted">${zone.desc}</p><p>Emplacement libre.</p>`;
      return;
    }
    const def = BUILDINGS[b.type];
    const si = dayInfo(state.day).seasonIndex;
    const rows: string[] = [];
    const staff = staffing(state);
    const s = staff.slots[slot.id];
    if (def.jobs && s) {
      const n = s.humain + s.nain;
      const who = PEOPLES.filter((p) => s[p]).map((p) => plural(s[p], PEOPLE_NAMES[p].one.toLowerCase(), PEOPLE_NAMES[p].name.toLowerCase())).join(", ");
      rows.push(`<div class="row"><span>Travailleurs</span><b class="${n < def.jobs ? "warn" : ""}">${n} / ${def.jobs}</b></div>`);
      if (who) rows.push(`<p class="muted">${who}</p>`);
      const boost = 1 + staff.tools;
      if (def.food) rows.push(`<div class="row"><span>Vivres par jour (cette saison)</span><b>${signed(n * def.food[si] * boost)}</b></div>`);
      if (def.wood) rows.push(`<div class="row"><span>Bois par jour (cette saison)</span><b>${signed(n * def.wood[si] * boost)}</b></div>`);
      if (def.tools) rows.push(`<div class="row"><span>Outils pour toute la cité</span><b>+${fmt((def.tools * n * 100) / def.jobs)} %</b></div>`);
    }
    if (def.beds) {
      const h = housing(state);
      const inGallery = slot.zone === "galeries";
      const used = inGallery ? h.gallery.humain + h.gallery.nain : h.surface.humain + h.surface.nain;
      const beds = inGallery ? h.galleryBeds : h.surfaceBeds;
      rows.push(`<div class="row"><span>Lits ${inGallery ? "des galeries" : "en surface"}</span><b>${used} / ${beds}</b></div>`);
    }
    if (def.storage) rows.push(`<div class="row"><span>Place pour les vivres</span><b>+${def.storage}</b></div>`);
    this.info.innerHTML = `<h3>${def.name}</h3><p>${def.desc}</p>${rows.join("")}<p class="muted">${zone.name} · Suppr pour démolir (rend ${Math.floor(def.cost / 2)} bois)</p>`;
  }

  toast(text: string, bad = false): void {
    this.toastEl.textContent = text;
    this.toastEl.style.color = bad ? "var(--bad)" : "var(--fg)";
    this.toastEl.classList.remove("hidden");
    clearTimeout(this.toastTimer);
    this.toastTimer = window.setTimeout(() => this.toastEl.classList.add("hidden"), 2600);
  }

  update(v: CalendarView, state: GameState, speed: number, frozen: boolean): void {
    const hh = Math.floor(v.hour);
    const mm = Math.floor((v.hour - hh) * 60);
    this.clockEl.innerHTML = `<b>${v.season.name}</b> · an ${v.year}, jour ${v.dayOfSeason} · ${String(hh).padStart(2, "0")}:${String(mm).padStart(2, "0")}`;
    this.barEl.style.width = `${Math.round(v.seasonProgress * 100)}%`;
    this.moodEl.textContent = SEASON_MOOD[v.season.id] ?? "";
    this.speedBtns.forEach((b, i) => b.classList.toggle("on", !frozen && i === speed));
    if (state !== this.lastState) {
      this.lastState = state;
      this.renderResources(state);
      this.renderChronicle(state);
      this.renderModal(state);
      this.renderInfo(state);
      const winter = dayInfo(state.day).seasonIndex === 3;
      for (const [t, b] of this.toolBtns) b.classList.toggle("off", winter || state.wood < BUILDINGS[t].cost);
    }
  }

  // --- Ressources, avec le détail au survol ---
  private renderResources(s: GameState): void {
    const f: Forecast = forecast(s);
    const h = housing(s);
    const staff = staffing(s);
    const need = winterNeeds(s);
    const pop = population(s);
    const homeless = h.homeless.humain + h.homeless.nain;
    const wounded = s.pop.humain.wounded + s.pop.nain.wounded;
    const tone = (n: number) => (n < -0.05 ? "bad" : n > 0.05 ? "good" : "");
    const foodTip = `${lines("Production par jour", f.foodIn, "+")}${lines("Consommation par jour", f.foodOut, "−")}<p>Les greniers gardent ${fmt(f.storage)} vivres, le reste pourrit.</p>`;
    const woodTip = `${lines("Production par jour", f.woodIn, "+")}${lines("Consommation par jour", f.woodOut, "−") || "<p>Pas de chauffage en cette saison.</p>"}`;
    const popTip = `<div class="tip-h">Peuples</div>${PEOPLES.map((p) => `<div class="tip-l"><span>${PEOPLE_NAMES[p].name}</span><b>${s.pop[p].able} valides${s.pop[p].wounded ? `, ${s.pop[p].wounded} blessés` : ""}</b></div>`).join("")}<p>Les blessés mangent mais ne travaillent pas. À la saison suivante, ils guérissent ou meurent.</p>`;
    const bedTip = `<div class="tip-h">Lits</div><div class="tip-l"><span>En surface</span><b>${h.surface.humain + h.surface.nain} / ${h.surfaceBeds}</b></div><div class="tip-l"><span>Dans les galeries</span><b>${h.gallery.humain + h.gallery.nain} / ${h.galleryBeds}</b></div><p>Les Nains vont d'abord dans les galeries, les Humains en surface. L'hiver, dormir dehors tue : 6 % de risque par jour.</p>`;
    const jobTip = `<div class="tip-h">Travail</div><div class="tip-l"><span>Au travail</span><b>${staff.workers}</b></div><div class="tip-l"><span>Sans poste</span><b>${staff.idle}</b></div><div class="tip-l"><span>Outils des forges</span><b>+${fmt(staff.tools * 100)} %</b></div><p>Chaque bâtiment reçoit un travailleur à tour de rôle : forges, fermes, serres, bûcherons.</p>`;
    const short = { food: need.food - s.food, wood: need.wood - s.wood };
    const winterTip = `<div class="tip-h">Pour passer l'hiver (6 jours)</div><div class="tip-l"><span>Vivres</span><b>${fmt(need.food)} (tu en as ${fmt(s.food)})</b></div><div class="tip-l"><span>Bois</span><b>${fmt(need.wood)} (tu en as ${fmt(s.wood)})</b></div><p>Calculé avec la cité d'aujourd'hui : chaque maison, chaque bouche et chaque phare compte. L'hiver, les fermes et les bûcherons ne donnent rien.</p>`;
    const winterTxt =
      short.food <= 0 && short.wood <= 0
        ? `<b class="good">réserves suffisantes</b>`
        : `il manque ${[short.food > 0 ? `<b class="bad">${fmt(short.food)} vivres</b>` : "", short.wood > 0 ? `<b class="bad">${fmt(short.wood)} bois</b>` : ""].filter(Boolean).join(" et ")}`;
    this.res.innerHTML = `
      <span class="chip" data-tip="${esc(foodTip)}"><i class="dot food"></i>Vivres <b>${fmt(s.food)}</b><small>/ ${fmt(f.storage)}</small> <em class="${tone(f.food)}">${signed(f.food)}/j</em></span>
      <span class="chip" data-tip="${esc(woodTip)}"><i class="dot wood"></i>Bois <b>${fmt(s.wood)}</b> <em class="${tone(f.wood)}">${signed(f.wood)}/j</em></span>
      <span class="chip" data-tip="${esc(popTip)}">Habitants <b>${pop}</b><small>${s.pop.humain.able + s.pop.humain.wounded} humains · ${s.pop.nain.able + s.pop.nain.wounded} nains${wounded ? ` · ${wounded} blessés` : ""}</small></span>
      <span class="chip" data-tip="${esc(bedTip)}">Lits <b>${h.surfaceBeds + h.galleryBeds}</b>${homeless ? `<em class="bad">${homeless} dehors</em>` : `<em class="good">tous logés</em>`}</span>
      <span class="chip" data-tip="${esc(jobTip)}">Travail <b>${staff.workers}</b><small>/ ${s.pop.humain.able + s.pop.nain.able}</small></span>
      <span class="chip" data-tip="${esc(winterTip)}">Hiver : ${winterTxt}</span>`;
  }

  private renderChronicle(s: GameState): void {
    const last = s.chronicle.slice(-5).reverse();
    this.chron.innerHTML = `<div class="chron-h">Chronique de Hautbourg</div>${last.map((e) => `<p class="${e.tone}">${e.text}</p>`).join("")}`;
  }

  // --- Décisions : colonne aux portes, bilan de l'hiver, chute ---
  private renderModal(s: GameState): void {
    const key = s.fallen ? "fallen" : s.report ? `report-${s.report.year}` : s.column ? `column-${s.column.year}` : "";
    if (key === this.modalKey) return;
    this.modalKey = key;
    this.modal.classList.toggle("hidden", !key);
    if (!key) {
      this.modal.innerHTML = "";
      return;
    }
    const box = document.createElement("div");
    box.className = "panel modal";
    this.modal.innerHTML = "";
    this.modal.appendChild(box);

    if (s.fallen) {
      box.innerHTML = `<div class="sub">FIN</div><h2>Hautbourg est tombée</h2><p>Il ne reste personne pour allumer les phares. La brume entre par la porte ouverte.</p>`;
      this.button(box, "Recommencer", () => this.cb.onRestart()).classList.add("big");
      return;
    }
    if (s.report) {
      const r = s.report;
      const lost = r.cold + r.hunger + r.wounds;
      const row = (label: string, n: number) => (n ? `<div class="row"><span>${label}</span><b class="bad">${n}</b></div>` : "");
      box.innerHTML = `<div class="sub">AN ${r.year} · FIN DE L'HIVER</div><h2>${r.year === 1 ? "Le premier hiver" : `L'hiver de l'an ${r.year}`}</h2>
        <p>${lost ? `L'hiver a pris ${plural(lost, "vie", "vies")}. On les enterre sous les pins, au pied de la falaise.` : "Personne n'est mort cet hiver. Dans les tavernes, on n'ose pas encore le dire tout haut."}</p>
        ${row("Morts de froid", r.cold)}${row("Morts de faim", r.hunger)}${row("Blessés emportés", r.wounds)}
        <div class="row"><span>Survivants</span><b>${r.survivors}</b></div>
        <div class="row"><span>Il reste</span><b>${fmt(r.food)} vivres · ${fmt(r.wood)} bois</b></div>`;
      this.button(box, "Le printemps revient", () => this.cb.onReportDone()).classList.add("big");
      return;
    }
    const c = s.column!;
    const size = c.able + c.wounded;
    const who = PEOPLE_NAMES[c.people].name.toLowerCase();
    box.innerHTML = `<div class="sub">AN ${c.year} · PRINTEMPS · AUX PORTES</div><h2>${cap(c.origin)}</h2><p class="story">${c.story}</p>
      <p>${size} ${who} attendent devant la porte : <b>${c.able} valides</b> et <b class="warn">${c.wounded} blessés</b>.</p><div class="choices"></div>`;
    const choices = box.querySelector(".choices")!;
    const option = (choice: ColumnChoice, label: string) => {
      const after = answerColumn(s, choice);
      const added = population(after) - population(s);
      const need = winterNeeds(after);
      const h = housing(after);
      const homeless = h.homeless.humain + h.homeless.nain;
      const b = this.button(choices as HTMLElement, "", () => this.cb.onColumn(choice));
      b.classList.add("choice");
      const consequences = added
        ? `+${added} bouches · hiver : ${fmt(need.food)} vivres à prévoir · ${homeless ? `${homeless} sans lit` : "tous logés"}`
        : choice === "personne"
          ? `Personne n'entre. ${size} ${who} repartent dans la brume.`
          : "";
      b.innerHTML = `<span class="n">${label}</span><span class="z">${consequences}${choice === "valides" ? ` · ${c.wounded} blessés laissés dehors` : ""}</span>`;
    };
    option("tous", "Ouvrir les portes à tous");
    option("valides", "Seulement ceux qui peuvent travailler");
    option("personne", "Garder les portes fermées");
  }
}
