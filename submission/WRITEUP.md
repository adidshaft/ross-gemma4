# ROSS-Gemma4

**Subtitle:** Private AI Junior Associate for Access-to-Justice Workflows

## Product Vision
ROSS-Gemma4 is a mobile-first, privacy-preserving legal workbench built around Gemma 4. It helps advocates and legal clinics process casework directly on their devices, ensuring client confidentiality and offline capability.

## Gemma 4 Integration
Gemma 4 capability packs power local intake, chronology building, issue extraction, and first-pass drafting.
ROSS-Gemma4 uses Gemma 4 models selected by device capability and workflow complexity:

- **Quick Associate (Gemma 4 E2B Q4):** For initial intake and checklist verification.
- **Case Associate (Gemma 4 E4B Q4):** For chronology building, issue extraction, and missing-fact analysis.
- **Senior Drafting Support (Gemma 4 26B-A4B Q4):** For advanced drafting in clinic workstation mode.

## Architecture
- **Mobile-first inference:** Runs locally on iOS utilizing an integrated local runtime abstraction.
- **Strict Privacy:** Zero case files are uploaded to the cloud. Inference happens on-device.
- **Tier-based capability:** Dynamic downloading of Gemma 4 capability packs depending on hardware limits.

## Submission Details
- **Demo Mode:** Since verified Gemma 4 GGUFs and an active iOS runtime package are pending integration, the app is running in Demo Mode where model responses are simulated for walkthrough purposes. It will gracefully upgrade to real Gemma 4 inference when the verified artifact URLs are updated and a replacement runtime is deployed.
