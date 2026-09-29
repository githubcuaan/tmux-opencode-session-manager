import { execFile } from "node:child_process"
import { promisify } from "node:util"

const exec = promisify(execFile)

export function currentSessionID(context) {
  const route = context.ui.router.current()
  return route.type === "session" && /^ses[a-zA-Z0-9_-]+$/.test(route.sessionID ?? "")
    ? route.sessionID : null
}

export async function startBridge(context) {
  const pane = process.env.TMUX_PANE
  if (!process.env.TMUX || !/^%[0-9]+$/.test(pane ?? "")) return
  const tmux = async (...args) => (await exec("tmux", args, { timeout: 2000 })).stdout.trim()
  let session
  try {
    const prefix = await tmux("show-option", "-gqv", "@opencode_session_prefix") || "opencode-"
    const info = await tmux("display-message", "-p", "-t", pane, "#{session_id}\t#{session_name}")
    const [id, name] = info.split("\t")
    if (!name?.startsWith(prefix)) return
    session = id
  } catch {
    return
  }

  let stopped = false
  let running = false
  let pending = Promise.resolve()
  let lastFocus

  async function publish() {
    if (running || stopped) return
    running = true
    try {
      const id = currentSessionID(context)
      if (id === lastFocus) return
      if (id) {
        await tmux("set-option", "-t", session, "@opencode_session_id", id)
      } else {
        await tmux("set-option", "-u", "-t", session, "@opencode_session_id")
      }
      lastFocus = id
    } catch {
      // A destroyed pane or unavailable tmux must not interrupt the TUI.
    } finally {
      running = false
    }
  }
  function tick() {
    if (!running && !stopped) pending = publish()
  }
  tick()
  const timer = setInterval(tick, 300)
  return async () => {
    stopped = true
    clearInterval(timer)
    await pending
  }
}
