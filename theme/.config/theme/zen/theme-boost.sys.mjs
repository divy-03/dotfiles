/* Zen Boosts only apply to the one site they were made on. This makes the
   desktop theme's boost the fallback for every site with no active boost of
   its own, and repaints the open tabs when the theme changes.

   ~/.config/theme/theme writes the boost to <profile>/chrome/theme-boost.json
   and installs theme-boost.cfg (which loads this module at startup) next to
   the Zen binary. A site opts out with a boost of its own that has the color
   adjustments disabled. */

const lazy = {};
ChromeUtils.defineESModuleGetters(lazy, {
  setInterval: "resource://gre/modules/Timer.sys.mjs",
});

const FILE = PathUtils.join(PathUtils.profileDir, "chrome", "theme-boost.json");
// how often the file is checked for a new theme
const POLL_MS = 2000;
// a JSWindowActor: its parent half answers each tab's "what is my boost?"
const ACTOR = "resource:///actors/ZenBoostsParent.sys.mjs";

let boostData = null;
let mtime = 0;

async function reload() {
  let modified = 0;
  try {
    modified = (await IOUtils.stat(FILE)).lastModified;
  } catch {}
  if (modified === mtime) {
    return;
  }
  mtime = modified;
  try {
    boostData = modified ? await IOUtils.readJSON(FILE) : null;
  } catch (e) {
    boostData = null;
    console.error("theme-boost:", e);
  }
  // every open tab asks for its boost again
  Services.obs.notifyObservers(null, "zen-boosts-update");
}

function patch() {
  const { ZenBoostsParent } = ChromeUtils.importESModule(ACTOR);
  const receiveMessage = ZenBoostsParent.prototype.receiveMessage;
  ZenBoostsParent.prototype.receiveMessage = async function (message) {
    const result = await receiveMessage.call(this, message);
    if (
      message.name !== "ZenBoost:GetBoostForDomain" ||
      result ||
      !boostData ||
      !message.data ||
      !this.browsingContext.top.embedderElement
    ) {
      return result;
    }
    return {
      id: "desktop-theme",
      domain: message.data,
      boostEntry: { boostData },
      workspaceGradient: [],
      styleSheet: null,
    };
  };
}

Services.obs.addObserver(function start(subject, topic) {
  Services.obs.removeObserver(start, topic);
  try {
    patch();
  } catch (e) {
    console.error("theme-boost: Zen's boosts changed, not patching", e);
    return;
  }
  reload();
  lazy.setInterval(reload, POLL_MS);
}, "final-ui-startup");
