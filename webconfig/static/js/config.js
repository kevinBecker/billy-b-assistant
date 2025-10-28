// ===================== APP CONFIG (single fetch) =====================
const AppConfig = (() => {
    let cfg = null;
    let promise = null;

    const load = () => {
        if (promise) return promise;
        promise = fetch("/config")
            .then(r => r.json())
            .then(j => (cfg = j))
            .catch(e => {
                console.warn("Failed to load /config:", e);
                cfg = {};
                return cfg;
            });
        return promise;
    };

    const get = () => cfg || {};
    return { load, get };
})();


// ===================== Header Secondary Actions =====================

const LogPanel = (() => {
    let autoScrollEnabled = false;
    let isLogHidden = true;
    let isEnvHidden = true;
    let isSupportHidden = true;
    let isReleaseHidden = true;

    // Reboot Billy
    const rebootBilly = async () => {
        if (!confirm("Are you sure you want to reboot Billy? This will reboot the whole system.")) return;
        try {
            const res = await fetch('/reboot', {method: 'POST'});
            const data = await res.json();
            if (data.status === "ok") {
                showNotification("Billy is rebooting!", "success");
                setTimeout(() => {
                    location.reload();
                }, 15000);
            }
            else {
                showNotification(data.error || "Reboot failed", "error");
            }
        } catch (err) {
            console.error("Failed to reboot Billy:", err);
            showNotification("Failed to reboot Billy", "error");
        }
    };

    // Shutdown Billy
    const shutdownBilly = async () => {
        if (!confirm("Are you sure you want to shutdown Billy?\n\nThis will power off the Raspberry Pi but one or more of the motors may remain engaged.\n" +
            "To fully power down, make sure to also switch off or unplug the power supply after shutdown.")) return;
        try {
            const res = await fetch('/shutdown', {method: 'POST'});
            const data = await res.json();
            if (data.status === "ok") {
                showNotification("Billy is shutting down!", "success");
                setTimeout(() => {
                    location.reload();
                }, 3000);
            }
            else {
                showNotification(data.error || "Shutdown failed", "error");
            }
        } catch (err) {
            console.error("Failed to shutdown Billy:", err);
            showNotification("Failed to shutdown Billy", "error");
        }
    };

    const restartUI = async () => {
        try {
            const res = await fetch('/restart', {method: 'POST'});
            const data = await res.json();
            if (data.status === "ok") {
                showNotification("Restarting UI…", "success");
                setTimeout(() => location.reload(), 3000);
            } else {
                showNotification(data.error || "Restart failed", "error");
            }
        } catch (err) {
            showNotification(err.message, "error");
        }
    };


    // Fetch logs and update UI
    const fetchLogs = async () => {
        const res = await fetch("/logs");
        const data = await res.json();
        const logOutput = document.getElementById("log-output");
        const logContainer = document.getElementById("log-container");

        logOutput.textContent = data.logs || "No logs found.";

        if (autoScrollEnabled) {
            requestAnimationFrame(() => {
                logContainer.scrollTop = logContainer.scrollHeight;
            });
        }
    };

    // Toggle log panel visibility
    const toggleLogPanel = () => {
        isLogHidden = !isLogHidden;
        elements.logPanel.classList.toggle("hidden", isLogHidden);
        elements.toggleBtn.classList.toggle("bg-cyan-500", !isLogHidden);
        elements.toggleBtn.classList.toggle("bg-zinc-700", isLogHidden);
    };

    // Toggle .env editor visibility and fetch content if showing
    const toggleEnvPanel = () => {
        isEnvHidden = !isEnvHidden;
        elements.envPanel.classList.toggle("hidden", isEnvHidden);
        elements.toggleEnvBtn.classList.toggle("bg-amber-500", !isEnvHidden);
        elements.toggleEnvBtn.classList.toggle("bg-zinc-700", isEnvHidden);

        if (!isEnvHidden) {
            fetch('/get-env')
                .then(res => res.text())
                .then(text => elements.envTextarea.value = text.trim())
                .catch(() => showNotification("An error occurred while loading .env", "error"));
        }
    };

    const toggleSupportPanel = () => {
        isSupportHidden = !isSupportHidden;
        elements.supportPanel.classList.toggle("hidden", isSupportHidden);
        elements.toggleSupportBtn.classList.toggle("bg-red-500", !isSupportHidden);
        elements.toggleSupportBtn.classList.toggle("bg-zinc-700", isSupportHidden);
    };

    const toggleReleasePanel = () => {
        isReleaseHidden = !isReleaseHidden;

        elements.releasePanel.classList.toggle("hidden", isReleaseHidden);

        // active styling like other toggles
        elements.toggleReleaseBtn.classList.toggle("bg-emerald-500", !isReleaseHidden);
        elements.toggleReleaseBtn.classList.toggle("hover:bg-emerald-400", !isReleaseHidden);
        elements.toggleReleaseBtn.classList.toggle("text-black", !isReleaseHidden);

        elements.toggleReleaseBtn.classList.toggle("bg-zinc-700", isReleaseHidden);
        elements.toggleReleaseBtn.classList.toggle("hover:bg-zinc-600", isReleaseHidden);
    };

    const toggleMotion = () => {
        const btn = elements.toggleMotionBtn;
        const icon = btn.querySelector(".material-icons");

        btn.classList.toggle("bg-zinc-700");
        document.documentElement.classList.toggle("reduce-motion");

        const isReduced = document.documentElement.classList.contains("reduce-motion");
        localStorage.setItem("reduceMotion", isReduced ? "1" : "0");

        // Toggle icon
        if (icon) {
            icon.textContent = isReduced ? "blur_off" : "blur_on";
        }
    };

    // Fullscreen toggle
    const toggleFullscreenLog = () => {
        const icon = document.getElementById("fullscreen-icon");
        const isFullscreen = elements.logContainer.classList.toggle("log-fullscreen");
        icon.textContent = isFullscreen ? "fullscreen_exit" : "fullscreen";
    };

    // Toggle auto-scroll to bottom of log
    const toggleAutoScroll = () => {
        autoScrollEnabled = !autoScrollEnabled;
        elements.scrollBtn.classList.toggle("bg-cyan-500", autoScrollEnabled);
        elements.scrollBtn.classList.toggle("bg-zinc-800", !autoScrollEnabled);
        elements.scrollBtn.title = autoScrollEnabled ? "Auto-scroll ON" : "Auto-scroll OFF";

        if (autoScrollEnabled) {
            elements.logOutput.scrollTop = elements.logOutput.scrollHeight;
        }
    };

    // Save .env file and optionally restart service
    const saveEnv = async () => {
        if (!confirm("Are you sure you want to overwrite the .env file? This may affect how Billy runs.")) return;

        try {
            const res = await fetch('/save-env', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({content: elements.envTextarea.value})
            });
            const data = await res.json();

            if (data.status === "ok") {
                fetch('/restart', {method: 'POST'})
                    .then(res => res.json())
                    .then(data => {
                        if (data.status === "ok") {
                            showNotification(".env saved. Restarting", "success");
                            setTimeout(() => location.reload(), 3000);
                        } else {
                            showNotification(data.error || "Restart failed", "error");
                        }
                    })
                    .catch(err => showNotification(err.message, "error"));
            } else {
                showNotification(data.error || "Unknown error", "error");
            }
        } catch (err) {
            showNotification(err.message, "error");
        }
    };

    // Cache DOM references after DOMContentLoaded
    let elements = {};
    const bindUI = (cfg = {}) => {
        elements = {
            logOutput: document.getElementById("log-output"),
            logContainer: document.getElementById("log-container"),
            toggleFullscreenBtn: document.getElementById("toggle-fullscreen-btn"),
            scrollBtn: document.getElementById("scroll-bottom-btn"),
            toggleBtn: document.getElementById("toggle-log-btn"),
            logPanel: document.getElementById("log-panel"),
            toggleEnvBtn: document.getElementById("toggle-env-btn"),
            envPanel: document.getElementById("env-panel"),
            envTextarea: document.getElementById("env-textarea"),
            saveEnvBtn: document.getElementById("save-env-btn"),
            toggleMotionBtn: document.getElementById("toggle-motion-btn"),
            powerBtn: document.getElementById("power-btn"),
            powerDropdown: document.getElementById("power-dropdown"),
            rebootBillyBtn: document.getElementById("reboot-billy-btn"),
            restartUIBtn: document.getElementById("restart-ui-btn"),
            shutdownBillyBtn: document.getElementById("shutdown-billy-btn"),
            toggleSupportBtn: document.getElementById("toggle-support-btn"),
            supportPanel: document.getElementById("support-panel"),

            // Release panel bits
            toggleReleaseBtn: document.getElementById("current-version"),
            releasePanel: document.getElementById("release-panel"),
            releaseTitle: document.getElementById("release-title"),
            releaseBody: document.getElementById("release-body"),
            releaseLink: document.getElementById("release-link"),
            releaseClose: document.getElementById("release-close"),
            releaseMarkRead: document.getElementById("release-mark-read"),
            releaseBadge: document.getElementById("release-badge"),
        };

        const show = String(cfg.SHOW_SUPPORT || "").toLowerCase() === "true";
        if (show) {
            elements.toggleSupportBtn?.classList.remove("hidden");
        } else {
            elements.toggleSupportBtn?.classList.add("hidden");
            elements.supportPanel?.classList.add("hidden");
            isSupportHidden = true;
        }

        // Toggle dropdown open/close
        elements.powerBtn?.addEventListener("click", (e) => {
            e.stopPropagation();
            elements.powerDropdown?.classList.toggle("hidden");
        });

        // Close on outside click
        document.addEventListener("click", (e) => {
            const menu = document.getElementById("power-menu");
            if (!menu?.contains(e.target)) {
                elements.powerDropdown?.classList.add("hidden");
            }
        });

        elements.toggleBtn.addEventListener("click", toggleLogPanel);
        elements.toggleFullscreenBtn.addEventListener("click", toggleFullscreenLog);
        elements.scrollBtn.addEventListener("click", toggleAutoScroll);
        elements.toggleEnvBtn.addEventListener("click", toggleEnvPanel);
        elements.toggleMotionBtn.addEventListener("click", toggleMotion);
        elements.saveEnvBtn.addEventListener("click", saveEnv);
        elements.rebootBillyBtn.addEventListener("click", rebootBilly);
        elements.restartUIBtn.addEventListener("click", restartUI);
        elements.shutdownBillyBtn.addEventListener("click", shutdownBilly);
        elements.toggleSupportBtn?.addEventListener("click", toggleSupportPanel);
        elements.toggleReleaseBtn?.addEventListener("click", toggleReleasePanel);
        elements.releaseClose?.addEventListener("click", () => {
            isReleaseHidden = true;
            elements.releasePanel.classList.add("hidden");
            // reset button to inactive style
            elements.toggleReleaseBtn.classList.remove("bg-emerald-500","hover:bg-emerald-400","text-black");
            elements.toggleReleaseBtn.classList.add("bg-zinc-700","hover:bg-zinc-600","text-white");
        });

        if (localStorage.getItem("reduceMotion") === "1") {
            document.documentElement.classList.add("reduce-motion");

            const btn = elements.toggleMotionBtn;
            const icon = btn.querySelector(".material-icons");
            btn.classList.remove("bg-zinc-700");

            if (icon) {
                icon.textContent = "blur_off";
            }
        }

    };

    return {fetchLogs, bindUI};
})();

// ===================== SERVICE STATUS =====================

const ServiceStatus = (() => {
    const fetchStatus = async () => {
        const res = await fetch("/service/status");
        const data = await res.json();
        updateServiceStatusUI(data.status);
    };

    const updateServiceStatusUI = (status) => {
        const statusEl = document.getElementById("service-status");
        const controlsEl = document.getElementById("service-controls");
        const logoEl = document.getElementById("status-logo");

        statusEl.textContent = `(${status})`;
        statusEl.classList.remove("text-emerald-500", "text-amber-500", "text-rose-500");

        let logoSrc = "/static/images/status-inactive.png";

        if (status === "active") {
            statusEl.classList.add("text-emerald-500");
            logoSrc = "/static/images/status-active.png";
        } else if (status === "inactive") {
            statusEl.classList.add("text-amber-500");
            logoSrc = "/static/images/status-inactive.png";
        } else if (status === "failed") {
            statusEl.classList.add("text-rose-500");
            logoSrc = "/static/images/status-inactive.png"; // fallback
        }

        // Swap the logo if element exists
        if (logoEl) logoEl.src = logoSrc;

        controlsEl.innerHTML = "";
        const createButton = (label, action, color, iconName) => {
            const btn = document.createElement("button");
            btn.className = `flex items-center transition-all gap-1 bg-${color}-500 hover:bg-${color}-400 text-zinc-800 font-semibold py-1 px-2 rounded`;

            const icon = document.createElement("i");
            icon.className = "material-icons";
            icon.textContent = iconName;
            btn.appendChild(icon);

            const labelSpan = document.createElement("span");
            labelSpan.className = "hidden md:inline";
            labelSpan.textContent = label;
            btn.appendChild(labelSpan);

            btn.onclick = () => handleServiceAction(action);
            return btn;
        };

        if (status === "inactive" || status === "failed") {
            controlsEl.appendChild(createButton("Start", "start", "emerald", "play_arrow"));
        } else if (status === "active") {
            controlsEl.appendChild(createButton("Restart", "restart", "amber", "restart_alt"));
            controlsEl.appendChild(createButton("Stop", "stop", "rose", "stop"));
        } else {
            controlsEl.textContent = "Unknown status.";
        }
    };

    const handleServiceAction = async (action) => {
        const statusEl = document.getElementById("service-status");
        const logoEl = document.getElementById("status-logo");

        const statusMap = {
            restart: {text: "restarting", color: "text-amber-500", logo: "/static/images/status-starting.png"},
            stop:    {text: "stopping",   color: "text-rose-500",   logo: "/static/images/status-stopping.png"},
            start:   {text: "starting",   color: "text-emerald-500",logo: "/static/images/status-starting.png"}
        };

        if (statusMap[action]) {
            const {text, color, logo} = statusMap[action];
            statusEl.textContent = text;
            statusEl.classList.remove("text-emerald-500", "text-amber-500", "text-rose-500");
            statusEl.classList.add(color);
            if (logoEl) logoEl.src = logo;
        }

        try {
            await fetch(`/service/${action}`);
        } catch (err) {
            console.error(`Failed to ${action} service:`, err);
        }

        fetchStatus();
        LogPanel.fetchLogs();
    };

    return {fetchStatus, updateServiceStatusUI};
})();


// ===================== PIN PROFILE + HARDWARE VISIBILITY =====================
const PinProfile = (() => {
    function syncHardwareVisibility() {
        const pinSelect = document.getElementById('BILLY_PINS_SELECT');
        const modelRow  = document.getElementById('hardware-version-row');
        const modelSel  = document.getElementById('BILLY_MODEL');
        if (!pinSelect || !modelRow || !modelSel) return;

        const isNew = pinSelect.value === 'new';
        const isMotorHat = pinSelect.value === 'adafruit_motor_hat';

        if (isNew || isMotorHat) {
            modelRow.classList.add('hidden', 'force-hidden');
            if (!modelSel.dataset.prev) modelSel.dataset.prev = modelSel.value;
            modelSel.value = 'modern';
            modelSel.disabled = true;
        } else {
            modelRow.classList.remove('hidden', 'force-hidden');
            modelSel.disabled = false;
            if (modelSel.dataset.prev) modelSel.value = modelSel.dataset.prev;
        }
    }

    function bindUI(cfg = {}) {
        const sel = document.getElementById('BILLY_PINS_SELECT');
        if (!sel) return;

        // Initialize select from config
        const mode = String(cfg.BILLY_PINS || 'new').toLowerCase();
        sel.value = mode;
        sel.setAttribute('data-original', mode);

        // Wire visibility behavior
        sel.addEventListener('change', syncHardwareVisibility);
        syncHardwareVisibility(); // run once after initializing value
    }

    return { bindUI };
})();

// ===================== SETTINGS FORM =====================

const SettingsForm = (() => {
    const handleSettingsSave = () => {
        document.getElementById("config-form").addEventListener("submit", async function (e) {
            e.preventDefault();

            const resStatus = await fetch("/service/status");
            const {status: wasActive} = await resStatus.json();

            const formData = new FormData(this);
            const payload = Object.fromEntries(formData.entries());

            const flaskPortInput = document.getElementById("FLASK_PORT");
            const oldPort = parseInt(flaskPortInput.getAttribute("data-original")) || 80;
            const newPort = parseInt(payload["FLASK_PORT"] || "80");

            const hostnameInput = document.getElementById("hostname");
            const oldHostname = (hostnameInput.getAttribute("data-original") || hostnameInput.defaultValue || "").trim();
            const newHostname = (formData.get("hostname") || "").trim();

            const pinSelect = document.getElementById("BILLY_PINS_SELECT");
            if (pinSelect) {
                payload.BILLY_PINS = pinSelect.value; // "new" | "legacy" | "adafruit_motor_hat"
            }

            let hostnameChanged = false;

            // Save config (.env)
            const saveResponse = await fetch("/save", {
                method: "POST",
                headers: {"Content-Type": "application/json"},
                body: JSON.stringify(payload),
            });
            const saveResult = await saveResponse.json();
            let portChanged = saveResult.port_changed || (oldPort !== newPort);

            // Only update hostname if it actually changed
            if (newHostname && newHostname !== oldHostname) {
                const hostResponse = await fetch("/hostname", {
                    method: "POST",
                    headers: {"Content-Type": "application/json"},
                    body: JSON.stringify({hostname: newHostname})
                });
                const hostResult = await hostResponse.json();
                if (hostResult.hostname) {
                    hostnameChanged = true;
                    showNotification(`Hostname updated to ${hostResult.hostname}.local`, "success", 5000);
                }
            }

            await fetch("/service/restart");
            showNotification("Settings saved – Billy restarted", "success");

            if (portChanged || hostnameChanged) {
                const targetHost = hostnameChanged ? `${newHostname}.local` : window.location.hostname;
                const targetPort = portChanged ? newPort : (window.location.port || 80);

                showNotification(`Redirecting to http://${targetHost}:${targetPort}/...`, "warning", 5000);
                setTimeout(() => {
                    window.location.href = `http://${targetHost}:${targetPort}/`;
                }, 3000);
            }
        });
    };

    // Set hostname field from server
    fetch('/hostname')
        .then(res => res.json())
        .then(data => {
            if (data.hostname) {
                const input = document.getElementById('hostname');
                input.value = data.hostname;
                input.setAttribute('data-original', data.hostname);
            }
        });

    // Set original port attribute for change detection
    const flaskPortInput = document.getElementById("FLASK_PORT");
    if (flaskPortInput) {
        flaskPortInput.setAttribute("data-original", flaskPortInput.value);
    }

    return {handleSettingsSave};
})();

// ===================== PERSONA FORM =====================

const PersonaForm = (() => {
    const addBackstoryField = (key = "", value = "") => {
        const wrapper = document.createElement("div");
        wrapper.className = "flex items-center space-x-2";

        const keyInput = Object.assign(document.createElement("input"), {
            type: "text",
            value: key,
            placeholder: "Key",
            className: "w-1/3 p-1 bg-zinc-800 text-white rounded"
        });

        const valInput = Object.assign(document.createElement("input"), {
            type: "text",
            value: value,
            placeholder: "Value",
            className: "flex-1 p-1 bg-zinc-800 text-white rounded"
        });

        const removeBtn = document.createElement("button");
        removeBtn.type = "button";
        removeBtn.className = "text-rose-500 hover:text-rose-400 cursor-pointer";
        const icon = document.createElement("span");
        icon.className = "material-icons align-middle";
        icon.textContent = "remove_circle_outline";
        removeBtn.appendChild(icon);
        removeBtn.onclick = () => wrapper.remove();

        wrapper.append(keyInput, valInput, removeBtn);
        document.getElementById("backstory-fields").appendChild(wrapper);
    };

    const renderPersonalitySliders = (personality) => {
        const container = document.getElementById("personality-sliders");
        container.innerHTML = "";

        for (const [key, value] of Object.entries(personality)) {
            const wrapper = document.createElement("div");
            wrapper.className = "flex gap-2 space-y-1";

            // Label column
            const label = document.createElement("div");
            label.className = "flex w-36 justify-between items-center text-sm text-slate-300 font-semibold";
            label.innerHTML = `<span>${key}</span>`;

            // Bar container
            const barContainer = document.createElement("div");
            barContainer.className = "relative w-full rounded-full bg-zinc-700 overflow-hidden cursor-pointer";
            barContainer.style.userSelect = "none";

            // Fill bar
            const fillBar = document.createElement("div");
            fillBar.className = "absolute left-0 top-0 h-full bg-emerald-500 transition-all duration-100";
            fillBar.style.width = `${value}%`;
            fillBar.dataset.fillFor = key;

            barContainer.appendChild(fillBar);

            // Output value
            const valueLabel = document.createElement("span");
            valueLabel.id = `${key}-value`;
            valueLabel.className = "text-zinc-400 w-4";
            valueLabel.textContent = value;

            // Drag interaction
            let isDragging = false;

            const updateValue = (e) => {
                const rect = barContainer.getBoundingClientRect();
                const percent = Math.min(Math.max((e.clientX - rect.left) / rect.width, 0), 1);
                const newVal = Math.round(percent * 100);
                fillBar.style.width = `${newVal}%`;
                valueLabel.textContent = newVal;
                fillBar.setAttribute("data-value", newVal);
            };

            barContainer.addEventListener("mousedown", (e) => {
                isDragging = true;
                updateValue(e);
            });

            document.addEventListener("mousemove", (e) => {
                if (isDragging) updateValue(e);
            });

            document.addEventListener("mouseup", () => {
                isDragging = false;
            });

            wrapper.appendChild(label);
            wrapper.appendChild(barContainer);
            wrapper.appendChild(valueLabel);

            container.appendChild(wrapper);
        }
    };

    function setupSlider(barId, fillId, inputId, min, max) {
        const bar = document.getElementById(barId);
        const fill = document.getElementById(fillId);
        const input = document.getElementById(inputId);

        let isDragging = false;

        const updateUI = (val) => {
            const percent = ((val - min) / (max - min)) * 100;
            fill.style.width = `${percent}%`;
            fill.dataset.value = val;
        };

        const updateFromMouse = (e) => {
            const rect = bar.getBoundingClientRect();
            const percent = Math.min(Math.max((e.clientX - rect.left) / rect.width, 0), 1);
            const val = Math.round(min + percent * (max - min));
            input.value = val;
            input.dispatchEvent(new Event("input", {bubbles: true}));
            updateUI(val);
        };

        // Allow dragging
        bar.addEventListener("mousedown", (e) => {
            isDragging = true;
            updateFromMouse(e);
        });

        document.addEventListener("mousemove", (e) => {
            if (isDragging) updateFromMouse(e);
        });

        document.addEventListener("mouseup", () => {
            isDragging = false;
        });

        // Sync with input on load/change (just in case)
        input.addEventListener("input", () => updateUI(Number(input.value)));
        updateUI(Number(input.value));
    }

    setupSlider("mic-gain-bar", "mic-gain-fill", "mic-gain", 0, 16);
    setupSlider("speaker-volume-bar", "speaker-volume-fill",  "speaker-volume", 0, 100);

    const renderBackstoryFields = (backstory) => {
        const container = document.getElementById("backstory-fields");
        container.innerHTML = "";
        Object.entries(backstory).forEach(([k, v]) => addBackstoryField(k, v));
    };

    const loadPersona = async () => {
        const res = await fetch("/persona");
        const data = await res.json();
        renderPersonalitySliders(data.PERSONALITY);
        renderBackstoryFields(data.BACKSTORY);
        document.getElementById("meta-text").value = data.META || "";

        await loadWakeupClips();
    };

    const handlePersonaSave = () => {
        document.getElementById("persona-form").addEventListener("submit", async (e) => {
            e.preventDefault();

            const res = await fetch("/service/status");
            const {status: wasActive} = await res.json();

            const personality = {};
            document.querySelectorAll("#personality-sliders div[data-fill-for]").forEach((bar) => {
                const trait = bar.dataset.fillFor;
                personality[trait] = parseInt(bar.style.width);
            });

            const backstory = {};
            document.querySelectorAll("#backstory-fields > div").forEach((row) => {
                const [keyInput, valInput] = row.querySelectorAll("input");
                if (keyInput.value.trim() !== "") {
                    backstory[keyInput.value.trim()] = valInput.value.trim();
                }
            });

            const meta = document.getElementById("meta-text").value.trim();

            const wakeup = {};
            const rows = document.querySelectorAll("#wakeup-sound-list .flex[data-index]");
            let currentIndex = 1;
            rows.forEach((row) => {
                const phrase = row.querySelector("input[type='text']")?.value?.trim();
                if (phrase) {
                    wakeup[currentIndex++] = phrase;
                }
            });

            await fetch("/persona", {
                method: "POST",
                headers: {"Content-Type": "application/json"},
                body: JSON.stringify({PERSONALITY: personality, BACKSTORY: backstory, META: meta, WAKEUP: wakeup })
            });

            showNotification("Persona saved", "success");

            if (wasActive === "active") {
                await fetch("/service/restart");
                showNotification("Persona saved – service restarted", "success");
                ServiceStatus.fetchStatus();
            }
        });
    };

    return {addBackstoryField, loadPersona, handlePersonaSave};
})();


// ===================== WAKEUP CLIPS =====================

async function loadWakeupClips() {
    const container = document.getElementById("wakeup-sound-list");
    container.innerHTML = ""; // clear previous rows

    try {
        const res = await fetch("/wakeup");
        const { clips } = await res.json();

        if (clips.length === 0) {
            const message = document.createElement("div");
            message.className = "text-sm text-zinc-400 italic py-2";
            message.textContent = "No custom wake-up clips added. Using the default sounds.";
            container.appendChild(message);
            return;
        }
        else {
            const label = document.createElement("label");
            label.className = "flex items-center justify-between font-semibold text-sm text-slate-300 mb-1"
            label.innerHtml = `Words or phrases that Billy will randomly say on activation:`;
            container.appendChild(label);
        }

        clips.sort((a, b) => a.index - b.index).forEach(({ index, phrase, has_audio }) => {
            const row = document.createElement("div");
            row.className = "flex items-center space-x-2";
            row.dataset.index = index;

            row.innerHTML = `
                <input type="text" class="text-input w-full rounded bg-zinc-800 border border-zinc-700 px-2 py-1" value="${phrase}">
                <button type="button" class="wakeup-generate-btn text-white hover:text-amber-400" title="Generate .wav">
                    <i class="material-icons align-middle">auto_fix_high</i>
                </button>
                <button type="button" class="wakeup-play-btn text-white hover:text-emerald-400 ${!has_audio ? 'invisible' : ''}" title="Play .wav">
                    <i class="material-icons align-middle">play_arrow</i>
                </button>
                <button type="button" class="remove-wakeup-row text-rose-500 hover:text-rose-400" title="Remove">
                    <i class="material-icons align-middle">remove_circle_outline</i>
                </button>
            `;

            container.appendChild(row);
        });
    } catch (err) {
        console.error("Failed to load wakeup clips:", err);
        showNotification("Failed to load wakeup clips", "error");
    }
}

function addWakeupSound(index = null, phrase = "", hasAudio = false) {
    const container = document.getElementById("wakeup-sound-list");
    const rows = container.querySelectorAll("div[data-index]");
    const usedIndices = Array.from(rows).map(row => parseInt(row.dataset.index));
    const nextIndex = index ?? (usedIndices.length > 0 ? Math.max(...usedIndices) + 1 : 1);

    const row = document.createElement("div");
    row.className = "flex items-center space-x-2";
    row.dataset.index = nextIndex;

    row.innerHTML = `
        <input type="text" class="text-input w-full rounded bg-zinc-800 border border-zinc-700 px-2 py-1" value="${phrase}" placeholder="word or phrase">
        <button type="button" class="wakeup-generate-btn text-white hover:text-amber-400" title="Generate .wav">
            <i class="material-icons align-middle">auto_fix_high</i>
        </button>
        <button type="button" class="wakeup-play-btn text-white hover:text-emerald-400 ${!hasAudio ? 'invisible' : ''}" title="Play .wav">
            <i class="material-icons align-middle">play_arrow</i>
        </button>
        <button type="button" class="remove-wakeup-row text-rose-500 hover:text-rose-400" title="Remove">
            <i class="material-icons align-middle">remove_circle_outline</i>
        </button>
    `;

    container.appendChild(row);
}

document.getElementById("wakeup-sound-list").addEventListener("click", async (e) => {
    const row = e.target.closest(".flex");
    if (!row) return;

    const clipIndex = row.dataset.index;
    const input = row.querySelector("input[type='text']");
    const phrase = input?.value?.trim();

    // === Play button ===
    if (e.target.closest(".wakeup-play-btn")) {
        const clipIndex = e.target.closest("div[data-index]")?.dataset.index;
        if (!clipIndex) return;

        const tryPlay = async () => {
            const res = await fetch("/wakeup/play", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ index: parseInt(clipIndex) }),
            });

            const data = await res.json();
            if (!res.ok) throw new Error(data.error || "Failed to play audio");

            showNotification(data.status, "success");
        };

        try {
            await tryPlay();
        } catch (err) {
            console.warn("Initial play failed, trying to stop service and retry:", err.message);
            try {
                await fetch("/service/stop");
                await ServiceStatus.fetchStatus();
                await tryPlay(); // retry after stopping
                showNotification("Billy was active. Stopped and retried clip.", "warning");
            } catch (retryErr) {
                console.error("Retry failed:", retryErr);
                showNotification("Play failed after retry: " + retryErr.message, "error");
            }
        }

        return;
    }

    // === Generate button ===
    if (e.target.closest(".wakeup-generate-btn")) {
        const generateBtn = e.target.closest("button");
        generateBtn.disabled = true;
        generateBtn.classList.add("opacity-50");
        generateBtn.querySelector("i").textContent = "hourglass_empty";

        if (!phrase) {
            showNotification("Please enter a phrase", "warning");
            return;
        }

        try {
            const res = await fetch("/wakeup/generate", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ text: phrase, index: parseInt(clipIndex) }),
            });

            if (!res.ok) {
                const err = await res.json();
                throw new Error(err.error || "Failed to generate audio");
            }

            const resPersona = await fetch("/persona/wakeup", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ index: clipIndex, phrase: phrase }),
            });

            if (!resPersona.ok) {
                const err = await resPersona.json();
                throw new Error(err.error || "Failed to update persona");
            }

            showNotification(`Clip ${clipIndex} generated and saved!`, "success");

            await loadWakeupClips();

        } catch (err) {
            console.error("Generate error:", err);
            showNotification("Generate failed: " + err.message, "error");
        } finally {
            generateBtn.disabled = false;
            generateBtn.classList.remove("opacity-50");
            generateBtn.querySelector("i").textContent = "auto_fix_high";
        }
        return;
    }

    if (e.target.closest(".remove-wakeup-row")) {
        const row = e.target.closest("div[data-index]");
        const clipIndex = row?.dataset.index;

        if (!clipIndex) return;

        if (!confirm("Are you sure you want to delete this wake-up clip?")) return;

        try {
            const res = await fetch("/wakeup/remove", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ index: parseInt(clipIndex) }),
            });

            const data = await res.json();
            if (!res.ok) throw new Error(data.error || "Failed to remove clip");

            showNotification(`Clip ${clipIndex} removed`, "success");

            await loadWakeupClips();
        } catch (err) {
            console.error("Remove error:", err);
            showNotification("Remove failed: " + err.message, "error");
        }
    }
});

// ===================== UI HELPERS =====================

function showNotification(message, type = "info", duration = 2500) {
    const bar = document.getElementById("notification");
    bar.textContent = message;
    bar.classList.remove("hidden", "opacity-0", "bg-cyan-500/80", "bg-emerald-500/80", "bg-amber-500/80", "bg-rose-500/80");
    const typeClass = {
        info: "bg-cyan-500/80",
        success: "bg-emerald-500/80",
        warning: "bg-amber-500/80",
        error: "bg-rose-500/80",
    }[type] || "bg-cyan-500/80";
    bar.classList.add(typeClass, "opacity-100");
    setTimeout(() => {
        bar.classList.remove("opacity-100");
        bar.classList.add("opacity-0");
        setTimeout(() => bar.classList.add("hidden"), 300);
    }, duration);
}

// Toggle password input visibility
function toggleInputVisibility(inputId) {
    const input = document.getElementById(inputId);
    const icon = document.getElementById(`${inputId}_icon`);
    const isHidden = input.type === "password";
    input.type = isHidden ? "text" : "password";
    icon.textContent = isHidden ? "visibility_off" : "visibility";
}

function toggleDropdown(btn) {
    // Close all other dropdowns first
    document.querySelectorAll('.dropdown-menu').forEach(menu => {
        // Only close menus not related to this button
        if (!menu.classList.contains('hidden') && !menu.parentElement.contains(btn)) {
            menu.classList.add('hidden');
            const arrow = menu.parentElement.querySelector('.dropdown-toggle .material-icons');
            if (arrow) arrow.classList.remove('rotate-180');
        }
    });

    // Find this button's dropdown menu (assumes menu is sibling or child)
    let dropdown = btn.closest('.relative').querySelector('.dropdown-menu');
    if (!dropdown) return;

    dropdown.classList.toggle('hidden');

    // Toggle arrow rotation
    const arrow = btn.querySelector('.material-icons');
    if (arrow) arrow.classList.toggle('rotate-180');
}

function toggleTooltip(el) {
    el.classList.toggle("text-cyan-400")
    const container = el.closest("label")?.parentElement;
    if (!container) return;

    const tooltip = container.querySelector("[data-tooltip]");
    if (tooltip) {
        const visible = tooltip.getAttribute("data-visible") === "true";
        tooltip.setAttribute("data-visible", visible ? "false" : "true");
    }
}


// Close on click outside
document.addEventListener('click', (e) => {
    document.querySelectorAll('.dropdown-menu').forEach(menu => {
        // If the click is outside the .relative container
        if (!menu.classList.contains('hidden') && !menu.closest('.relative').contains(e.target)) {
            menu.classList.add('hidden');
            const arrow = menu.parentElement.querySelector('.dropdown-toggle .material-icons');
            if (arrow) arrow.classList.remove('rotate-180');
        }
    });
});

// ===================== VERSION & UPDATE =====================

(() => {
    fetch("/version")
        .then(res => res.json())
        .then(data => {
            const currentBtn = document.getElementById("current-version");
            if (currentBtn) {
                const label = currentBtn.querySelector(".label");
                if (label) label.textContent = `${data.current}`;
            }
            if (data.update_available) {
                const latestSpan = document.getElementById("latest-version");
                const updateBtn = document.getElementById("update-btn");
                if (latestSpan) {
                    latestSpan.textContent = `Update to: ${data.latest}`;
                    latestSpan.classList.remove("hidden");
                }
                if (updateBtn) {
                    updateBtn.classList.add('flex');
                    updateBtn.classList.remove("hidden");
                }
            }
        })
        .catch(err => {
            console.error("Failed to load version info", err);
        });

    document.getElementById("update-btn").addEventListener("click", () => {
        if (!confirm("Are you sure you want to update Billy to the latest version?")) return;
        showNotification("Update started");
        fetch("/update", {method: "POST"})
            .then(res => res.json())
            .then(data => {
                if (data.message) {
                    showNotification(data.message);
                }
                let attempts = 0, maxAttempts = 24;
                const checkForUpdate = async () => {
                    try {
                        const res = await fetch("/version");
                        const data = await res.json();
                        if (data.update_available === false) {
                            showNotification("Update complete. Reloading...", "info");
                            setTimeout(() => location.reload(), 1500);
                            return;
                        }
                    } catch (err) {
                        console.error("Version check failed:", err);
                    }
                    attempts++;
                    if (attempts < maxAttempts) {
                        setTimeout(checkForUpdate, 5000);
                    } else {
                        showNotification("Update timed out after 2 minutes. Reloading");
                        setTimeout(() => location.reload(), 1500);
                    }
                };
                setTimeout(checkForUpdate, 5000);
            })
            .catch(err => {
                console.error("Failed to update:", err);
                showNotification("Failed to update", "error");
            });
    });
})();

// ===================== RELEASE NOTES =====================
const ReleaseNotes = (() => {
    const keyFor = (tag) => `release_notice_read_${tag}`;

    const els = {
        panel:       () => document.getElementById("release-panel"),
        title:       () => document.getElementById("release-title"),
        body:        () => document.getElementById("release-body"),
        link:        () => document.getElementById("release-link"),
        markReadBtn: () => document.getElementById("release-mark-read"),
        closeBtn:    () => document.getElementById("release-close"),
        badge:       () => document.getElementById("release-badge"),
        toggleBtn:   () => document.getElementById("current-version"),
    };

    async function fetchNote() {
        const res = await fetch("/release-note");
        if (!res.ok) throw new Error("Failed to fetch /release-note");
        return res.json(); // { tag, body, url, fetched_at }
    }

    function isRead(tag) {
        return localStorage.getItem(keyFor(tag)) === "1";
    }

    function markRead(tag) {
        localStorage.setItem(keyFor(tag), "1");

        const badge = els.badge();
        if (badge) badge.classList.add("!hidden");

        const mark = els.markReadBtn();
        if (mark) mark.classList.add("!hidden");

        showNotification("Marked release notes as read", "success");
    }

    function render(note) {
        const t = els.title();
        const b = els.body();
        const l = els.link();
        const mark = els.markReadBtn();
        const badge = els.badge();

        if (t) t.textContent = `Release Notes – ${note.tag}`;
        if (b) b.innerHTML = marked.parse(note.body || "No content.");

        if (l) {
            if (note.url) {
                l.href = note.url;
                l.classList.remove("hidden");
            } else {
                l.classList.add("hidden");
            }
        }

        const read = isRead(note.tag);

        // Toggle badge visibility
        if (badge) badge.classList.toggle("!hidden", read);

        // Toggle Mark as read visibility
        if (mark) mark.classList.toggle("!hidden", read);

        // Wire button
        if (mark && !read) {
            mark.onclick = () => markRead(note.tag);
        }

        const close = els.closeBtn();
        if (close) {
            close.onclick = () => {
                const panel = els.panel();
                const btn = els.toggleBtn();
                if (panel) panel.classList.add("hidden");
                if (btn) {
                    btn.classList.remove("bg-emerald-500", "hover:bg-emerald-400", "text-black");
                    btn.classList.add("bg-zinc-700", "hover:bg-zinc-600");
                }
            };
        }
    }

    async function init() {
        try {
            const note = await fetchNote();
            render(note);
        } catch (e) {
            console.warn("Release notes unavailable:", e);
            const badge = els.badge();
            if (badge) badge.classList.add("hidden");
        }
    }

    return { init };
})();

// ===================== AUDIO =====================

const AudioPanel = (() => {
    let micCheckSource = null;

    const micCheckBtn = document.getElementById("mic-check-btn");
    micCheckBtn.addEventListener("click", toggleMicCheck);

    document.getElementById("speaker-check-btn").addEventListener("click", async () => {
        try {
            const res = await fetch("/service/status");
            const {status} = await res.json();
            if (status === "active") {
                showNotification("⚠️ Please stop the Billy service before running speaker test.", "warning");
                return;
            }
            await fetch("/speaker-test", {method: "POST"});
            showNotification("Speaker test triggered");
        } catch (err) {
            console.error("Failed to trigger speaker test:", err);
            showNotification("Failed to trigger speaker test", "error");
        }
    });

    async function toggleMicCheck() {
        const btn = micCheckBtn;
        const isActive = btn.classList.contains("bg-emerald-600");
        if (isActive) {
            stopMicCheck();
            btn.classList.remove("bg-emerald-600");
            btn.classList.add("bg-zinc-800");
            showNotification("Mic check stopped");
        } else {
            try {
                const res = await fetch("/service/status");
                const {status} = await res.json();
                if (status === "active") {
                    await fetch("/service/stop");
                    showNotification("Billy was stopped for mic check. You’ll need to start it again afterwards.", "warning");
                }
                startMicCheck();
                btn.classList.remove("bg-zinc-800");
                btn.classList.add("bg-emerald-600");
                if (status !== "active") {
                    showNotification("Mic check started");
                }
            } catch (err) {
                console.error("Failed to toggle mic check:", err);
                showNotification("Mic check failed", "error");
            }
        }
    }

    function stopMicCheck() {
        micCheckSource?.close();
        fetch("/mic-check/stop");
        micCheckSource = null;
        updateMicBar(0);
    }

    function startMicCheck() {
        let maxRms = 0;
        const SCALING_FACTOR = 32768;
        micCheckSource = new EventSource("/mic-check");
        micCheckSource.onmessage = (e) => {
            let data;
            try {
                data = JSON.parse(e.data);
            } catch (err) {
                console.error("Invalid JSON from /mic-check:", e.data);
                return;
            }
            if (data.error) {
                console.error("Mic check error:", data.error);
                return;
            }
            const rms = data.rms * SCALING_FACTOR;
            const threshold = data.threshold;
            maxRms = Math.max(maxRms, rms);
            const percent = Math.min((rms / threshold) * 100, 100);
            const thresholdPercent = Math.min((threshold / SCALING_FACTOR) * 100, 100);
            updateMicBar(percent, thresholdPercent);
        };
        micCheckSource.onerror = () => {
            console.error("Mic check connection error.");
            stopMicCheck();
        };
    }

    function updateMicBar(percentage, thresholdPercent = 0) {
        const bar = document.getElementById("mic-level-bar");
        bar.style.width = `${percentage}%`;
        bar.classList.toggle("bg-zinc-500", percentage < thresholdPercent);
        bar.classList.toggle("bg-emerald-500", percentage < 70);
        bar.classList.toggle("bg-amber-500", percentage >= 70 && percentage < 90);
        bar.classList.toggle("bg-red-500", percentage >= 90);
    }

    // Mic gain UI
    async function loadMicGain() {
        const label = document.getElementById("mic-gain-value");
        const slider = document.getElementById("mic-gain");
        const fill = document.getElementById("mic-gain-fill");

        try {
            const res = await fetch("/mic-gain");
            const data = await res.json();
            if (data.gain !== undefined) {
                slider.value = data.gain;
                label.textContent = data.gain;

                const percent = (data.gain / 16) * 100;
                fill.style.width = `${percent}%`;
                fill.dataset.value = data.gain;
            } else {
                label.textContent = "Unavailable";
            }
        } catch (err) {
            label.textContent = "Error";
        }
    }

    document.getElementById("mic-gain").addEventListener("input", async () => {
        const value = parseInt(document.getElementById("mic-gain").value, 10);
        await fetch("/mic-gain", {
            method: "POST",
            headers: {"Content-Type": "application/json"},
            body: JSON.stringify({value})
        });
        document.getElementById("mic-gain-value").textContent = value;
    });

    // Silence threshold drag interaction
    let micBar = document.getElementById("mic-bar-container");
    let thresholdLine = document.getElementById("threshold-line");
    let silenceThresholdInput = document.getElementById("SILENCE_THRESHOLD");
    let dragging = false;

    thresholdLine.addEventListener("mousedown", (e) => {
        dragging = true;
        e.preventDefault();
    });

    document.addEventListener("mousemove", (e) => {
        if (!dragging) return;
        const rect = micBar.getBoundingClientRect();
        if (rect.width === 0) return;
        let offsetX = e.clientX - rect.left;
        offsetX = Math.max(0, Math.min(offsetX, rect.width));
        const percent = offsetX / rect.width;
        const scaledThreshold = Math.round(percent * 32768);
        thresholdLine.style.left = `${percent * 100}%`;
        silenceThresholdInput.value = scaledThreshold;
    });

    document.addEventListener("mouseup", () => {
        dragging = false;
    });

    window.addEventListener("load", () => {
        const threshold = parseInt(silenceThresholdInput.value || "1000", 10);
        thresholdLine.style.left = `${(threshold / 32768) * 100}%`;
    });

    // Speaker volume
    const speakerSlider = document.getElementById("speaker-volume");
    fetch("/volume")
        .then(res => res.json())
        .then(data => {
            if (data.volume !== undefined) {
                speakerSlider.value = data.volume;
                const fill = document.getElementById("speaker-volume-fill");
                const percent = (data.volume / 100) * 100;
                fill.style.width = `${percent}%`;
                fill.dataset.value = data.volume;
            }
        });
    let volumeDebounceTimeout;

    speakerSlider.addEventListener("input", () => {
        clearTimeout(volumeDebounceTimeout);
        volumeDebounceTimeout = setTimeout(() => {
            fetch("/volume", {
                method: "POST",
                headers: {"Content-Type": "application/json"},
                body: JSON.stringify({volume: parseInt(speakerSlider.value)})
            }).catch(err => console.error("Failed to set speaker volume:", err));
        }, 500);
    });

    // Device labels
    async function updateDeviceLabels() {
        try {
            const res = await fetch("/device-info");
            const data = await res.json();
            const updateParentClass = (id, value) => {
                const el = document.getElementById(id);
                if (el && el.parentElement) {
                    el.textContent = value;
                    el.parentElement.classList.add("text-emerald-500");
                }
            };
            updateParentClass("mic-label", data.mic);
            updateParentClass("speaker-label", data.speaker);
        } catch (error) {
            console.error("Failed to fetch device info:", error);
        }
    }

    return {loadMicGain, updateDeviceLabels};
})();

// ===================== MOTOR TEST PANEL =====================

const MotorPanel = (() => {
    function sendMotorTest(motor) {
        fetch("/test-motor", {
            method: "POST",
            headers: {"Content-Type": "application/json"},
            body: JSON.stringify({motor})
        })
            .then(res => res.json())
            .then(data => {
                if (data.error) {
                    showNotification("Motor error: " + data.error, "error", 4000);
                } else {
                    showNotification(`Tested ${motor}`, "success", 1500);
                    if (data.service_was_active) {
                        showNotification(
                            "Billy was stopped for hardware test. Please restart Billy again when done.",
                            "warning",
                            7000
                        );
                        ServiceStatus.fetchStatus();
                    }
                }
            })
            .catch(err => showNotification("Motor test failed: " + err, "error"));
    }

    // Attach events after DOM loaded
    function bindUI() {
        ["mouth", "head", "tail"].forEach(motor => {
            const btn = document.getElementById(`test-${motor}-btn`);
            if (btn) {
                btn.addEventListener("click", function () {
                    sendMotorTest(motor);
                });
            }
        });
    }

    return {bindUI};
})();

// ===================== COLLAPSIBLE SECTIONS =====================

const Sections = (() => {
    function collapsible() {
        document.querySelectorAll('.collapsible-section').forEach(section => {
            const header = section.querySelector('h3');
            if (!header) return;

            // Add icon if not present
            let icon = header.querySelector('.material-icons');
            if (!icon) {
                icon = document.createElement('span');
                icon.className = 'material-icons transition-transform duration-200 ml-2 rotate-0';
                icon.textContent = 'expand_more';
                header.appendChild(icon);
            } else {
                icon.classList.add('transition-transform', 'duration-200', 'ml-2');
                icon.classList.add('rotate-0');
            }

            // Restore state from localStorage
            const id = section.id;
            const collapsed = localStorage.getItem('collapse_' + id) === 'closed';

            icon.classList.toggle('rotate-180', !collapsed);
            icon.classList.toggle('rotate-0', collapsed);
            header.classList.toggle('mb-4', !collapsed);

            [...section.children].forEach(child => {
                if (child !== header && !child.classList.contains('force-hidden')) {
                    child.classList.toggle('hidden', collapsed);
                }
            });

            // Click to toggle
            header.addEventListener('click', () => {
                const collapsed = section.classList.toggle('collapsed');
                [...section.children].forEach(child => {
                    if (child !== header) child.classList.toggle('hidden', collapsed);
                });
                icon.classList.toggle('rotate-180', !collapsed);
                icon.classList.toggle('rotate-0', collapsed);

                // Toggle mb-4 on h3 only when expanded
                header.classList.toggle('mb-4', !collapsed);

                localStorage.setItem('collapse_' + id, collapsed ? 'closed' : 'open');
            });
        });
    }

    return {collapsible};
})();

// ===================== IMPORT / EXPORT =====================

function exportSettings() {
    fetch('/get-env').then(res => res.text()).then(text => {
        const blob = new Blob([text], {type: "application/octet-stream"});
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = "billy.env";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    });
}

function importSettings(input) {
    const file = input.files[0];
    if (!file) return;
    if (!file.name.endsWith('.env')) {
        showNotification("Only .env files are allowed.", "error");
        return;
    }
    const reader = new FileReader();
    reader.onload = function (e) {
        fetch('/save-env', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({content: e.target.result})
        })
            .then(res => res.json())
            .then(data => {
                if (data.status === "ok") {
                    showNotification("Settings imported. Restarting...", "success");
                    setTimeout(() => location.reload(), 2000);
                } else {
                    showNotification(data.error || "Failed to import settings.", "error");
                }
            });
    };
    reader.readAsText(file);
}

function exportPersona() {
    const a = document.createElement('a');
    a.href = '/persona/export';
    a.download = 'persona.ini';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
}

function importPersona(input) {
    const file = input.files[0];
    if (!file) return;
    if (!file.name.endsWith('.ini')) {
        showNotification("Only .ini files are allowed.", "error");
        return;
    }
    const formData = new FormData();
    formData.append('file', file);
    fetch('/persona/import', {
        method: 'POST',
        body: formData
    })
        .then(res => res.json())
        .then(data => {
            if (data.status === "ok") {
                showNotification("Persona imported. Restarting...", "success");
                setTimeout(() => location.reload(), 2000);
            } else {
                showNotification(data.error || "Failed to import persona.", "error");
            }
        });
}

// ===================== INITIALIZE =====================

document.addEventListener("DOMContentLoaded", async () => {
    const cfg = await AppConfig.load();

    LogPanel.bindUI(cfg);
    LogPanel.fetchLogs();
    ServiceStatus.fetchStatus();
    setInterval(LogPanel.fetchLogs, 5000);
    setInterval(ServiceStatus.fetchStatus, 10000);

    AudioPanel.updateDeviceLabels();
    PersonaForm.loadPersona();
    AudioPanel.loadMicGain();
    SettingsForm.handleSettingsSave();
    PersonaForm.handlePersonaSave();
    window.addBackstoryField = PersonaForm.addBackstoryField;
    MotorPanel.bindUI();
    PinProfile.bindUI(cfg);
    Sections.collapsible();
    ReleaseNotes.init();
});