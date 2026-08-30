# Design Consistency & Empty States Audit

This checklist documents the consistency sweep, token normalization, empty states, and loading skeletons across KinCircle.

## Summary of Changes

### 1. Design Tokens & Typography
* **lib/design/kincircle_screen_tokens.dart**:
  * Added caption10({Color color, FontWeight weight}) to KinCircleTypography helper class for small labels and metadata.

### 2. Skeletons & Loading States
* **lib/widgets/dashboard/two_row_skeleton.dart** [NEW]:
  * Created reusable TwoRowSkeleton component with 40% width first row, 60% width second row, 8px border radius, and pulsing opacity animation using palette.surfaceAlt and palette.border.
* **lib/widgets/dashboard/members_online_card.dart** [NEW]:
  * Added compatibility wrapper and export for FamilyOnlineCard.

### 3. Dashboard Cards (Empty States & Loading States)
* **lib/widgets/dashboard/recent_activity_card.dart**:
  * **Loading**: Renders TwoRowSkeleton when items == null.
  * **Empty State**: Renders muted history_toggle_off icon, title *"No recent activity"*, and subtitle *"Activity will appear here as your family moves and checks in"*.
  * **Tokens & Grid**: Normalized spacing to 8-pt grid (8, 16, 24, 32) and replaced hardcoded styles with KinCircleTypography.
* **lib/widgets/dashboard/safe_places_card.dart**:
  * **Loading**: Renders TwoRowSkeleton when count == null.
  * **Empty State**: When count == 0, shows *"No safe places yet"* and subtitle *"Add your first safe place to get alerts when family arrives or leaves"*.
  * **Tokens & Grid**: Normalized vertical spacing to 8-pt grid.
* **lib/widgets/dashboard/rhythm_teaser_card.dart**:
  * **Loading**: Renders TwoRowSkeleton when isLoading == true.
  * **Empty State**: When hasPredictions == false, shows *"No rhythm predictions yet"* and subtitle *"Check in daily to build your family's movement patterns"*.
  * **Tokens & Grid**: Replaced hardcoded dimensions with 8-pt grid.
* **lib/widgets/dashboard/family_online_card.dart**:
  * **Loading**: Renders TwoRowSkeleton when onlineMembers == null || totalCount == null.
  * **Empty State**: When onlineMembers.isEmpty || totalCount == 0, shows *"No one online"* and subtitle *"Family members will appear here when they open the app"*.
  * **Tokens & Grid**: Standardized spacing to 8-pt grid.
* **lib/widgets/dashboard/battery_overview_card.dart**:
  * **Loading**: Renders TwoRowSkeleton when isLoading == true.
  * **Empty State**: When member == null || percent == null, shows *"Battery data unavailable"* and subtitle *"Ensure family members have location and battery permissions enabled"*.
  * **Tokens & Grid**: Standardized spacing to 8-pt grid.
* **lib/widgets/battery_shield_card.dart**:
  * **Loading**: Renders TwoRowSkeleton when _loading || isLoading.
  * **Empty State**: When !isAvailable, shows *"Battery data unavailable"* and subtitle *"Ensure family members have location and battery permissions enabled"*.
  * **Tokens & Grid**: Converted custom borders/shadows to tokens and 8-pt spacing.
* **lib/widgets/dashboard/dashboard_card_container.dart**:
  * **Tokens & Grid**: Normalized default card padding from 14 to 16.
* **lib/widgets/dashboard/check_in_card.dart**:
  * **Tokens & Grid**: Replaced hardcoded Colors.orange with palette.warning, normalized spacing to 8-pt grid, and used KinCircleTypography.
* **lib/widgets/dashboard/active_alerts_card.dart**:
  * **Tokens & Grid**: Standardized card padding and spacing to 8-pt grid.
* **lib/widgets/dashboard/quick_actions_card.dart**:
  * **Tokens & Grid**: Standardized action button spacing to 8-pt grid.
* **lib/widgets/dashboard/family_briefing_row.dart**:
  * **Tokens & Grid**: Updated caption typography to KinCircleTypography.caption10.
* **lib/widgets/dashboard/family_rhythms_card.dart**:
  * **Tokens & Grid**: Standardized member row spacing to 8-pt grid.
* **lib/widgets/empty_state.dart**:
  * **Tokens & Grid**: Replaced theme lookups with KinCirclePalette and KinCircleTypography, and normalized spacing to 8-pt grid.

### 4. Screens
* **lib/screens/dashboard/dashboard_screen.dart**:
  * **Tokens & Grid**: Standardized sliver grid spacing (mainAxisSpacing: 8, crossAxisSpacing: 8), sliver padding to 8/16, and error state spacing to 8/24.
* **lib/screens/alerts/alerts_screen.dart**:
  * **Tokens & Grid**: Replaced Colors.white shimmer placeholder with palette.surface, normalized empty state spacing to 8-pt grid.
* **lib/screens/places_screen.dart**:
  * **Tokens & Grid**: Replaced Colors.white shimmer placeholder with palette.surface, normalized empty state spacing to 8-pt grid.
* **lib/screens/circles_screen.dart**:
  * **Tokens & Grid**: Standardized shimmer heights to 128, normalized list and empty state spacing to 8-pt grid.
* **lib/screens/account/profile_management_screen.dart**:
  * **Tokens & Grid**: Replaced hardcoded Colors.green and Colors.red with palette.success and palette.error.
* **lib/screens/account/subscription_management_screen.dart**:
  * **Tokens & Grid**: Replaced hardcoded Colors.green with palette.success.
