"use strict";

// Promotion panel — intentionally minimal.
//
// This file MUST exist: promotion.xml includes it, and promotion.xml is loaded
// by custom_ui_manifest.xml. If this script is missing, the whole
// custom_ui_manifest fails to COMPILE FROM SOURCE, which silently disables ALL
// custom UI (mode-config panel, currency, custom hero selection, etc.). Shipped
// builds hid this because they ship pre-compiled panorama; compiling from source
// (as the tools do for this repo) requires the file to be present.
//
// promotion.xml only renders a static panel, so no script logic is needed here.
