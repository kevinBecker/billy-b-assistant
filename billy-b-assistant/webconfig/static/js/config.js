// ===================== LOGS =====================

let autoScrollEnabled = false;

async function fetchLogs() {
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
}

document.addEventListener("DOMContentLoaded", () => {
    // Element references
    const elements = {
        logOutput: document.getElementById("log-output"),
        logContainer: document.getElementById("log-container"),
        toggleFullscreenBtn: document.getElementById("toggle-fullscreen-btn"),
        scrollBtn: document.getElementById("scroll-bottom-btn"),
        scrollBtnFullscreen: document.getElementById("scroll-bottom-btn-fullscreen"),
        logOverlay: document.getElementById("log-overlay"),
        body: document.body,
        toggleBtn: document.getElementById("toggle-log-btn"),
        logPanel: document.getElementById("log-panel"),
    };

    let isHidden = true;

    // Toggle log visibility
    function toggleLogPanel() {
        isHidden = !isHidden;
        elements.logPanel.classList.toggle("hidden", isHidden);
        elements.toggleBtn.textContent = isHidden ? "Show Log" : "Hide Log";
    }

    // Fullscreen mode using class toggle
    function toggleFullscreenLog() {
        const container = document.getElementById("log-container");
        const icon = document.getElementById("fullscreen-icon");

        const isFullscreen = container.classList.toggle("log-fullscreen");
        icon.textContent = isFullscreen ? "fullscreen_exit" : "fullscreen";
    }

    // Auto-scroll toggle
    function toggleAutoScroll() {
        autoScrollEnabled = !autoScrollEnabled;
        elements.scrollBtn.classList.toggle("bg-cyan-500", autoScrollEnabled);
        elements.scrollBtn.classList.toggle("bg-zinc-800", !autoScrollEnabled);
        elements.scrollBtn.title = autoScrollEnabled ? "Auto-scroll ON" : "Auto-scroll OFF";

        if (autoScrollEnabled) {
            elements.logOutput.scrollTop = elements.logOutput.scrollHeight;
        }
    }

    // Event bindings
    elements.toggleBtn.addEventListener("click", toggleLogPanel);
    elements.toggleFullscreenBtn.addEventListener("click", toggleFullscreenLog);
    elements.scrollBtn.addEventListener("click", toggleAutoScroll);
});

// ===================== SERVICE STATUS =====================

async function fetchStatus() {
    const res = await fetch("/service/status");
    const data = await res.json();
    updateServiceStatusUI(data.status);
}

function updateServiceStatusUI(status) {
    const statusEl = document.getElementById("service-status");
    const controlsEl = document.getElementById("service-controls");

    // Set status text
    statusEl.textContent = `(${status})`;

    // Reset previous color classes
    statusEl.classList.remove("text-emerald-500", "text-amber-500", "text-rose-500");

    // Add color based on status
    if (status === "active") {
        statusEl.classList.add("text-emerald-500");
    } else if (status === "inactive") {
        statusEl.classList.add("text-amber-500");
    } else if (status === "failed") {
        statusEl.classList.add("text-rose-500");
    }

    // Clear and repopulate controls
    controlsEl.innerHTML = "";

    const createButton = (label, action, color) => {
        const btn = document.createElement("button");
        btn.textContent = label;
        btn.className = `bg-${color}-500 hover:bg-${color}-600 text-white font-semibold py-1 px-3 rounded`;
        btn.onclick = () => handleServiceAction(action);
        return btn;
    };

    if (status === "inactive" || status === "failed") {
        controlsEl.appendChild(createButton("Start", "start", "emerald"));
    } else if (status === "active") {
        controlsEl.appendChild(createButton("Restart", "restart", "amber"));
        controlsEl.appendChild(createButton("Stop", "stop", "rose"));
    } else {
        controlsEl.textContent = "Unknown status.";
    }
}

async function handleServiceAction(action) {
    await fetch(`/service/${action}`);
    fetchStatus();
    fetchLogs();
}

// ===================== SETTINGS FORM =====================

function handleSettingsSave() {
    document.getElementById("config-form").addEventListener("submit", async function (e) {
        e.preventDefault();

        const res = await fetch("/service/status");
        const { status: wasActive } = await res.json();

        const formData = new FormData(this);
        const payload = Object.fromEntries(formData.entries());

        await fetch("/save", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload),
        });

        showNotification("Settings saved");

        if (res.ok) {
            await setupDeviceControls();
        } else {
            alert("Failed to save settings.");
        }

        if (wasActive === "active") {
            await fetch("/service/restart");
            showNotification("Settings saved – service restarted");
            fetchStatus();
        }
    });
}

// ===================== PERSONA FORM =====================

function addBackstoryField(key = "", value = "") {
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
    removeBtn.className = "text-red-400 text-xl";
    removeBtn.innerHTML = "&minus;";
    removeBtn.onclick = () => wrapper.remove();

    wrapper.append(keyInput, valInput, removeBtn);
    document.getElementById("backstory-fields").appendChild(wrapper);
}

async function loadPersona() {
    const res = await fetch("/persona");
    const data = await res.json();

    renderPersonalitySliders(data.PERSONALITY);
    renderBackstoryFields(data.BACKSTORY);
    document.getElementById("meta-text").value = data.META || "";
}

function renderPersonalitySliders(personality) {
    const container = document.getElementById("personality-sliders");
    container.innerHTML = "";

    for (const [key, value] of Object.entries(personality)) {
        const wrapper = document.createElement("div");
        wrapper.className = "flex items-center space-x-4";

        const label = document.createElement("label");
        label.className = "w-32 font-semibold text-sm";
        label.textContent = key;
        label.for = key;

        const input = Object.assign(document.createElement("input"), {
            type: "range",
            name: key,
            min: 0,
            max: 100,
            value,
            className: "flex-1"
        });

        const output = document.createElement("span");
        output.className = "w-10 text-sm text-zinc-400 text-right";
        output.textContent = value;

        input.addEventListener("input", () => {
            output.textContent = input.value;
        });

        wrapper.append(label, input, output);
        container.appendChild(wrapper);
    }
}

function renderBackstoryFields(backstory) {
    const container = document.getElementById("backstory-fields");
    container.innerHTML = "";
    Object.entries(backstory).forEach(([k, v]) => addBackstoryField(k, v));
}

function handlePersonaSave() {
    document.getElementById("persona-form").addEventListener("submit", async (e) => {
        e.preventDefault();

        const res = await fetch("/service/status");
        const { status: wasActive } = await res.json();

        const personality = {};
        document.querySelectorAll("#personality-sliders input").forEach((input) => {
            personality[input.name] = parseInt(input.value, 10);
        });

        const backstory = {};
        document.querySelectorAll("#backstory-fields > div").forEach((row) => {
            const [keyInput, valInput] = row.querySelectorAll("input");
            if (keyInput.value.trim() !== "") {
                backstory[keyInput.value.trim()] = valInput.value.trim();
            }
        });

        const meta = document.getElementById("meta-text").value.trim();

        await fetch("/persona", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ PERSONALITY: personality, BACKSTORY: backstory, META: meta })
        });

        showNotification("Persona saved");

        if (wasActive === "active") {
            await fetch("/service/restart");
            showNotification("Persona saved – service restarted");
            fetchStatus();
        }
    });
}

// ===================== UI =====================

function showNotification(message, duration = 2500) {
    const bar = document.getElementById("notification");
    bar.textContent = message;
    bar.classList.remove("hidden", "opacity-0");
    bar.classList.add("opacity-100");

    setTimeout(() => {
        bar.classList.remove("opacity-100");
        bar.classList.add("opacity-0");
        setTimeout(() => bar.classList.add("hidden"), 300);
    }, duration);
}

// ===================== AUDIO =====================

fetch("/device-info")
    .then(res => res.json())
    .then(data => {
        document.getElementById("mic-label").innerHTML = data.mic;
        document.getElementById("speaker-label").innerHTML = data.speaker;
    });

let micCheckSource = null;

document.getElementById("mic-check-btn").addEventListener("click", toggleMicCheck);

async function toggleMicCheck() {
    const btn = document.getElementById("mic-check-btn");
    const warning = document.getElementById("mic-check-warning");
    const isActive = btn.classList.contains("bg-emerald-600");

    if (isActive) {
        stopMicCheck();
        btn.classList.remove("bg-emerald-600");
        btn.classList.add("bg-zinc-800");
        warning.classList.add("hidden");
    } else {
        // Check if the service is running
        const res = await fetch("/service/status");
        const { status } = await res.json();

        if (status === "active") {
            warning.textContent = "⚠️ Please stop the Billy service with the button at the top of the page before running mic check.";
            warning.classList.remove("hidden");
            return; // Block mic check start
        }

        warning.classList.add("hidden");
        startMicCheck();
        btn.classList.remove("bg-zinc-800");
        btn.classList.add("bg-emerald-600");
    }
}

function stopMicCheck() {
    micCheckSource.close();
    fetch("/mic-check/stop");
    micCheckSource = null;

    updateMicBar(0);
    clearThresholdLine();
}

function startMicCheck() {
    let maxRms = 0;

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

        const SCALING_FACTOR = 32768;
        const rms = data.rms * SCALING_FACTOR;
        const threshold = data.threshold;
        maxRms = Math.max(maxRms, rms);

        const percent = Math.min((rms / threshold) * 100, 100);
        const thresholdPercent = Math.min((threshold / SCALING_FACTOR) * 100, 100);

        updateMicBar(percent, thresholdPercent);
        updateThresholdLine(thresholdPercent);
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
    bar.classList.toggle("bg-yellow-500", percentage >= 70 && percentage < 90);
    bar.classList.toggle("bg-red-500", percentage >= 90);
}

function updateThresholdLine(percent) {
    document.getElementById("threshold-line").style.left = `${percent}%`;
}

function clearThresholdLine() {
    document.getElementById("threshold-line").style.left = "0%";
}

async function loadMicGain() {
    const label = document.getElementById("mic-gain-value");
    const slider = document.getElementById("mic-gain");

    try {
        const res = await fetch("/mic-gain");
        const data = await res.json();
        if (data.gain !== undefined) {
            label.textContent = data.gain;
            slider.value = data.gain;
        } else {
            label.textContent = "Unavailable";
        }
    } catch (err) {
        label.textContent = "Error";
    }
}

document.getElementById("mic-gain").addEventListener("change", async () => {
    const value = parseInt(document.getElementById("mic-gain").value, 10);
    await fetch("/mic-gain", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ value })
    });
    document.getElementById("mic-gain-value").textContent = value;
});

// ===================== INITIALIZE =====================

document.addEventListener("DOMContentLoaded", () => {
    fetchLogs();
    fetchStatus();
    setInterval(fetchLogs, 5000);
    setInterval(fetchStatus, 10000);

    loadPersona();
    loadMicGain();
    handleSettingsSave();
    handlePersonaSave();
});