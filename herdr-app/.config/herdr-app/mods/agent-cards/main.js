// Agent cards: one minimal card per agent, four semantic states, native motion only.
//   blocked -> ATTENTION  red    slow-pulsing border + bouncing "!"
//   working -> WORKING    amber  breathing glow, "+N" sub-agent count
//   idle    -> WAITING    grey   dimmed, drifting "z z"
//   done    -> DONE       green  one-time check pop, then static
// Colors always come from theme().blocked/working/idle/done so every theme (including
// the wallpaper one) keeps the same meaning.
// Motion: shared("motion.reduced") === true switches every loop/spring off (there is no OS
// reduced-motion signal in herdr-app, so this is the mod's own switch; the header toggles it).
// Preview: setShared("agent-cards.demo", true) shows one fake card per state.
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { agents, terminals, theme, shared, setShared, run } from "herdr";

const LABEL = { blocked: "ATTENTION", working: "WORKING", idle: "WAITING", done: "DONE" };
const NOTE = { blocked: "waiting for your answer", working: "working", idle: "idle", done: "finished" };
const DEMO = [
  { address: "demo1", status: "blocked", program: { name: "Claude" }, title: "fix login bug", subs: 0 },
  { address: "demo2", status: "working", program: { name: "Codex" }, title: "refactor api", subs: 3 },
  { address: "demo3", status: "idle", program: { name: "Gemini" }, title: "docs pass", subs: 0 },
  { address: "demo4", status: "done", program: { name: "Kiro" }, title: "tests green", subs: 0 },
];
const alpha = (hex, a) => hex + Math.round(a * 255).toString(16).padStart(2, "0");

export default class AgentCards extends View {
  init(_props, cx) {
    this.popped = new Set();   // done cards whose check has already popped
    this.counts = new Map();   // address -> last +N, to flash a change
    this.flash = new Set();
  }

  list() {
    if (shared("agent-cards.demo")) return DEMO;
    const subs = new Map();
    for (const t of terminals()) if (t.parent) subs.set(t.parent, (subs.get(t.parent) ?? 0) + 1);
    return agents().map((a) => ({ ...a, status: a.status === "error" ? "blocked" : a.status, subs: subs.get(a.address) ?? 0 }));
  }

  render(cx) {
    const t = theme();
    const calm = shared("motion.reduced") === true;
    const items = this.list();
    return v_flex().id("agent-cards").size_full().bg(t.chrome).p(14).gap(12).text_size(12)
      .child(h_flex().items_center().gap(8)
        .child(div().flex_1().text_color(t.muted).font_semibold().child("Agents"))
        .child(div().id("demo-toggle").px(8).h(22).flex().items_center().rounded(5).border(1).border_color(t.border)
          .text_color(shared("agent-cards.demo") ? t.accent : t.muted).hover((s) => s.bg(t.hover))
          .on_click(() => setShared("agent-cards.demo", !shared("agent-cards.demo")))
          .child("Demo"))
        .child(div().id("motion-toggle").px(8).h(22).flex().items_center().rounded(5).border(1).border_color(t.border)
          .text_color(t.muted).hover((s) => s.bg(t.hover))
          .on_click(() => setShared("motion.reduced", !calm))
          .child(calm ? "Motion: reduced" : "Motion: on")))
      .child(h_flex().flex_wrap().gap(12).children(items.map((a) => this.card(a, t, calm, cx))))
      .when(items.length === 0, (el) => el.child(div().text_color(t.dim).child("No agent status yet.")));
  }

  card(a, t, calm, cx) {
    const st = LABEL[a.status] ? a.status : "idle";
    const color = t[st] ?? t.dim;

    // +N changes flash briefly (opacity transition, native)
    const prev = this.counts.get(a.address);
    if (prev !== undefined && prev !== a.subs && !calm) {
      this.flash.add(a.address);
      cx.timer.after(450, (c) => { this.flash.delete(a.address); c.notify(); });
    }
    this.counts.set(a.address, a.subs);

    const card = v_flex().id(`card-${a.address}`).relative().w(168).h(132).rounded(8)
      .bg(t.surface).border(1).border_color(t.border).overflow_hidden()
      .when(st === "idle", (el) => el.opacity(0.7));

    // --- state layer (behind the content) ---
    if (st === "working") {
      const glow = div().absolute().inset(0).bg(color);
      card.child(calm ? glow.opacity(0.1) : glow.opacity(0.05).loop("opacity", { from: 0.04, to: 0.16, period: 2600 }));
    }
    if (st === "blocked") {
      const ring = div().absolute().inset(0).rounded(8).border(2).border_color(color);
      card.child(calm ? ring : ring.loop("opacity", { from: 0.25, to: 1, period: 2000 }));
    }

    // --- room: the visual for the state ---
    const room = div().h(64).w_full().flex().items_center().justify_center().relative();
    if (st === "blocked") {
      const bang = div().absolute().top(14).text_size(30).font_bold().text_color(color).child("!");
      room.child(calm ? bang : bang.loop("top", { from: 14, to: 6, period: 1200 }));
    } else if (st === "working") {
      room.child(div().size(10).rounded_full().bg(color)
        .when(!calm, (el) => el.loop("opacity", { from: 0.45, to: 1, period: 1600 })));
    } else if (st === "idle") {
      const z = (txt, size, period, x) => {
        const el = div().absolute().left(x).top(26).text_size(size).font_semibold().text_color(t.dim).child(txt);
        return calm ? el.opacity(0.6) : el.loop("opacity", { from: 0.1, to: 0.7, period }).loop("top", { from: 30, to: 18, period });
      };
      room.child(z("z", 14, 3200, 72)).child(z("z", 18, 4200, 86));
    } else {
      // done: pop once (spring with overshoot), then it stays at rest
      const settled = calm || this.popped.has(a.address);
      if (!settled) cx.timer.after(60, (c) => { this.popped.add(a.address); c.notify(); });
      const d = settled ? 30 : 4;
      room.child(div().w(34).h(34).flex().items_center().justify_center()
        .child(div().w(d).h(d).rounded_full().bg(alpha(color, 0.18)).border(1.5).border_color(color)
          .overflow_hidden().flex().items_center().justify_center()
          .spring("width", { response: 380, damping: 0.45 }).spring("height", { response: 380, damping: 0.45 })
          .child(svg("mods/workspace-chrome/check.svg").size(16).flex_none().text_color(color))));
    }
    card.child(room);

    // --- text ---
    return card.child(v_flex().px(12).pb(10).gap(3)
      .child(h_flex().items_center().gap(6)
        .child(div().flex_1().truncate().text_color(t.foreground).font_semibold().child(a.program?.name ?? "agent"))
        .when(a.subs > 0, (el) => el.child(div().text_size(11).text_color(color)
          .opacity(this.flash.has(a.address) ? 0.35 : 1).transition("opacity", { duration: 350, easing: "ease-out" })
          .child(`+${a.subs}`))))
      .child(div().text_size(10.5).font_semibold().text_color(color).child(LABEL[st]))
      .child(div().truncate().text_size(10.5).text_color(t.dim).child(st === "blocked" ? NOTE.blocked : (a.title || NOTE[st]))));
  }
}
