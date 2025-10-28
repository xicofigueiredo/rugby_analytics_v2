# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_10_28_062559) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "actions", force: :cascade do |t|
    t.bigint "player_match_id", null: false
    t.string "action_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_type"], name: "index_actions_on_action_type"
    t.index ["player_match_id", "action_type"], name: "index_actions_on_player_match_id_and_action_type"
    t.index ["player_match_id"], name: "index_actions_on_player_match_id"
  end

  create_table "matches", force: :cascade do |t|
    t.string "season"
    t.string "competition"
    t.string "description"
    t.date "date"
    t.string "result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "home_team_id"
    t.bigint "away_team_id"
    t.text "coach_notes"
    t.float "avg_time_played"
    t.float "avg_positive_tackle"
    t.float "avg_neutral_tackle"
    t.float "avg_negative_tackle"
    t.float "avg_assist_tackle"
    t.float "avg_missed_tackle"
    t.float "avg_turnover"
    t.float "avg_pen_offside"
    t.float "avg_pen_breakdown"
    t.float "avg_pen_scrum"
    t.float "avg_pen_others"
    t.float "avg_aerial_duel_won"
    t.float "avg_aerial_duel_lost"
    t.float "avg_positive_offload"
    t.float "avg_negative_offload"
    t.float "avg_linebreak"
    t.float "avg_knock_on"
    t.float "avg_positive_carry"
    t.float "avg_carries"
  end

  create_table "player_matches", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "match_id", null: false
    t.boolean "started", default: false, null: false
    t.integer "minutes_played", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "on_field", default: false, null: false
    t.integer "position"
    t.text "coach_notes"
    t.text "player_notes"
    t.integer "time_played"
    t.integer "try"
    t.integer "conversion"
    t.integer "missed_conversion"
    t.integer "penalty_kick_goal"
    t.integer "missed_penalty_kick_goals"
    t.integer "drop_goal"
    t.integer "missed_drop_goals"
    t.integer "try_assist"
    t.integer "positive_tackle"
    t.integer "neutral_tackle"
    t.integer "negative_tackle"
    t.integer "assist_tackle"
    t.integer "missed_tackle"
    t.integer "lineout_turnover"
    t.integer "lineout_won_jump"
    t.integer "lineout_won_no_jump"
    t.integer "introduction_won"
    t.integer "introduction_lost"
    t.integer "turnover"
    t.integer "pen_offside"
    t.integer "pen_breakdown"
    t.integer "pen_scrum"
    t.integer "pen_others"
    t.integer "aerial_duel_won"
    t.integer "aerial_duel_lost"
    t.integer "positive_offload"
    t.integer "negative_offload"
    t.integer "linebreak"
    t.integer "knock_on"
    t.integer "positive_carry"
    t.integer "carries"
    t.integer "yellow"
    t.integer "red"
    t.float "attack_rating"
    t.float "defense_rating"
    t.float "consistency_rating"
    t.float "discipline_rating"
    t.float "skills_rating"
    t.float "work_rate_rating"
    t.integer "linebreak_assists"
    t.integer "other_mistakes"
    t.integer "scrum_dominant"
    t.integer "mod_game_plus"
    t.integer "mod_game_minus"
    t.decimal "overall_rating", precision: 4, scale: 2
    t.integer "extra_points"
    t.index ["match_id"], name: "index_player_matches_on_match_id"
    t.index ["player_id"], name: "index_player_matches_on_player_id"
  end

  create_table "players", force: :cascade do |t|
    t.integer "age"
    t.integer "height"
    t.decimal "weight"
    t.string "positions", default: [], array: true
    t.bigint "team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "country"
    t.jsonb "cache_counters", default: {}
    t.integer "total_points", default: 0
    t.index ["team_id"], name: "index_players_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name"
    t.string "level"
    t.integer "classification"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "players_count", default: 0, null: false
    t.string "abbreviation"
    t.string "main_color"
    t.string "secondary_color"
    t.string "country", default: "Portugal", null: false
  end

  create_table "teamstats", force: :cascade do |t|
    t.bigint "match_id", null: false
    t.bigint "team_id", null: false
    t.integer "lineouts_won", default: 0, null: false
    t.integer "lineouts_lost", default: 0, null: false
    t.integer "lineouts_stolen", default: 0, null: false
    t.integer "lineouts_not_stolen", default: 0, null: false
    t.integer "scrums_won", default: 0, null: false
    t.integer "scrums_lost", default: 0, null: false
    t.integer "scrums_stolen", default: 0, null: false
    t.integer "scrums_not_stolen", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "attack_rating"
    t.float "defense_rating"
    t.float "consistency_rating"
    t.float "discipline_rating"
    t.float "skills_rating"
    t.float "work_rate_rating"
    t.index ["match_id", "team_id"], name: "index_teamstats_on_match_id_and_team_id", unique: true
    t.index ["match_id"], name: "index_teamstats_on_match_id"
    t.index ["team_id"], name: "index_teamstats_on_team_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.bigint "team_id"
    t.string "role"
    t.integer "player_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["player_id"], name: "index_users_on_player_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["team_id"], name: "index_users_on_team_id"
  end

  add_foreign_key "actions", "player_matches"
  add_foreign_key "matches", "teams", column: "away_team_id"
  add_foreign_key "matches", "teams", column: "home_team_id"
  add_foreign_key "player_matches", "matches"
  add_foreign_key "player_matches", "players"
  add_foreign_key "players", "teams"
  add_foreign_key "teamstats", "matches"
  add_foreign_key "teamstats", "teams"
  add_foreign_key "users", "teams"
end
