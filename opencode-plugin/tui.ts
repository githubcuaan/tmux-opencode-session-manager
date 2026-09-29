import { Plugin } from "@opencode/plugin/tui"
import { startBridge } from "./bridge.mjs"

export default Plugin.define({
  id: "tmux-opencode-client-state",
  setup: startBridge,
})
