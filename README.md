DruidForeverManabar

A lightweight mana-tracking addon for Druids in World of Warcraft: Forever.

DruidForeverManabar keeps your Mana visible while shapeshifted and includes a visual Five Second Rule tracker so you can see when Spirit-based mana regeneration is expected to resume.

Features

Mana bar while shapeshifted

The addon displays a dedicated Mana bar while using:

Cat Form
Bear Form
Dire Bear Form
Travel Form
Aquatic Form

By default, the bar is hidden in normal caster form. An option is available to keep it visible outside shapeshift forms as well.

Mana percentage

Your current Mana percentage is displayed directly on the bar for quick resource tracking.

Five Second Rule tracker

When a spell successfully spends Mana, the addon starts a five-second timer.

The tracker includes:

A moving indicator across the Mana bar

An optional numeric countdown

Automatic reset when another Mana-costing spell is successfully cast

Energy and Rage abilities do not reset the timer.

Spell-cost detection

The addon distinguishes between Mana-based spells and form abilities that use other resources.

Examples:

Healing Touch: resets the timer

Shapeshifting spells with a Mana cost: reset the timer

Cat Form Energy abilities: ignored

Bear Form Rage abilities: ignored

Failed or interrupted casts: ignored

Customizable appearance

Available options include:

Show Mana bar in caster form

Show or hide the Five Second Rule countdown

Font selection

Font size

Movable bar

Player Frame snapping

UI scale

Bar width and height

Built-in font choices include:

Arial Narrow

Friz Quadrata

Morpheus

Skurri

Commands

/dfm

Opens the addon settings.

/dfm test

Starts a test Five Second Rule countdown.

/dfm debug

Displays diagnostic information useful for troubleshooting.

World of Warcraft: Forever

DruidForeverManabar is designed specifically for the World of Warcraft: Forever client and its modern addon API.

Forever uses newer API restrictions, including protected or secret values in some situations. The addon avoids unsafe arithmetic or comparisons on restricted values and uses supported display APIs where possible.

Because Forever is still in active development, future client updates may require addon changes.

Installation

Download the latest release.

Extract the DruidForeverManabar folder.

Place it inside your World of Warcraft AddOns directory.

Restart the game or reload the UI.

Enable the addon from the AddOns menu if necessary.

Development

The addon is intentionally small and dependency-free.

It primarily uses Blizzard events for spell and resource updates rather than continuously polling the game state.

Bug Reports

If you encounter an issue, please include:

What you were doing when the issue occurred

Your current Druid form

The spell or ability involved

Any Lua error message

Output from /dfm debug if relevant

Version

Current version: 1.0.3

Author

antisnake
