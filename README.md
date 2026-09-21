DruidForeverManabar

<p align="center">
  <img src="https://i.imgur.com/xIDoEIU.gif" alt="DruidForeverManabar in action" width="760">
</p>

A lightweight Druid mana-tracking addon built specifically for World of Warcraft: Forever.

Keep your Mana visible while shapeshifted, track the Five Second Rule, and quickly see when Spirit-based mana regeneration is ready to resume.

Overview

DruidForeverManabar adds a dedicated Mana bar that remains available while using Druid shapeshift forms such as Cat, Bear, Dire Bear, Travel, and Aquatic Form.

It also tracks the Five Second Rule after Mana is spent, giving you a clear visual indication of when Spirit-based mana regeneration can begin again.

By default, the Mana bar appears only while shapeshifted. If you prefer a consistent display at all times, it can also be enabled in normal caster form from the addon settings.

Features

Mana tracking while shapeshifted

Keep your Mana visible while using:

Cat Form

Bear Form

Dire Bear Form

Travel Form

Aquatic Form

Five Second Rule tracker

When a successful spell spends Mana, the addon starts a five-second timer.

The tracker includes:

A moving indicator across the Mana bar

An optional numeric countdown

Automatic reset when another Mana-costing spell is successfully cast

Energy and Rage abilities do not reset the timer.

Accurate resource handling

DruidForeverManabar distinguishes Mana-costing spells from abilities that use other resources.

Examples:

Healing spells reset the timer

Mana-costing shapeshifts reset the timer

Cat Form Energy abilities are ignored

Bear Form Rage abilities are ignored

Failed or interrupted casts do not start the timer

Mana percentage

Your current Mana percentage is displayed directly on the bar for quick resource awareness.

Customizable display

The options panel lets you adjust:

Show Mana bar in caster form

Show or hide the Five Second Rule countdown

Font

Font size

Bar width

Bar height

UI scale

Player Frame snapping

Free positioning

Available built-in fonts include:

Arial Narrow

Friz Quadrata

Morpheus

Skurri

Settings

<p align="center">
  <img src="https://i.imgur.com/geYL8aZ.png" alt="DruidForeverManabar settings menu" width="720">
</p>

How It Works

DruidForeverManabar listens for successful spell casts and checks whether the spell uses Mana.

When Mana is spent:

The Five Second Rule timer starts.

The visual indicator progresses across the Mana bar.

The optional countdown shows the remaining time.

Another Mana-costing spell resets the timer.

Energy and Rage abilities are ignored.

The Mana bar itself continues to represent your Mana pool even while another resource, such as Energy or Rage, is your active shapeshift resource.

Commands

/dfm
Opens the addon settings.

/dfm test
Starts a test Five Second Rule countdown.

/dfm debug
Displays diagnostic information useful for troubleshooting.

Installation

Download the latest release.

Extract the DruidForeverManabar folder.

Place it in your World of Warcraft AddOns directory.

Restart the game or reload the UI.

Enable the addon from the AddOns menu if necessary.

World of Warcraft: Forever Compatibility

DruidForeverManabar is designed specifically for the World of Warcraft: Forever client and its modern addon API.

Forever uses newer API restrictions, including protected or secret values in some situations. The addon avoids unsafe arithmetic or comparisons on restricted values and uses supported display APIs where possible.

Because Forever is still in active development, future client updates may require changes to the addon.

Performance

DruidForeverManabar is intentionally small and dependency-free.

It primarily relies on Blizzard events for spell and resource updates rather than continuously polling game state, keeping runtime overhead low.

Bug Reports

If you encounter an issue, please include:

What you were doing when the issue occurred

Your current Druid form

The spell or ability involved

Any Lua error message

Output from /dfm debug, if relevant

Version

1.0.3

Author

antisnake
