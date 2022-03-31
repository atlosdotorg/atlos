// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
import TomSelect from "../node_modules/tom-select/dist/js/tom-select.complete"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

function initializeMultiSelects() {
    // Make multi-selects interactive
    document.querySelectorAll("select[multiple]").forEach(s => {
        if (s.tomselect) {
            if (document.activeElement == s.tomselect.control_input) {
                return; // Don't update if we're currently editing
            }
        }

        s.tomselect = undefined;
        let x = new TomSelect(`#${s.id}`, {
            maxOptions: null,
            placeholder: "Select all that apply...",
            onItemAdd(_a, _b) {
                setTimeout(() => x.control_input.value = "", 1);
            }
        });
        x.control_input.setAttribute("phx-debounce", "blur");
    });
}

document.addEventListener("phx:update", initializeMultiSelects);
document.addEventListener("load", initializeMultiSelects);