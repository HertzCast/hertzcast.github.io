# Yamaha Controller — App Store Submission Plan

---

## ⚠️ Pre-requisites Before Any Code Work

### App Name — Trademark Risk
**"Yamaha Controller" uses a registered trademark.** Apple frequently rejects apps that contain third-party brand names in the title. Yamaha can also file a takedown at any time. **Choose a new name before starting Phase 1.** The name change affects: `Info.plist`, `AppDelegate.swift`, `build.sh`, launchd plist labels, and all hardcoded strings.

### No Xcode Project Exists
The current build uses `swiftc` directly via `build.sh` — there is no `.xcodeproj`. App Store Archive requires Xcode. Creating the project (with two targets: main app + SMAppService helper) is the first technical step and takes 1–2 days on its own.

---

## Phase 1 — Code & Technical (Claude Code)

### 1.1 Sandbox Migration
**Ce ceri Claude Code:**
```
Follow the sandbox-migration-plan.md and migrate Yamaha Controller 
from launchd to SMAppService for Mac App Store sandbox compatibility.
Start by analysing SchedulerService.swift, then implement all changes.
```

### 1.2 App Name & Icon Update
**Ce faci tu:**
- Decide noul nume al app-ului
- Creează icon 1024x1024px PNG fără transparență

**Ce ceri Claude Code:**
```
Rename the app from "Yamaha Controller" to "[NEW NAME]" across all 
files in the project — Info.plist, AppDelegate.swift, build.sh, 
launchd plist labels, and any hardcoded strings.
```

### 1.2b Privacy Manifest (Required since 2024)
Apple mandates a `PrivacyInfo.xcprivacy` file declaring which privacy-sensitive APIs the app uses. Without it, the build is rejected automatically. For Yamaha Controller this covers: `UserDefaults`, `URLSession` (network access).

**Ce ceri Claude Code:**
```
Create a PrivacyInfo.xcprivacy file for Yamaha Controller declaring:
- NSPrivacyAccessedAPITypeReasons for UserDefaults (CA92.1)
- No data collected from users (no analytics, no tracking)
```

### 1.3 Xcode Project Setup
**Ce ceri Claude Code:**
```
Set up the Xcode project for Mac App Store submission:
1. Enable App Sandbox entitlement
2. Add network client entitlement (required for YXC HTTP API)
3. Configure App Group entitlement: group.com.[bundleid]
4. Set correct Bundle Identifier (reverse domain, e.g. com.yourname.yamaha)
5. Set Deployment Target to macOS 13.0
6. Configure Release scheme for Archive
```

### 1.4 Notarization & Signing Setup
**Ce ceri Claude Code:**
```
Update build.sh to support proper code signing with Developer ID 
and notarization via notarytool for Mac App Store submission.
The current ad-hoc signing needs to be replaced.
```

### 1.5 Final Testing
- Testează toate funcțiile pe macOS Ventura și Sonoma
- Verifică Morning Alarm și Auto Off cu SMAppService
- Verifică Bonjour discovery
- Zero crash-uri

---

## Phase 2 — Apple Developer Setup (Tu)

### 2.1 Înregistrare Apple Developer Account
- Mergi pe **developer.apple.com/programs**
- Înregistrează-te cu Apple ID-ul tău
- Plătești **$99/an**
- Durată activare: 24-48h

### 2.2 Certificates & Provisioning
- În Xcode → Preferences → Accounts → adaugi Apple ID-ul tău
- Xcode generează automat certificatele necesare
- Creezi **Mac App Store Distribution certificate** în Xcode sau Developer Portal

### 2.3 App Store Connect
- Mergi pe **appstoreconnect.apple.com**
- New App → macOS
- Completezi:
  - **Bundle ID** — trebuie să coincidă cu cel din Xcode
  - **SKU** — orice string unic (ex: yamaha-controller-001)
  - **Nume app**
  - **Preț** — setat în Pricing & Availability

---

## Phase 3 — App Store Metadata (Tu)

### 3.1 Screenshots
- Minim 1 screenshot pentru Mac
- Dimensiuni acceptate: **1280x800** sau **1440x900** sau **2560x1600** sau **2880x1800**
- Poți face screenshot direct din app pe Mac (Shift+Cmd+3)
- Recomand 3-5 screenshots care arată: UI principal, Music Center, Audio Settings, Color Schemes, Alarm setup

### 3.2 Descriere App
- **Subtitle** — max 30 caractere (ex: "Yamaha AV Receiver Control")
- **Description** — max 4000 caractere, explică features
- **Keywords** — max 100 caractere, separate prin virgulă (ex: yamaha,receiver,audio,av,control,remote)
- **Support URL** — poți folosi GitHub repo sau pinecone.design
- **Privacy Policy URL** — obligatorie (pagină simplă pe pinecone.design)

### 3.3 Pricing
- Recomandat: **$4.99**
- Setat în App Store Connect → Pricing & Availability

---

## Phase 4 — Build & Submit

### 4.1 Archive în Xcode
```
Product → Archive → Distribute App → App Store Connect → Upload
```

### 4.2 Submit for Review
- În App Store Connect → selectezi build-ul uploadat
- Completezi toate câmpurile obligatorii
- Submit for Review

### 4.3 Review Apple
- Durata obișnuită: **1-3 zile**
- Dacă e respins, Apple explică exact de ce — corectezi și resubmit

---

## Timeline Estimat (realist, la ritmul actual de lucru)

| Fază | Durată |
|------|--------|
| Ales nume nou + redenumit în cod | 0.5 zile |
| Creat Xcode project (2 target-uri: app + helper) | 1-2 zile |
| Sandbox migration (SMAppService + App Group + helper) | 4-6 zile |
| Privacy manifest + entitlements finale | 0.5 zile |
| Semnare + notarizare setup | 1 zi |
| Testing extensiv (alarm, auto-off, discovery sub sandbox) | 2-3 zile |
| Phase 2 — Apple Developer Setup | 2-3 zile |
| Phase 3 — Metadata & Screenshots | 1-2 zile |
| Phase 4 — Build, Submit, Review Apple | 3-5 zile |
| **Total** | **~3-4 săptămâni** |

---

## Financiar

| | |
|---|---|
| Apple Developer Account | $99/an |
| Comision Apple | 15% (sub $1M/an vânzări) |
| Preț recomandat | $4.99 |
| Vânzări necesare pentru break-even | ~24 descărcări |

---

## Riscuri

| Risc | Probabilitate | Soluție |
|------|--------------|---------|
| **Respins pentru trademark în nume** | **Mare** | **Alege alt nume înainte de orice** |
| Respins pentru sandbox issues | Mică | Rezolvat în Phase 1 |
| Respins pentru Privacy Policy lipsă | Mare dacă uiți | Creezi pagină simplă |
| Respins pentru Privacy Manifest lipsă | Mare dacă uiți | Adăugat în Phase 1.2b |
| SMAppService nu funcționează corect | Medie | Testezi extensiv în Phase 1 |
| Iconița conține elemente Yamaha | Medie | Folosești iconița actuală sau una nouă fără branding |
| Review prelungit | Mică | Normal 1-3 zile |
