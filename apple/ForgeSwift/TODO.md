# Components TODO

## Content
- Audio
- Chart
- Embed
- Indicator
- Loader
- PDF
- Progress
- Skeleton
- Video

## Input
The vast majority of inputs fall in one of the three categories - text, number and options.

- Plane
    - Slider
    - Knob
    - Dial
- Text
    - TextField
    - Stepper
- Picker
    - Date
    - Color
    - Tabs
    - Toggle
        - Switch
        - Radio
        - Checkbox
        - Icon
        - Chip
        - Tile

## Layout

Each layout is basically taking a parent's bounds and previously laid out children to determine where a next child should go.
Some layouts don't need to know previously laid out children's rects, because the rules are mathematical.
We should be able to write a generic layout delegate

- Box
- Flex
- Wrap
- Grid
- Masonry
- Table

## Overlays
- Alert
- Barrier
- Coachmark
- ContextMenu
- Cover
- Drawer
- Lightbox
- Modal
- Popover
- Screen
- Sheet
- Toast

## Semantic
- AppBar
- Badge
- Droppable
- Heading
- ListItem
- Scaffold

## Visibility
- Lift
- Transition

## Utility
- PlatformBuilder
