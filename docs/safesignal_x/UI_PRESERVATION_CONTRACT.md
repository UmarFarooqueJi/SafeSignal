# SAFESIGNAL X: UI/UX PRESERVATION CONTRACT

**Strict Directive:** RULE 1 (PRESERVE EXISTING UI/UX EXACTLY)  
**Status:** BINDING DESIGN CONTRACT FOR ALL CODE COMMITS  

---

## 1. Absolute Preservation Boundaries

The existing visual design of SafeSignal is approved and established. No engineering modification may alter:
- **Application Theme:** Material 3 Dark Cyber Theme (`lib/core/theme/app_theme.dart`).
- **Color Palette:**
  - Background: Dark Navy/Black `#0A0E1A` (`AppColors.background`)
  - Primary Accent: Neon Cyan `#00E5FF` (`AppColors.primary`)
  - Critical/Danger: Neon Red/Coral `#FF1744` (`AppColors.critical`)
  - Warning/Suspicious: Amber/Yellow `#FFC107` (`AppColors.warning`)
  - Success/Safe: Emerald Green `#00E676` (`AppColors.safe`)
  - Surface/Cards: Deep Slate `#141C2E` (`AppColors.cardBackground`) with subtle border `#1E293B`
- **Typography:** Custom font scales defined in `lib/core/theme/typography.dart`.
- **Dashboard Layout:** The executive score dial, quick action cards, threat radar, and bottom navigation bar on `HomeScreen` must remain structurally and visually identical.
- **Screen Navigation:** All 19 existing routes and their visual entry points must remain intact.

---

## 2. Permitted Additive UI Surfaces

The only permitted UI modifications are:
1. **Additive Link Guard Results Sheet:** When an incoming shared link (`ACTION_SEND`) arrives from WhatsApp, Telegram, or browsers, display an incoming scan bottom sheet or modal dialog rendered using standard SafeSignal design tokens (`AppColors.cardBackground`, cyan accents, standard typography).
2. **Vault Master Passphrase Prompt:** A secure PIN/Passphrase dialog when biometric hardware is unavailable or un-enrolled, rendered using existing SafeSignal input field styling.
3. **Corrected Claim Texts:** Textual updates on screens that previously claimed "100% Air-Gapped" or "AI Analysis" to accurately describe on-device heuristic & local ML operations without changing layout or font sizes.
4. **Offline Mode Indicators:** Subtle status badge in the chat screen indicating "On-Device Engine (Private & Offline)".

---

## 3. UI Component Reuse Standards

Any new dialog, bottom sheet, or indicator MUST reuse existing widgets:
- `GlassmorphicContainer` / `Card` with `AppColors.cardBackground` and `1px` border `AppColors.cardBorder`.
- Primary actions use `ElevatedButton` with `AppColors.primary` background and black text.
- Secondary actions use `OutlinedButton` with `AppColors.primary` border.
- Security severity badges use existing `SeverityBadge` component with appropriate color mappings.
