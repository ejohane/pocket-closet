# Design

## Theme

Pocket Closet uses a restrained native iOS product theme. The interface should feel like Photos, Reminders, and a lightweight inventory tool: familiar, fast, and quiet.

## Color

- Background: semantic grouped system backgrounds.
- Surface: semantic secondary grouped backgrounds and system background cards.
- Ink: semantic primary/secondary labels.
- Primary: muted closet green for primary actions, selected filters, and key status accents.
- Accents: soft pastels for people, locations, and non-critical status chips.
- Destructive: system red for delete/archive confirmations and donate emphasis where appropriate.

Primary action color: muted green, approximately `#2F7656`.

## Typography

Use SF Pro through SwiftUI system typography. Prefer native title, headline, body, callout, subheadline, caption, and footnote text styles so Dynamic Type works without custom scaling.

## Components

- App shell: three native tabs, `Closet`, `Add`, and `Manage`.
- Cards: photo-forward item cards with 12-14pt continuous corners and thin semantic borders.
- Rows: native-feeling metadata rows with SF Symbols, bold labels, trailing values, and chevrons when interactive.
- Chips: horizontal filter chips with clear active/inactive states.
- Buttons: filled muted-green primary buttons, bordered secondary buttons, and destructive buttons only for destructive actions.
- Empty states: short, practical copy plus one obvious action.

## Layout

Closet uses a two-column adaptive grid on iPhone and expands naturally on larger devices. Add and Manage use scrollable, grouped layouts with sticky primary actions where useful. Avoid nested cards and oversized decorative panels.

## Motion

Use standard SwiftUI transitions and native sheet/navigation motion. Do not add decorative page-load animations. Respect reduced motion automatically through native controls.
