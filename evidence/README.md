# Visual evidence: TVPV8/TVP#18 (remove .tvpp, store player data in DB)

Reproduced against the PR head (`gesior/TVP-OTland@5df93f9`, base `33c4bb6`), built on Ubuntu 24.04
with MariaDB 10.11, using an OTCv8 client (`OTCv8/otcv8-dev`) with 7.72 `Tibia.dat`/`Tibia.spr`
driven by a scripted mod (`tools/autotest.lua`) under Xvfb.

## 1. Fresh install cannot log in — `fig1_fresh_schema.png`

The PR adds a SQL file in `migrations/` that nothing runs (the server's migration runner only loads
`data/migrations/{n}.lua`), and `schema.sql` is not updated. With a database built from `schema.sql`,
every login fails with *"Your character could not be loaded."*:

```
[Error - mysql_real_query] Query: SELECT `id`, `name`, ... `blessings`, `cap`, ... FROM `players` WHERE `id` = 1
Message: Unknown column 'blessings' in 'SELECT'
```

## 2. Container contents and item attributes are lost on relog — `fig2_relog_item_loss.png`

After applying `migrations/001_player_data.sql` manually, the scripted client:

1. logs in, creates a backpack, coins and a rope, plus a might ring;
2. sets the ring's attributes with `/attr charges, 7` and `/attr description, Engraved for PR 18 test.`;
3. looks at the ring, screenshots, and logs out (server: `was removed from the game`, so the save ran);
4. starts a **new client process** and logs in again (server: `has logged in`, so the player is reloaded from DB).

| | Before logout | After relog |
|---|---|---|
| Backpack | 3 crystal coins, rope | **empty** |
| Might ring look | "has 7 charges left … Engraved for PR 18 test." | **"has 1 charge left."** (no description) |

The save itself is correct (`db_after_save.txt`): every `attributes` blob starts with the item ID that
`Item::serializeTVPFormat` writes (`C407` = 1988 backpack, `7408` = 2164 ring), followed by the
attributes (`16 0700` = charges 7, `07 1800 "Engraved…"`) and the container children.
The loader creates the item from `itemtype` and then calls `unserializeTVPFormat`, which expects
the ID to be consumed already, so it reads everything 2 bytes early. The next save writes the
damaged state back (`db_after_relog_save.txt`: backpack `…00000000` = 0 children, ring
`1601 00` = 1 charge), so **the loss is permanent**.

## 3. Control: skipping the ID fixes it — `fig3_control_fix.png`

Same scenario with a one-line local change in `IOLoginData::loadPlayer` (not part of the PR):

```cpp
propStream.skip(2); // blob starts with the item id written by serializeTVPFormat
item->unserializeTVPFormat(propStream);
```

Backpack contents, 7 charges and the description all survive, and the re-saved blob is
byte-identical to the original (`control/db_after_relog_save.txt`).

## Not covered visually

Condition subclass state (poison damage list, haste speed delta, light, regeneration, …) and the
MySQL-only syntax issues from the code review were not reproduced here.

## Files

- `fig*.png`: annotated composites; raw screenshots `0*.png`, `control/0*.png`
- `client_*.log`: client logs with `[AUTOTEST]` step and event markers
- `db_*.txt`: `player_items` rows (hex blobs) after each save
- `tools/`: client mod and the run/reset scripts used to produce all of the above
