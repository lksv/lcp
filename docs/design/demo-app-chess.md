# Demo Application Design: Chess Training Academy

**Status:** Proposed
**Date:** 2026-03-03

## 1. Why Chess (and not another domain)

| Criterion | Chess Training Academy | HR System | Issues Tracker |
|-----------|----------------------|-----------|----------------|
| API-backed models | **Primary feature** — 3 Lichess API models (player, game, puzzle) | Not applicable | Not applicable |
| Cross-source associations | **Natural** — DB members link to API players, assignments link to API puzzles | None | None |
| Tree structures | Opening repertoire (1.e4 → 1...c5 → 2.Nf3 → Najdorf) | Departments, positions, skills | Only project → sub-project |
| Domain appeal | Universal — chess is well-known, visually striking | Every company understands HR | Developer-specific |
| Host app integration | Interactive board viewer (chessboard.js + chess.js) — rich custom page | Standard CRUD only | Standard CRUD only |
| Overlap with existing examples | None — unique domain, unique technical features | None | Partially overlaps with Todo |
| Permission complexity | Coach/student/admin with ownership patterns | Multi-level org structure | Simpler: admin, lead, member |
| Custom renderers | Chess board preview, game result, move list, badge list | Status timeline, org chart | Minimal |
| Real-world data | Lichess public API — real players, real games, real puzzles | Faker-generated | Synthetic only |

**Recommendation:** Chess Training Academy. It is the first demo to showcase **API-backed models**, **cross-source associations** (DB records referencing API data), and **host app custom pages** (interactive board viewer). Combined with tree structures (opening repertoire) and a visually compelling domain, it demonstrates platform capabilities no other demo covers.

---

## 2. Data Model Overview

### 2.1 Entity Relationship Diagram (conceptual)

```
                         ┌───────────────────┐
                         │  lichess_player   │ ◄── API-backed (Lichess)
                         │  (API, read-only) │
                         └────────▲──────────┘
                                  │ cross-source FK (lichess_username)
                         ┌────────┴──────────┐
                         │      Member       │ ◄── central entity (DB)
                         │    (DB, CRUD)     │
                         └──┬──┬──┬──┬──┬───┘
                            │  │  │  │  │
         ┌──────────────────┘  │  │  │  └──────────────────────────┐
         │                     │  │  │                              │
  ┌──────▼───────┐   ┌────────▼──▼──────┐  ┌──────────────┐  ┌───▼──────────────┐
  │  Repertoire  │   │  TrainingPlan    │  │  GameAnnot.  │  │ TournamentEntry  │
  │  (join)      │   │  (coach→student) │  │  (DB+API)    │  │  (DB)            │
  └──────┬───────┘   └────────┬─────────┘  └──────┬───────┘  └───┬──────────────┘
         │                    │                    │              │
  ┌──────▼───────┐   ┌────────▼─────────┐  ┌──────▼───────┐  ┌──▼──────────────┐
  │ OpeningLine  │   │ PuzzleAssignment │  │ lichess_game │  │ ClubTournament  │
  │ (DB, tree)   │   │ (DB+API)         │  │ (API)        │  │ (DB)            │
  └──────────────┘   └────────┬─────────┘  └──────────────┘  └──┬──────────────┘
                              │                                  │
                     ┌────────▼─────────┐              ┌────────▼──────────┐
                     │ lichess_puzzle   │              │ TournamentRound   │
                     │ (API, read-only) │              │ (DB)              │
                     └──────────────────┘              └────────┬──────────┘
                                                                │
                                                       ┌────────▼──────────┐
                                                       │TournamentPairing  │
                                                       │ (DB)              │
                                                       └───────────────────┘

 ┌──────────────┐       ┌──────────────────────┐
 │  StudyGroup  │◄──────│ StudyGroupMembership │  (many-to-many)
 │  (DB)        │       │ (DB)                 │
 └──────────────┘       └──────────────────────┘
```

**Legend:**
- **(API)** = API-backed model, data fetched from Lichess at runtime
- **(DB)** = Standard database-backed model
- **(DB+API)** = DB model with cross-source FK to an API model
- **cross-source FK** = Foreign key from a DB model to an API model (e.g., `lichess_username` → `lichess_player`)

### 2.2 API-Backed Model Definitions (read-only, from Lichess)

These models have no database table. Data is fetched from the Lichess public API via host data sources.

---

#### lichess_player (API-backed)

```yaml
name: lichess_player

data_source:
  type: host
  provider: "Lichess::PlayerDataSource"

fields:
  id:        { type: string }     # lichess username (primary key)
  username:  { type: string }
  title:     { type: string }     # GM, IM, FM, WGM, etc. or null
  perfs:     { type: json }       # { bullet: { games, rating, rd }, blitz: {...}, ... }
  count:     { type: json }       # { all, rated, draw, loss, win, bookmark, playing }
  createdAt: { type: datetime }   # account creation (ms timestamp)
  seenAt:    { type: datetime }   # last seen online (ms timestamp)
  url:       { type: url }        # https://lichess.org/@/username
  patron:    { type: boolean }    # lichess patron (supporter)
```

**Lichess endpoint:** `GET https://lichess.org/api/user/{username}` (no auth required)

**Sample response:**
```json
{
  "id": "drnykterstein",
  "username": "DrNykterstein",
  "title": "GM",
  "perfs": {
    "bullet": { "games": 9567, "rating": 3276, "rd": 78 },
    "blitz": { "games": 604, "rating": 3131, "rd": 160 },
    "chess960": { "games": 129, "rating": 2541, "rd": 181 }
  },
  "count": { "all": 10432, "rated": 10417, "draw": 833, "loss": 2405, "win": 7194 },
  "url": "https://lichess.org/@/DrNykterstein",
  "createdAt": 1544100290814,
  "seenAt": 1771960526591
}
```

**Features exercised:** API-backed model, host data source, JSON fields (perfs, count), url type, cross-source FK target.

---

#### lichess_game (API-backed)

```yaml
name: lichess_game

data_source:
  type: host
  provider: "Lichess::GameDataSource"

fields:
  id:         { type: string }     # game ID (e.g., "zUxV8GLr")
  rated:      { type: boolean }
  variant:    { type: string }     # standard, chess960, atomic, etc.
  speed:      { type: string }     # bullet, blitz, rapid, classical
  createdAt:  { type: datetime }
  lastMoveAt: { type: datetime }
  status:     { type: string }     # resign, mate, timeout, draw, stalemate, etc.
  players:    { type: json }       # { white: { user, rating, ratingDiff }, black: {...} }
  winner:     { type: string }     # "white", "black", or null (draw)
  moves:      { type: string }     # move sequence in SAN notation
  pgn:        { type: text }       # full PGN with headers
  clock:      { type: json }       # { initial, increment, totalTime }
```

**Lichess endpoint:** `GET https://lichess.org/api/games/user/{username}?max=300&pgnInJson=true`

**Note:** Game lists return NDJSON by default. The host data source handles NDJSON parsing or uses `Accept: application/json` header for JSON arrays (max 300 games).

**Sample response (single game):**
```json
{
  "id": "zUxV8GLr",
  "rated": true,
  "variant": "standard",
  "speed": "bullet",
  "createdAt": 1768818177307,
  "lastMoveAt": 1768818267710,
  "status": "resign",
  "players": {
    "white": {
      "user": { "name": "DrNykterstein", "title": "GM", "id": "drnykterstein" },
      "rating": 3268, "ratingDiff": 8
    },
    "black": {
      "user": { "name": "indianstar", "title": "GM", "id": "indianstar" },
      "rating": 3099, "ratingDiff": -3
    }
  },
  "winner": "white",
  "moves": "d4 Nf6 c4 g6 Nc3 Bg7 e4 O-O Nf3 d6 Be2 Nbd7 O-O e5 d5 a5...",
  "pgn": "[Event \"Rated Bullet game\"]\n[Site \"https://lichess.org/zUxV8GLr\"]\n...\n1. d4 Nf6 2. c4 g6...",
  "clock": { "initial": 60, "increment": 0 }
}
```

**Features exercised:** API-backed model, NDJSON handling in host data source, JSON fields (players, clock), cross-source FK target.

---

#### lichess_puzzle (API-backed)

```yaml
name: lichess_puzzle

data_source:
  type: host
  provider: "Lichess::PuzzleDataSource"

fields:
  id:       { type: string }    # puzzle ID (e.g., "UQGFK")
  rating:   { type: integer }   # puzzle difficulty rating
  plays:    { type: integer }   # number of times played
  solution: { type: json }      # array of UCI moves (e.g., ["g1g7", "h8g7", "h5g5"])
  themes:   { type: json }      # array of themes (e.g., ["middlegame", "attraction", "long"])
  game:     { type: json }      # related game: { id, pgn, clock, players }
```

**Lichess endpoint:** `GET https://lichess.org/api/puzzle/{id}`

**Sample response:**
```json
{
  "id": "UQGFK",
  "rating": 2008,
  "plays": 42979,
  "solution": ["g1g7", "h8g7", "h5g5", "g7h8", "g5f6"],
  "themes": ["middlegame", "attraction", "long"],
  "game": {
    "id": "gKhR1l05",
    "pgn": "e4 c5 Nf3 d6...",
    "clock": "3+2",
    "players": [
      { "name": "luxnov_JC3", "id": "luxnov_jc3", "color": "white", "rating": 1577 },
      { "name": "sandzzz", "id": "sandzzz", "color": "black", "rating": 1524 }
    ]
  }
}
```

**Features exercised:** API-backed model, JSON fields (solution, themes, game), cross-source FK target.

---

### 2.3 DB-Backed Model Definitions

---

#### Member (central entity)

```yaml
options:
  auditing: true
  userstamps: true
  custom_fields: true

fields:
  first_name:       { type: string, null: false, transforms: [strip, titlecase] }
  last_name:        { type: string, null: false, transforms: [strip, titlecase] }
  full_name:        { type: string, computed: "{first_name} {last_name}" }
  email:            { type: email, null: false, unique: true }
  lichess_username: { type: string, null: false, unique: true }  # cross-source FK → lichess_player
  joined_at:        { type: date }
  role:
    type: enum
    values: [admin, coach, member]
    default: member
  bio:              { type: text }
  photo:
    type: attachment
    options: { accept: "image/*", max_size: "5MB", variants: { thumbnail: { resize_to_fill: [80, 80] } } }

associations:
  belongs_to:
    - name: lichess_player
      target_model: lichess_player
      foreign_key: lichess_username   # cross-source FK to API model
  has_many: [training_plans_as_coach, training_plans_as_student, game_annotations, repertoires, tournament_entries, study_group_memberships]

scopes:
  active_coaches: { where: { role: coach } }
  active_members: { where: { role: member } }
```

**Features exercised:** cross-source FK to API model (`lichess_username` → `lichess_player`), computed field (full_name), custom types (email), transforms (titlecase), enum, attachment (photo with variants), auditing, userstamps, custom fields, multiple scopes, multiple has_many associations.

---

#### OpeningLine (tree structure)

```yaml
options:
  tree: true          # Sicilian → 2.Nf3 → Najdorf → 6.Be2 English Attack
  positioning: true   # sibling order within parent

fields:
  name:        { type: string, null: false }   # e.g., "Sicilian Defense"
  eco:         { type: string }                # ECO code (e.g., B20, B90)
  moves:       { type: string }                # Move sequence (e.g., "1.e4 c5 2.Nf3")
  fen:         { type: string }                # FEN position at end of line
  notes:       { type: text }                  # Coach annotations
  engine_eval: { type: string }                # Best evaluation (e.g., "+0.3", "=")
  white_pov:   { type: boolean }               # Perspective (true = white, false = black)

associations:
  belongs_to:
    - name: parent
      target_model: opening_line
      optional: true
  has_many: [children, repertoires]
```

**Features exercised:** tree structure (opening repertoire naturally hierarchical — 1.e4 → Sicilian → Open Sicilian → Najdorf), positioning (sibling order for move priority), self-referential parent, boolean field. Unique demo feature — no other demo showcases tree structures for opening repertoire.

---

#### Repertoire (many-to-many join)

```yaml
fields:
  is_white:  { type: boolean, null: false }   # true for white repertoire, false for black
  rating:    { type: integer }                # Member's rating when line was learned
  notes:     { type: text }                   # Personal notes on this line

associations:
  belongs_to:
    - name: member (required)
    - name: opening_line (required)
```

**Features exercised:** many-to-many join model with extra attributes (rating, notes), boolean field, association with tree model.

---

#### TrainingPlan

```yaml
options:
  positioning: true   # priority order in coach's plan list
  userstamps: true
  auditing: true
  soft_delete: true

fields:
  title:          { type: string, null: false }
  description:    { type: text }
  start_date:     { type: date, null: false }
  end_date:       { type: date }
  status:
    type: enum
    values: [draft, active, completed, archived]
    default: draft
  focus_area:
    type: enum
    values: [openings, tactics, endgames, strategy, speed]
  difficulty:
    type: enum
    values: [beginner, intermediate, advanced, expert]
  duration_weeks: { type: integer }

associations:
  belongs_to:
    - name: coach
      target_model: member
      foreign_key: coach_id
      required: true
    - name: student
      target_model: member
      foreign_key: student_id
      required: true
  has_many: puzzle_assignments

validations:
  - end_date >= start_date (cross-field)
```

**Features exercised:** positioning (reorder plans), userstamps (coach who created), auditing (status changes), soft delete, dual FK to same model (coach + student — demonstrates role-based ownership pattern), multiple enums, cross-field validation, record rules (no edit after completed).

---

#### PuzzleAssignment (cross-source FK to API)

```yaml
options:
  userstamps: true
  auditing: true

fields:
  assigned_at:   { type: datetime }
  due_date:      { type: date }
  status:
    type: enum
    values: [assigned, in_progress, solved, skipped]
    default: assigned
  attempts:      { type: integer, default: 0 }
  rating_delta:  { type: integer }       # Change in puzzle rating after attempt
  time_spent_ms: { type: integer }       # Time spent solving (milliseconds)
  solution:      { type: json }          # Array of moves played by student

associations:
  belongs_to:
    - name: training_plan (required)
    - name: lichess_puzzle
      target_model: lichess_puzzle
      foreign_key: puzzle_id          # cross-source FK to API model
      required: true
```

**Features exercised:** cross-source FK to API model (`puzzle_id` → `lichess_puzzle`), userstamps, auditing, enum with workflow-like states, JSON field (student's solution moves), conditional rendering (solution visible only when solved).

---

#### GameAnnotation (cross-source FK to API)

```yaml
options:
  userstamps: true
  auditing: true

fields:
  annotated_at:     { type: datetime }
  notes:            { type: text }
  analysis:         { type: json }        # Move-by-move analysis: { "10": "Nxd5! exploits pin", ... }
  key_moves:        { type: json }        # UCI moves that changed evaluation
  mistakes:         { type: text }
  improvement_plan: { type: text }

associations:
  belongs_to:
    - name: member (required)
    - name: lichess_game
      target_model: lichess_game
      foreign_key: game_id          # cross-source FK to API model
      required: true
```

**Features exercised:** cross-source FK to API model (`game_id` → `lichess_game`), userstamps, auditing, JSON field (move-by-move analysis), custom renderer (chess_board_preview on the API game's PGN).

---

#### ClubTournament

```yaml
options:
  positioning: true   # display order in tournament list
  userstamps: true
  auditing: true
  soft_delete: true

fields:
  name:               { type: string, null: false }
  status:
    type: enum
    values: [draft, registration, pairing, in_progress, completed]
    default: draft
  start_date:         { type: date, null: false }
  format:
    type: enum
    values: [round_robin, swiss, knockout]
    default: swiss
  time_control:       { type: string }       # e.g., "5+3" (5 min + 3 sec increment)
  num_rounds:         { type: integer }
  current_round:      { type: integer, default: 0 }
  rating_restricted:  { type: boolean, default: false }
  min_rating:         { type: integer }
  max_rating:         { type: integer }
  description:        { type: text }

associations:
  has_many: [tournament_entries, tournament_rounds]

scopes:
  upcoming:   { where_not: { status: completed }, order: { start_date: asc } }
  completed:  { where: { status: completed } }
```

**Features exercised:** positioning, userstamps, auditing, soft delete, multiple enums (status, format), conditional fields (min_rating/max_rating visible when rating_restricted = true), record rules (no edit after completed), custom actions (open registration, generate pairings, complete), scopes.

---

#### TournamentEntry

```yaml
fields:
  entry_number:       { type: integer }         # board number or seed
  initial_rating:     { type: integer }         # rating at tournament start
  final_rating:       { type: integer }         # after tournament rating change
  score:              { type: decimal, precision: 4, scale: 1 }  # 0.0–6.0 for draws
  performance_rating: { type: integer }

associations:
  belongs_to:
    - name: member (required)
    - name: club_tournament (required)
```

**Features exercised:** decimal field (half-point scores for draws), multiple integer fields, join model with extra attributes.

---

#### TournamentRound

```yaml
options:
  userstamps: true
  auditing: true

fields:
  number:     { type: integer, null: false }
  status:
    type: enum
    values: [draft, pairings_done, in_progress, completed]
    default: draft
  start_date: { type: datetime }
  end_date:   { type: datetime }

associations:
  belongs_to: club_tournament (required)
  has_many: tournament_pairings
```

**Features exercised:** userstamps, auditing, enum status, datetime fields, nested under tournament.

---

#### TournamentPairing

```yaml
options:
  auditing: true

fields:
  pairing_number: { type: integer }
  board_number:   { type: integer }
  result:
    type: enum
    values: [pending, white_wins, black_wins, draw, unplayed]
    default: pending
  pgn:            { type: text }    # PGN of the game (optional)

associations:
  belongs_to:
    - name: tournament_round (required)
    - name: white_player
      target_model: member
      foreign_key: white_player_id
      required: true
    - name: black_player
      target_model: member
      foreign_key: black_player_id
      required: true
```

**Features exercised:** auditing (pairing changes logged), dual FK to same model (white_player + black_player), enum result, custom renderer (game_result with color-coded badges).

---

#### StudyGroup

```yaml
fields:
  name:        { type: string, null: false }
  description: { type: text }
  focus:
    type: enum
    values: [openings, tactics, endgames, strategy, speed]
  level:
    type: enum
    values: [beginner, intermediate, advanced]

associations:
  has_many: study_group_memberships
```

**Features exercised:** enum fields (focus, level), study group concept for cooperative learning.

---

#### StudyGroupMembership (many-to-many join)

```yaml
options:
  userstamps: true

fields:
  role:
    type: enum
    values: [member, moderator]
    default: member
  joined_at: { type: date, null: false }

associations:
  belongs_to:
    - name: member (required)
    - name: study_group (required)
```

**Features exercised:** many-to-many join with extra attributes (role, joined_at), userstamps.

---

### 2.4 Model Count and Feature Coverage Matrix

| # | Model | API | X-Source FK | Tree | SoftDel | Audit | CustFld | Usrstmp | Position | Attach | JSON | Enums |
|---|-------|-----|-------------|------|---------|-------|---------|---------|----------|--------|------|-------|
| 1 | lichess_player | X | | | | | | | | | X(2) | 0 |
| 2 | lichess_game | X | | | | | | | | | X(2) | 0 |
| 3 | lichess_puzzle | X | | | | | | | | | X(3) | 0 |
| 4 | Member | | X | | | X | X | X | | X | | 1 |
| 5 | OpeningLine | | | X | | | | | X | | | 0 |
| 6 | Repertoire | | | | | | | | | | | 0 |
| 7 | TrainingPlan | | | | X | X | | X | X | | | 3 |
| 8 | PuzzleAssignment | | X | | | X | | X | | | X | 1 |
| 9 | GameAnnotation | | X | | | X | | X | | | X(2) | 0 |
| 10 | ClubTournament | | | | X | X | | X | X | | | 2 |
| 11 | TournamentEntry | | | | | | | | | | | 0 |
| 12 | TournamentRound | | | | | X | | X | | | | 1 |
| 13 | TournamentPairing | | | | | X | | | | | | 1 |
| 14 | StudyGroup | | | | | | | | | | | 2 |
| 15 | StudyGroupMembership | | | | | | | X | | | | 1 |
| **Total** | | **3** | **3** | **1** | **2** | **8** | **1** | **8** | **3** | **1** | **10** | **12** |

---

## 3. Host Data Sources (Lichess API Integration)

This is the defining feature of the chess demo — the first example app to use host data sources for API-backed models.

### 3.1 API Overview

```
# All endpoints are public — no API key required!

GET https://lichess.org/api/user/{username}
  → Single player profile (ratings, game counts, metadata)

GET https://lichess.org/api/user/{username}/rating-history
  → Historical rating data (for ELO trend graphs)

GET https://lichess.org/api/games/user/{username}?max=300&pgnInJson=true
  → List of player's games (JSON array with pgnInJson=true, else NDJSON stream)

GET https://lichess.org/api/puzzle/{id}
  → Single puzzle with solution, themes, related game

GET https://lichess.org/api/puzzle/daily
  → Daily featured puzzle
```

### 3.2 Host Data Source Classes

Each API-backed model has a corresponding host data source class in the host app:

```ruby
# app/lcp_services/data_providers/lichess/player_data_source.rb
module Lichess
  class PlayerDataSource
    def find(username)
      response = Faraday.get("https://lichess.org/api/user/#{username}")
      map_player(JSON.parse(response.body))
    end

    def find_batch(usernames)
      # POST https://lichess.org/api/users (accepts comma-separated usernames)
      response = Faraday.post("https://lichess.org/api/users", usernames.join(","))
      JSON.parse(response.body).map { |data| map_player(data) }
    end

    private

    def map_player(data)
      {
        id: data["id"],
        username: data["username"],
        title: data["title"],
        perfs: data["perfs"],
        count: data["count"],
        createdAt: Time.at(data["createdAt"] / 1000),
        seenAt: Time.at(data["seenAt"] / 1000),
        url: data["url"],
        patron: data.fetch("patron", false)
      }
    end
  end
end
```

```ruby
# app/lcp_services/data_providers/lichess/game_data_source.rb
module Lichess
  class GameDataSource
    def find(game_id)
      # Single game export
      response = Faraday.get("https://lichess.org/game/export/#{game_id}",
                             { pgnInJson: true },
                             { "Accept" => "application/json" })
      map_game(JSON.parse(response.body))
    end

    def find_for_user(username, max: 20)
      # Player's games (JSON mode, limited)
      response = Faraday.get("https://lichess.org/api/games/user/#{username}",
                             { max: max, pgnInJson: true },
                             { "Accept" => "application/json" })
      JSON.parse(response.body).map { |data| map_game(data) }
    end

    private

    def map_game(data)
      {
        id: data["id"],
        rated: data["rated"],
        variant: data["variant"],
        speed: data["speed"],
        createdAt: Time.at(data["createdAt"] / 1000),
        lastMoveAt: Time.at(data["lastMoveAt"] / 1000),
        status: data["status"],
        players: data["players"],
        winner: data["winner"],
        moves: data["moves"],
        pgn: data["pgn"],
        clock: data["clock"]
      }
    end
  end
end
```

```ruby
# app/lcp_services/data_providers/lichess/puzzle_data_source.rb
module Lichess
  class PuzzleDataSource
    def find(puzzle_id)
      response = Faraday.get("https://lichess.org/api/puzzle/#{puzzle_id}")
      data = JSON.parse(response.body)
      {
        id: data.dig("puzzle", "id"),
        rating: data.dig("puzzle", "rating"),
        plays: data.dig("puzzle", "plays"),
        solution: data.dig("puzzle", "solution"),
        themes: data.dig("puzzle", "themes"),
        game: data["game"]
      }
    end
  end
end
```

### 3.3 Field Mapping Summary

```
Lichess JSON                      → LCP field
─────────────────────────────────────────────
Player:
  id                              → id (primary key)
  username                        → username
  title                           → title
  perfs (nested object)           → perfs (JSON blob — bullet.rating, blitz.rating, etc.)
  count (nested object)           → count (JSON blob — all, win, loss, draw)
  createdAt (ms timestamp)        → createdAt (converted to DateTime)
  seenAt (ms timestamp)           → seenAt (converted to DateTime)
  url                             → url
  patron                          → patron

Game:
  id                              → id (primary key)
  rated                           → rated
  variant                         → variant
  speed                           → speed
  createdAt (ms timestamp)        → createdAt
  lastMoveAt (ms timestamp)       → lastMoveAt
  status                          → status
  players (nested white/black)    → players (JSON blob)
  winner                          → winner
  moves (SAN sequence)            → moves
  pgn (full PGN string)           → pgn
  clock (nested initial/inc)      → clock (JSON blob)

Puzzle:
  puzzle.id                       → id (primary key)
  puzzle.rating                   → rating
  puzzle.plays                    → plays
  puzzle.solution (UCI array)     → solution (JSON array)
  puzzle.themes (string array)    → themes (JSON array)
  game (nested object)            → game (JSON blob)
```

### 3.4 Cross-Source Association Flow

```
1. Index page loads members
2. Presenter includes lichess_player.perfs.bullet.rating column
3. IncludesResolver detects cross-source association
4. Batch fetch: PlayerDataSource.find_batch(all lichess_usernames)
5. Results attached to member records for rendering
6. If API unavailable → graceful degradation (empty columns, no crash)
```

---

## 4. Host App Board Viewer

The interactive chess board viewer is a **host app custom page** — not generated by LCP. It demonstrates how the platform integrates with host application custom code.

### 4.1 Architecture

```
LCP Platform (generated pages)
  ├── Show page for game_annotation
  │   └── Displays notes, cross-source game reference
  │   └── Link: "View full game →" → /board/{game_id}
  │
  ├── Show page for member
  │   └── View slot widget: "Latest games" miniature board previews
  │   └── Each game links to → /board/{game_id}
  │
  └── Custom renderer: chess_board_preview
      └── FEN/PGN → static board image (current position)
      └── Inline link to full viewer


Host App (custom Rails pages)
  ├── Route: GET /board/:game_id
  │   └── Standalone page (outside LCP engine mount)
  │   └── Reads from LCP model registry
  │
  ├── Controller: BoardController
  │   ├── Fetches lichess_game via LcpRuby.registry.model_for("lichess_game")
  │   ├── Loads game_annotations via LcpRuby.registry.model_for("game_annotation")
  │   └── Renders full interactive board
  │
  ├── View: board/show.html.erb
  │   ├── Interactive chessboard (chessboard.js + chess.js)
  │   ├── Navigation: |« start | ← prev | next → | end »|
  │   ├── PGN panel (scrollable, current move highlighted)
  │   ├── Annotations panel (from game_annotation DB records, if any)
  │   └── Game metadata (players, ratings, date, result, time control)
  │
  └── Assets:
      ├── chessboard.js (board UI — drag/drop pieces, SVG rendering)
      ├── chess.js (game logic — move validation, FEN generation)
      └── custom CSS for board + panel layout
```

### 4.2 Controller

```ruby
# app/controllers/board_controller.rb
class BoardController < ApplicationController
  def show
    game_model = LcpRuby.registry.model_for("lichess_game")
    annotation_model = LcpRuby.registry.model_for("game_annotation")

    @game = game_model.find(params[:game_id])
    @annotations = annotation_model.where(game_id: params[:game_id])
  end
end
```

### 4.3 Custom Renderers

#### chess_board_preview

Used on LCP show pages (game_annotation, member) to render a static board preview from a FEN or PGN string.

```ruby
# app/renderers/chess_board_preview_renderer.rb
class ChessBoardPreviewRenderer < LcpRuby::Display::BaseRenderer
  # Input: PGN or FEN string
  # Output: <div class="board-preview"> with inline SVG board at final position
  # Link: <a href="/board/{game_id}">View full game</a>
end
```

#### game_result

Displays game result with color-coded winner badge.

```ruby
# app/renderers/game_result_renderer.rb
class GameResultRenderer < LcpRuby::Display::BaseRenderer
  # Input: "white", "black", or nil
  # Output: badge — "1-0" (green), "0-1" (red), "½-½" (gray)
end
```

#### moves_list

Renders a list of chess moves (UCI or SAN) as formatted, clickable move badges.

```ruby
# app/renderers/moves_list_renderer.rb
class MovesListRenderer < LcpRuby::Display::BaseRenderer
  # Input: array of UCI moves (["g1g7", "h8g7", "h5g5"])
  # Output: formatted move badges: 1. Rxg7+ Kxg7 2. Qg5+ ...
end
```

### 4.4 View Slot: Latest Games Widget

Registered as a view slot on the member show page:

```ruby
# app/view_slots/latest_games_widget.rb
LcpRuby::ViewSlots::Registry.register(:show, :after_sections) do |context|
  if context.presenter.model_name == "member"
    LcpRuby::ViewSlots::SlotComponent.new(
      name: "latest_games",
      partial: "shared/latest_games_widget",
      position: 10
    )
  end
end
```

```erb
<%# app/views/shared/_latest_games_widget.html.erb %>
<div class="latest-games-widget">
  <h3><%= t("chess.latest_games") %></h3>
  <% @latest_games.each do |game| %>
    <div class="game-mini">
      <span class="players">
        <%= game[:players]["white"]["user"]["name"] %> (<%= game[:players]["white"]["rating"] %>)
        vs
        <%= game[:players]["black"]["user"]["name"] %> (<%= game[:players]["black"]["rating"] %>)
      </span>
      <span class="result <%= game[:winner] %>"><%= format_result(game[:winner]) %></span>
      <a href="/board/<%= game[:id] %>"><%= t("chess.view_game") %></a>
    </div>
  <% end %>
</div>
```

---

## 5. Platform Feature Coverage

### 5.1 Features demonstrated (with specific model examples)

| Platform Feature | Models/Scenarios | Notes |
|---|---|---|
| **API-backed models** | lichess_player, lichess_game, lichess_puzzle | 3 read-only models fetched from Lichess API at runtime — **first demo to use this** |
| **Cross-source associations** | Member → lichess_player, PuzzleAssignment → lichess_puzzle, GameAnnotation → lichess_game | DB records referencing API data via string FKs — **unique to this demo** |
| **Cross-source batch preloading** | Member index (all lichess_player profiles in 1 API call) | Efficient index rendering for cross-source columns |
| **Host data sources** | Lichess::PlayerDataSource, GameDataSource, PuzzleDataSource | Custom Ruby classes that fetch and map external API data |
| **Tree structures** | OpeningLine (1.e4 → Sicilian → Najdorf → English Attack) | Opening repertoire as a natural tree hierarchy |
| **Tree index view** | OpeningLine repertoire browser | Expand/collapse, guide lines, reparenting |
| **Soft delete** | TrainingPlan, ClubTournament | 2 models with archive/restore |
| **Auditing** | Member, TrainingPlan, PuzzleAssignment, GameAnnotation, ClubTournament, TournamentRound, TournamentPairing | 8 models with full change tracking |
| **Custom fields** | Member | Runtime-extensible member attributes (e.g., FIDE ID, preferred time control) |
| **Userstamps** | Member, TrainingPlan, PuzzleAssignment, GameAnnotation, ClubTournament, TournamentRound, StudyGroupMembership | 8 models |
| **Positioning** | OpeningLine (sibling priority), TrainingPlan (plan order), ClubTournament (display order) | 3 models with drag-and-drop |
| **Attachments** | Member (photo with variants) | Single attachment with thumbnail variant |
| **JSON fields** | lichess_player (perfs, count), lichess_game (players, clock), lichess_puzzle (solution, themes, game), PuzzleAssignment (solution), GameAnnotation (analysis, key_moves) | 10 JSON fields across API and DB models |
| **Computed fields** | Member (full_name template) | Template-based computed field |
| **Custom types** | Member (email) | email type with validation and transform |
| **Transforms** | Member (titlecase names) | strip + titlecase on first_name, last_name |
| **Conditional rendering** | PuzzleAssignment (solution visible when solved), ClubTournament (rating fields when restricted), TrainingPlan (end_date validation) | visible_when on fields and sections |
| **Record rules** | TrainingPlan (no edit after completed), ClubTournament (no edit after completed) | Conditional CRUD denial based on status |
| **Custom actions** | ClubTournament (open_registration, generate_pairings, complete), TrainingPlan (activate, complete, archive) | Multi-step status progression |
| **Enums** | TrainingPlan (status, focus_area, difficulty), ClubTournament (status, format), PuzzleAssignment (status), TournamentPairing (result), etc. | 12 enum fields across models |
| **Multiple FKs to same model** | TrainingPlan (coach_id + student_id → Member), TournamentPairing (white_player_id + black_player_id → Member) | Dual FK pattern — coach/student, white/black |
| **Scopes** | Member (active_coaches, active_members), ClubTournament (upcoming, completed) | Model-level query scopes |
| **Custom renderers** | chess_board_preview, game_result, moves_list | 3 host app custom renderers |
| **View slots** | Latest games widget on member show page | Host app view slot integration |
| **Host app custom pages** | Board viewer (/board/:game_id) — interactive chessboard with annotations | Platform + host app integration boundary |
| **Dot-path fields** | Member show: lichess_player.perfs.bullet.rating, lichess_player.count.win | Cross-source dot-path resolution |
| **Cross-field validation** | TrainingPlan (end_date >= start_date) | Date range validation |
| **Decimal fields** | TournamentEntry (score with 0.5 precision for draws) | Half-point scoring |

### 5.2 Features NOT covered (with rationale)

| Feature | Reason |
|---|---|
| Workflows (state machine) | Platform feature not yet implemented. Simulated with enum + record rules + custom actions |
| Rich text | Not natural for chess domain — notes are plain text |
| Groups (platform subsystem) | StudyGroup is a domain model, not the platform's group_source: :model subsystem. Could be added if needed |
| Permission source: model | Fixed 3 roles sufficient for demo |
| Role source: model | Using enum role on member |
| Virtual models | No dashboard aggregate needed — API data provides real-time stats |
| Color type | No natural use case in chess domain |

---

## 6. Roles & Permissions Design

### 6.1 Roles

| Role | Description | Typical user |
|---|---|---|
| **admin** | Full system access. Manages all models, configuration, and API settings | Club administrator |
| **coach** | Creates training plans, assigns puzzles, annotates games, manages tournaments, views all members | Chess coach / instructor |
| **member** | Self-service — views own profile, completes assigned puzzles, creates own game annotations, browses repertoire | Club member / student |

### 6.2 Permission Matrix

| Model | admin | coach | member |
|---|---|---|---|
| **Member** | full CRUD, all fields | read all, create, update limited fields | read self only |
| **lichess_player** | read | read | read (via own member) |
| **lichess_game** | read | read | read |
| **lichess_puzzle** | read | read | read |
| **OpeningLine** | full CRUD | full CRUD | read only |
| **Repertoire** | full CRUD | read all, CRUD own | read own, CRUD own |
| **TrainingPlan** | full CRUD | CRUD own (as coach) | read own (as student) |
| **PuzzleAssignment** | full CRUD | CRUD (within own plans) | read + update status (own) |
| **GameAnnotation** | full CRUD | read all | CRUD own |
| **ClubTournament** | full CRUD | create, read, update | read only |
| **TournamentRound** | full CRUD | read, update | read only |
| **TournamentPairing** | full CRUD | read, update result | read only |
| **TournamentEntry** | full CRUD | CRUD | CRUD own |
| **StudyGroup** | full CRUD | full CRUD | read, join/leave |
| **StudyGroupMembership** | full CRUD | full CRUD | CRUD own |

### 6.3 Permission Definition

```yaml
# config/lcp_ruby/permissions/chess.yml

roles:
  admin:
    crud: [all]
    presenters: [all]
    fields: { readable: all, writable: all }

  coach:
    crud:
      member: [read, create]
      opening_line: [read, create, update, delete]
      repertoire: [read]
      training_plan: [create, read, update, delete]
      puzzle_assignment: [create, read, update]
      game_annotation: [read]
      club_tournament: [create, read, update]
      tournament_round: [read, update]
      tournament_pairing: [read, update]
      tournament_entry: [create, read, update, delete]
      study_group: [create, read, update, delete]
      study_group_membership: [create, read, update, delete]

    fields:
      member: { readable: all, writable: [email, role] }
      training_plan: { readable: all, writable: all }
      puzzle_assignment: { readable: all, writable: [status, due_date, assigned_at] }
      tournament_pairing: { readable: all, writable: [result, pgn] }

    presenters:
      - members
      - member_show
      - opening_repertoire
      - training_plans
      - training_plan_show
      - puzzle_assignments
      - game_annotations
      - club_tournaments
      - tournament_standings

    scope: all

    record_rules:
      - action: [update, delete]
        model: training_plan
        condition:
          field: status
          operator: eq
          value: completed
        deny: true
        message_key: lcp_ruby.record_rules.cannot_edit_completed_plan

  member:
    crud:
      member: [read]
      opening_line: [read]
      repertoire: [read, create, update]
      training_plan: [read]
      puzzle_assignment: [read, update]
      game_annotation: [read, create, update]
      club_tournament: [read]
      tournament_round: [read]
      tournament_pairing: [read]
      tournament_entry: [read, create]
      study_group: [read]
      study_group_membership: [read, create, delete]

    fields:
      member: { readable: [first_name, last_name, email, lichess_username, role, bio], writable: [] }
      puzzle_assignment: { readable: all, writable: [status, attempts, time_spent_ms, solution] }
      game_annotation: { readable: all, writable: [notes, analysis, key_moves, mistakes, improvement_plan] }

    presenters:
      - members
      - member_show
      - my_assignments
      - opening_repertoire
      - game_annotations
      - club_tournaments

    scope:
      member: { type: field_match, field: id, user_field: member_id }
      training_plan: { type: field_match, field: student_id, user_field: member_id }
      puzzle_assignment: { through: training_plan }
      game_annotation: { type: field_match, field: member_id, user_field: member_id }
      repertoire: { type: field_match, field: member_id, user_field: member_id }

    record_rules:
      - action: [update, delete]
        model: game_annotation
        condition:
          field: member_id
          operator: ne
          value: "{{ current_user.member_id }}"
        deny: true
        message_key: lcp_ruby.record_rules.own_annotations_only
```

---

## 7. Presenter Highlights

### 7.1 Members Index

```yaml
slug: members
model: member
type: index

columns:
  - field: photo
    renderer: image_thumbnail
  - field: full_name
    renderer: link
  - field: role
    renderer: badge
  - field: lichess_username
  - field: lichess_player.title
    renderer: badge           # GM, IM, FM badges
  - field: lichess_player.perfs.bullet.rating
    renderer: integer
  - field: lichess_player.perfs.blitz.rating
    renderer: integer
  - field: lichess_player.count.win
    renderer: integer
  - field: joined_at
    renderer: date

search:
  type: quick
  fields: [first_name, last_name, lichess_username, email]

filters:
  - name: all
  - name: coaches
    scope: active_coaches
  - name: members
    scope: active_members
```

**Notable:** Cross-source columns (lichess_player.*) with batch preloading. Multiple nested JSON field paths (perfs.bullet.rating, perfs.blitz.rating, count.win) from a single API model.

### 7.2 Member Show

```yaml
slug: member_show
model: member
type: show

sections:
  - title_key: lcp_ruby.presenters.member_show.sections.personal_info
    fields: [photo, first_name, last_name, email, lichess_username, joined_at, role, bio]

  - title_key: lcp_ruby.presenters.member_show.sections.lichess_stats
    fields:
      - field: lichess_player.username
        renderer: link
      - field: lichess_player.title
        renderer: badge
      - field: lichess_player.perfs
        renderer: json_table       # formatted table of all ratings
      - field: lichess_player.count
        renderer: json_display     # win/draw/loss stats

  - title_key: lcp_ruby.presenters.member_show.sections.recent_games
    fields:
      - field: game_annotations
        renderer: association_list
        limit: 5

  - title_key: lcp_ruby.presenters.member_show.sections.training
    fields:
      - field: training_plans_as_student
        renderer: association_list
```

**Notable:** Sections mixing DB fields (personal info) and API fields (Lichess stats). Latest games widget rendered via view slot. Graceful degradation if Lichess API unavailable.

### 7.3 Opening Repertoire (Tree View)

```yaml
slug: opening_repertoire
model: opening_line
type: index
view_type: tree

tree:
  parent_field: parent_id
  label_field: name
  allow_reparenting: true

columns:
  - field: name
  - field: eco
    renderer: badge
  - field: moves
    renderer: text_truncate
  - field: white_pov
    renderer: boolean
  - field: engine_eval
  - field: notes
    renderer: text_truncate

actions:
  - type: built_in
    action: create
  - type: built_in
    action: edit
  - type: custom
    name: add_child_line
```

**Notable:** Tree visualization with drag-and-drop reparenting. Opening lines are naturally hierarchical: Sicilian (root) → 2.Nf3 Open Sicilian → 3.d4 cxd4 4.Nxd4 → Najdorf 5...a6 → English Attack 6.Be2.

### 7.4 Training Plan Show (with nested assignments)

```yaml
slug: training_plan_show
model: training_plan
type: show

sections:
  - title_key: lcp_ruby.presenters.training_plan_show.sections.basics
    fields: [title, description, status, focus_area, difficulty, start_date, end_date, duration_weeks]

  - title_key: lcp_ruby.presenters.training_plan_show.sections.participants
    fields:
      - field: coach.full_name
        renderer: link
      - field: student.full_name
        renderer: link

  - title_key: lcp_ruby.presenters.training_plan_show.sections.puzzle_assignments
    fields:
      - field: puzzle_assignments
        renderer: association_list
        columns: [puzzle_id, lichess_puzzle.rating, status, due_date, attempts, time_spent_ms]

  - title_key: lcp_ruby.presenters.training_plan_show.sections.audit_history
    type: audit_history
```

### 7.5 Puzzle Assignment Show (cross-source data)

```yaml
slug: puzzle_assignment_show
model: puzzle_assignment
type: show

sections:
  - title_key: lcp_ruby.presenters.puzzle_assignment_show.sections.assignment_details
    fields: [assigned_at, due_date, status, attempts, time_spent_ms]

  - title_key: lcp_ruby.presenters.puzzle_assignment_show.sections.puzzle_details
    fields:
      - field: lichess_puzzle.id
      - field: lichess_puzzle.rating
        renderer: integer
      - field: lichess_puzzle.plays
        renderer: integer
      - field: lichess_puzzle.themes
        renderer: badge_list
      - field: lichess_puzzle.solution
        renderer: moves_list

  - title_key: lcp_ruby.presenters.puzzle_assignment_show.sections.student_solution
    visible_when:
      field: status
      operator: eq
      value: solved
    fields:
      - field: solution
        renderer: moves_list
      - field: rating_delta
        renderer: integer
```

**Notable:** DB assignment details alongside API puzzle details in separate sections. Solution section conditionally visible only when puzzle is solved.

### 7.6 Game Annotation Show (cross-source + board viewer)

```yaml
slug: game_annotation_show
model: game_annotation
type: show

sections:
  - title_key: lcp_ruby.presenters.game_annotation_show.sections.game_info
    fields:
      - field: lichess_game.pgn
        renderer: chess_board_preview     # custom renderer → inline board + link to /board/:id
      - field: lichess_game.players
        renderer: json_display
      - field: lichess_game.winner
        renderer: game_result
      - field: lichess_game.speed
        renderer: badge
      - field: lichess_game.createdAt
        renderer: datetime

  - title_key: lcp_ruby.presenters.game_annotation_show.sections.analysis
    fields: [annotated_at, notes, mistakes, improvement_plan]

  - title_key: lcp_ruby.presenters.game_annotation_show.sections.detailed_analysis
    fields:
      - field: analysis
        renderer: json_table
      - field: key_moves
        renderer: moves_list
```

**Notable:** Cross-source game data rendered with chess_board_preview (inline board image linking to interactive viewer). DB annotations alongside API game data.

### 7.7 Club Tournament Index

```yaml
slug: club_tournaments
model: club_tournament
type: index

columns:
  - field: name
    renderer: link
  - field: status
    renderer: badge
  - field: format
    renderer: badge
  - field: time_control
  - field: start_date
    renderer: date
  - field: num_rounds
  - field: current_round

filters:
  - name: all
  - name: upcoming
    scope: upcoming
  - name: completed
    scope: completed

actions:
  - type: built_in
    action: create
  - type: custom
    name: open_registration
    visible_when: { field: status, operator: eq, value: draft }
  - type: custom
    name: generate_pairings
    visible_when: { field: status, operator: eq, value: registration }
```

---

## 8. Menu Structure

```yaml
menu:
  sidebar_menu:
    - label_key: lcp_ruby.menu.dashboard
      icon: home
      path: /dashboard
      roles: [admin, coach, member]

    - label_key: lcp_ruby.menu.members
      icon: users
      lcp_slug: members
      roles: [admin, coach]
      badge:
        provider: member_count
        renderer: count_badge

    - label_key: lcp_ruby.menu.training
      icon: book-open
      roles: [admin, coach, member]
      children:
        - label_key: lcp_ruby.menu.my_assignments
          lcp_slug: my_assignments
          roles: [member]
        - label_key: lcp_ruby.menu.training_plans
          lcp_slug: training_plans
          roles: [coach, admin]
        - separator: true
        - label_key: lcp_ruby.menu.puzzle_bank
          lcp_slug: lichess_puzzles
          roles: [coach, admin]

    - label_key: lcp_ruby.menu.repertoire
      icon: git-branch
      lcp_slug: opening_repertoire
      roles: [admin, coach, member]

    - label_key: lcp_ruby.menu.tournaments
      icon: trophy
      roles: [admin, coach, member]
      children:
        - label_key: lcp_ruby.menu.club_tournaments
          lcp_slug: club_tournaments
          roles: [admin, coach]
        - label_key: lcp_ruby.menu.my_tournaments
          lcp_slug: my_tournaments
          roles: [member]
        - separator: true
        - label_key: lcp_ruby.menu.standings
          path: /tournaments/standings
          roles: [admin, coach, member]

    - label_key: lcp_ruby.menu.games
      icon: play-circle
      roles: [admin, coach, member]
      children:
        - label_key: lcp_ruby.menu.game_annotations
          lcp_slug: game_annotations
          roles: [admin, coach, member]
        - label_key: lcp_ruby.menu.browse_games
          lcp_slug: lichess_games
          roles: [admin, coach]

    - label_key: lcp_ruby.menu.study_groups
      icon: users
      lcp_slug: study_groups
      roles: [admin, coach, member]

    - label_key: lcp_ruby.menu.lichess
      icon: external-link
      roles: [admin, coach]
      children:
        - label_key: lcp_ruby.menu.player_profiles
          lcp_slug: lichess_players
        - label_key: lcp_ruby.menu.puzzle_explorer
          lcp_slug: lichess_puzzles
        - label_key: lcp_ruby.menu.game_explorer
          lcp_slug: lichess_games

    - label_key: lcp_ruby.menu.settings
      icon: settings
      path: /settings
      roles: [admin]
```

---

## 9. Custom Services

| Service Type | Name | Purpose |
|---|---|---|
| **Host Data Source** | `Lichess::PlayerDataSource` | Fetches player profiles from Lichess API (single + batch) |
| **Host Data Source** | `Lichess::GameDataSource` | Fetches games from Lichess API (single + by user) |
| **Host Data Source** | `Lichess::PuzzleDataSource` | Fetches puzzles from Lichess API |
| **Custom Renderer** | `chess_board_preview` | Renders FEN/PGN as inline board preview with link to viewer |
| **Custom Renderer** | `game_result` | Renders win/loss/draw as color-coded badge (1-0, 0-1, 1/2-1/2) |
| **Custom Renderer** | `moves_list` | Renders UCI/SAN move arrays as formatted move badges |
| **Custom Renderer** | `badge_list` | Renders string arrays as colored badges (puzzle themes) |
| **Custom Action** | `open_registration` | ClubTournament: draft → registration |
| **Custom Action** | `generate_pairings` | ClubTournament: registration → pairing (creates TournamentRound + TournamentPairing records) |
| **Custom Action** | `complete_tournament` | ClubTournament: in_progress → completed (calculates final scores) |
| **Custom Action** | `activate_plan` | TrainingPlan: draft → active |
| **Custom Action** | `complete_plan` | TrainingPlan: active → completed |
| **Data Provider** | `member_count` | Total member count (for menu badge) |
| **Event Handler** | `on_puzzle_solved` | Updates PuzzleAssignment stats when marked solved |
| **Event Handler** | `on_tournament_complete` | Calculates TournamentEntry scores and performance ratings |
| **View Slot** | `latest_games_widget` | Member show page: displays latest Lichess games |

---

## 10. Seed Data Plan

Target: **~15 members** with real Lichess usernames for credible demo data. Small scale focused on demonstrating cross-source features.

### 10.1 Members

```ruby
# db/seeds.rb

# Admin
admin = Member.create!(
  first_name: "Alice", last_name: "Maestro",
  email: "alice@chesscclub.local",
  lichess_username: "DrNykterstein",    # Magnus Carlsen's Lichess account
  role: "admin", joined_at: 2.years.ago
)

# Coaches
coach_bob = Member.create!(
  first_name: "Bob", last_name: "Fischer",
  email: "bob@chessclub.local",
  lichess_username: "Captain_Flint",     # Strong amateur
  role: "coach", joined_at: 1.year.ago
)

coach_carol = Member.create!(
  first_name: "Carol", last_name: "Kasparov",
  email: "carol@chessclub.local",
  lichess_username: "penguingim1",       # GM Andrew Tang
  role: "coach", joined_at: 10.months.ago
)

# Members (students)
students = [
  { first_name: "David",   last_name: "Petrov",    username: "indianstar",   joined: 8.months.ago },
  { first_name: "Eva",     last_name: "Lopez",     username: "Night-King96", joined: 6.months.ago },
  { first_name: "Frank",   last_name: "Marshall",  username: "Fins",         joined: 5.months.ago },
  { first_name: "Grace",   last_name: "Caro",      username: "German11",     joined: 4.months.ago },
  { first_name: "Henry",   last_name: "Nimzo",     username: "lance5500",    joined: 3.months.ago },
].map do |s|
  Member.create!(
    first_name: s[:first_name], last_name: s[:last_name],
    email: "#{s[:first_name].downcase}@chessclub.local",
    lichess_username: s[:username],
    role: "member", joined_at: s[:joined]
  )
end
```

### 10.2 Opening Repertoire Tree

```ruby
# Sicilian Defense tree
sicilian = OpeningLine.create!(
  name: "Sicilian Defense", eco: "B20",
  moves: "1.e4 c5",
  fen: "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2",
  white_pov: true,
  notes: "Most popular defense to 1.e4 — leads to sharp, asymmetrical positions"
)

open_sicilian = OpeningLine.create!(
  name: "Open Sicilian (2.Nf3)", eco: "B27",
  moves: "1.e4 c5 2.Nf3",
  parent: sicilian, white_pov: true,
  notes: "Main line — almost always followed by 3.d4"
)

najdorf = OpeningLine.create!(
  name: "Najdorf Variation", eco: "B90",
  moves: "1.e4 c5 2.Nf3 d6 3.d4 cxd4 4.Nxd4 Nf6 5.Nc3 a6",
  parent: open_sicilian, white_pov: true,
  notes: "Bobby Fischer's weapon of choice. Flexible, rich in theory."
)

english_attack = OpeningLine.create!(
  name: "English Attack (6.Be3)", eco: "B90",
  moves: "1.e4 c5 2.Nf3 d6 3.d4 cxd4 4.Nxd4 Nf6 5.Nc3 a6 6.Be3",
  parent: najdorf, white_pov: true,
  notes: "Aggressive setup — White aims for f3, Qd2, O-O-O, g4"
)

dragon = OpeningLine.create!(
  name: "Dragon Variation", eco: "B70",
  moves: "1.e4 c5 2.Nf3 d6 3.d4 cxd4 4.Nxd4 Nf6 5.Nc3 g6",
  parent: open_sicilian, white_pov: true,
  notes: "Sharp and tactical — Black fianchettoes the dark-square bishop"
)

# Italian Game tree
italian = OpeningLine.create!(
  name: "Italian Game", eco: "C50",
  moves: "1.e4 e5 2.Nf3 Nc6 3.Bc4",
  white_pov: true,
  notes: "Classical development — targets f7"
)

giuoco_piano = OpeningLine.create!(
  name: "Giuoco Piano", eco: "C53",
  moves: "1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5",
  parent: italian, white_pov: true,
  notes: "Quiet Italian — both sides develop harmoniously"
)

# Repertoire assignments
Repertoire.create!(member: coach_bob, opening_line: sicilian, is_white: true, rating: 2200)
Repertoire.create!(member: students[0], opening_line: najdorf, is_white: false, rating: 1800)
Repertoire.create!(member: students[1], opening_line: dragon, is_white: false, rating: 1600)
Repertoire.create!(member: students[2], opening_line: italian, is_white: true, rating: 1900)
```

### 10.3 Training Plans and Assignments

```ruby
plan = TrainingPlan.create!(
  title: "Sicilian Mastery — 8 Weeks",
  description: "Deep dive into Sicilian openings with tactical puzzles from master games",
  coach: coach_bob, student: students[0],
  start_date: Date.today, end_date: Date.today + 8.weeks,
  status: "active", focus_area: "openings",
  difficulty: "intermediate", duration_weeks: 8
)

# Puzzle assignments (referencing real Lichess puzzle IDs)
puzzle_ids = %w[UQGFK nGG3B rNkLm YvTGZ aBcDe]
puzzle_ids.each_with_index do |pid, i|
  PuzzleAssignment.create!(
    training_plan: plan, puzzle_id: pid,
    assigned_at: Time.current,
    due_date: Date.today + (i + 1).weeks,
    status: i < 2 ? "solved" : "assigned",
    attempts: i < 2 ? rand(1..3) : 0,
    time_spent_ms: i < 2 ? rand(30_000..180_000) : nil
  )
end

# Second plan
endgame_plan = TrainingPlan.create!(
  title: "Endgame Fundamentals",
  description: "King and pawn endings, rook endings, basic checkmates",
  coach: coach_carol, student: students[1],
  start_date: Date.today - 2.weeks, end_date: Date.today + 6.weeks,
  status: "active", focus_area: "endgames",
  difficulty: "beginner", duration_weeks: 8
)
```

### 10.4 Study Groups and Tournaments

```ruby
# Study group
sicilian_group = StudyGroup.create!(
  name: "Sicilian Specialists",
  description: "Weekly study of Sicilian variations — Najdorf, Dragon, Sveshnikov",
  focus: "openings", level: "intermediate"
)

[students[0], students[1], students[2]].each do |s|
  StudyGroupMembership.create!(
    member: s, study_group: sicilian_group,
    role: "member", joined_at: 2.months.ago
  )
end

# Club tournament
tournament = ClubTournament.create!(
  name: "Spring Blitz Championship 2026",
  start_date: Date.today + 2.weeks,
  format: "swiss", time_control: "5+3",
  num_rounds: 5, status: "registration",
  description: "Open to all club members. 5-round Swiss, 5+3 blitz."
)

[admin, coach_bob, coach_carol, *students].each_with_index do |m, i|
  TournamentEntry.create!(
    member: m, club_tournament: tournament,
    entry_number: i + 1
  )
end

# Game annotations
GameAnnotation.create!(
  member: students[0], game_id: "zUxV8GLr",
  annotated_at: 1.week.ago,
  notes: "Interesting King's Indian structure. Missed tactical shot on move 23.",
  key_moves: %w[e4e5 d4d5 Nf3g5],
  mistakes: "23...Qd7? allowed 24.Nxf7! winning the exchange",
  improvement_plan: "Study tactical patterns: knight forks on f7, discovered attacks"
)
```

### 10.5 Data Volume Summary

| Entity | Count | Notes |
|--------|-------|-------|
| **Member** | 10 | 1 admin + 2 coaches + 7 students, all with real Lichess usernames |
| **OpeningLine** | 7 | 2 trees: Sicilian (5 nodes, 4 levels) + Italian (2 nodes) |
| **Repertoire** | 4 | Members linked to specific opening lines |
| **TrainingPlan** | 2 | Active plans with different focus areas |
| **PuzzleAssignment** | 5 | Mix: 2 solved, 3 assigned |
| **GameAnnotation** | 1+ | With real Lichess game IDs |
| **StudyGroup** | 1 | With 3 memberships |
| **ClubTournament** | 1 | In "registration" status with all members entered |
| **TournamentEntry** | 10 | All members registered |
| **lichess_player** | 10 | Fetched live from Lichess API (not seeded) |
| **lichess_game** | dynamic | Fetched on-demand per member |
| **lichess_puzzle** | 5 | Fetched on-demand per assignment |

**Note:** Seed data uses real Lichess usernames (DrNykterstein, Captain_Flint, penguingim1, etc.) for demo credibility. API-backed models are not seeded — they are fetched live from Lichess. A disclaimer notes this is demo data.

---

## 11. Localization (i18n)

The demo ships with **English (en)** as the primary locale. All code, YAML config, and seed data are in English.

### 11.1 Key Namespaces

```yaml
# config/locales/en.yml
en:
  lcp_ruby:
    models:
      member:
        one: "Member"
        other: "Members"
        fields:
          first_name: "First name"
          last_name: "Last name"
          lichess_username: "Lichess username"
          joined_at: "Joined"
      opening_line:
        one: "Opening line"
        other: "Opening lines"
        fields:
          eco: "ECO code"
          moves: "Moves"
          fen: "FEN"
          engine_eval: "Engine eval"
          white_pov: "White perspective"
      training_plan:
        one: "Training plan"
        other: "Training plans"
        enums:
          status:
            draft: "Draft"
            active: "Active"
            completed: "Completed"
            archived: "Archived"
          focus_area:
            openings: "Openings"
            tactics: "Tactics"
            endgames: "Endgames"
            strategy: "Strategy"
            speed: "Speed"
    menu:
      dashboard: "Dashboard"
      members: "Members"
      training: "Training"
      my_assignments: "My Assignments"
      training_plans: "Training Plans"
      puzzle_bank: "Puzzle Bank"
      repertoire: "Repertoire"
      tournaments: "Tournaments"
      club_tournaments: "Club Tournaments"
      standings: "Standings"
      games: "Games"
      game_annotations: "Game Annotations"
      study_groups: "Study Groups"
      lichess: "Lichess"
      settings: "Settings"
    record_rules:
      cannot_edit_completed_plan: "Cannot edit a completed training plan"
      own_annotations_only: "You can only manage your own annotations"

  chess:
    latest_games: "Latest Games"
    view_game: "View game"
    board_viewer:
      title: "Game Viewer"
      move_first: "First move"
      move_prev: "Previous move"
      move_next: "Next move"
      move_last: "Last move"
```

---

## 12. Decisions

1. **Chess Training Academy domain** — uniquely showcases API-backed models, cross-source associations, and host app integration (board viewer). No overlap with existing examples (Todo, CRM). Visually compelling.

2. **15 models (3 API-backed + 12 DB-backed)** — comprehensive coverage. API-backed models demonstrate a completely new platform capability. Each DB model exercises multiple features.

3. **Host data sources over rest_json** — Lichess returns NDJSON for game lists (not standard JSON arrays), has complex nested response structures, and field mapping requires transformation (ms timestamps → DateTime). Host adapter gives full control and is the more realistic integration pattern.

4. **Opening repertoire as tree structure** — chess openings are naturally hierarchical (1.e4 → Sicilian → Najdorf → English Attack). Technically a DAG due to transpositions, but tree model is sufficient for personal study. Unique tree use case across all demos.

5. **Cross-source FK as string** — Lichess usernames and puzzle IDs are strings, not numeric auto-increment IDs. Using string FKs demonstrates the general "foreign key to external system" pattern clearly.

6. **Separate model for tournament pairings** — pairings need to persist for result tracking and audit history. Swiss/round-robin algorithms are complex; explicit model avoids repeated computation and allows metadata (board number, bye).

7. **3 roles (admin, coach, member)** — creates a meaningful permission hierarchy with ownership patterns (coach creates plans for students, members manage own annotations). Simpler than HR's 4 roles but demonstrates record-level scoping equally well.

8. **Board viewer as host app page** — clean boundary between platform (generated CRUD) and host customization (interactive JavaScript board). Demonstrates `LcpRuby.registry.model_for` usage from host app code.

9. **Real Lichess usernames in seeds** — DrNykterstein (Magnus Carlsen), penguingim1 (Andrew Tang), etc. Fetching real data makes the demo immediately credible. Disclaimer that this is demo data.

10. **Small seed data volume (~10 members)** — this demo's value is in cross-source features and visual appeal (board viewer), not data volume. HR demo covers large-scale seeding (500 records).

11. **App name: `examples/chess`** — consistent with `examples/todo`, `examples/crm`, `examples/hr`.

12. **Tournaments as optional v2 scope** — core demo focuses on members, training plans, puzzle assignments, opening repertoire, and game annotations. Tournament models (ClubTournament, TournamentRound, TournamentPairing, TournamentEntry) are included in the design but can be implemented in a second phase.

---

## 13. Open Questions

_(None remaining — all resolved in Decisions.)_
