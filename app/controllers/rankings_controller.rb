# frozen_string_literal: true

class RankingsController < ApplicationController
  before_action :require_team

  # Stats we rank: label => block that returns value from a single PlayerMatch
  RANKABLE_STATS = {
    "Total Tackles" => ->(pm) { (pm.positive_tackle || 0) + (pm.neutral_tackle || 0) + (pm.negative_tackle || 0) + (pm.assist_tackle || 0) },
    "Total Carries" => ->(pm) { (pm.carries || 0) + (pm.positive_carry || 0) },
    "Carries With Gain" => ->(pm) { pm.positive_carry || 0 },
    "Tries" => ->(pm) { pm.try || 0 },
    "Assists" => ->(pm) { pm.try_assist || 0 },
    "Linebreak" => ->(pm) { pm.linebreak || 0 },
    "Turnovers Won" => ->(pm) { pm.turnover || 0 },
    "Positive Tackles" => ->(pm) { pm.positive_tackle || 0 },
    "Missed Tackles" => ->(pm) { pm.missed_tackle || 0 },
    "Offloads Good" => ->(pm) { pm.positive_offload || 0 },
    "Offloads Bad" => ->(pm) { pm.negative_offload || 0 },
    "Total Penalties" => ->(pm) { (pm.pen_offside || 0) + (pm.pen_breakdown || 0) + (pm.pen_scrum || 0) + (pm.pen_others || 0) },
    "Knock On" => ->(pm) { pm.knock_on || 0 },
    "Lineout Steals" => ->(pm) { pm.lineout_turnover || 0 },
    "Aerial Duels Won" => ->(pm) { pm.aerial_duel_won || 0 },
    "Time Played" => ->(pm) { pm.time_played || 0 }
  }.freeze

  TOP_N = 20

  def index
    @team = current_user.team || current_user.player&.team
    @competition_filter = params[:competition_filter] || "all"
    @period_filter = params[:period_filter] || "all_season"
    @minutes_filter = params[:minutes_filter] || "all"

    player_matches = base_player_matches

    # Build rankings for each stat: { "Total Tackles" => [ { player:, value:, minutes: }, ... ], ... }
    @rankings = {}
    RANKABLE_STATS.each do |stat_label, value_proc|
      # Group by a normalized player identifier (name) so the same person
      # with multiple Player rows (e.g. A/B team entries) is aggregated together.
      grouped = player_matches.group_by { |pm| pm.player.name.to_s.strip.downcase }
      rows = grouped.map do |player_key, pms|
        # prefer a player record that belongs to the team, otherwise pick the first
        player = pms.find { |pm| pm.player.team_id == @team.id }&.player || pms.first.player
        minutes = pms.sum { |pm| pm.time_played || 0 }
        total_value = pms.sum { |pm| value_proc.call(pm) }
        value_per_10 = minutes.positive? ? ((total_value.to_f / minutes) * 10.0) : 0.0

        {
          player: player,
          value: (@minutes_filter == "min_10" ? value_per_10 : total_value),
          total_value: total_value,
          value_per_10: value_per_10,
          minutes: minutes
        }
      end
      # Sort by selected metric desc, then by total desc
      @rankings[stat_label] = rows.sort_by { |r| [-r[:value], -r[:total_value]] }.first(TOP_N)
    end

    # Rankings shown as won/total (e.g. 11/14)
    @rankings["Conversions"] = build_ratio_ranking(
      player_matches,
      won_proc: ->(pm) { pm.conversion || 0 },
      total_proc: ->(pm) { (pm.conversion || 0) + (pm.missed_conversion || 0) }
    )
    @rankings["Lineout Introductions"] = build_ratio_ranking(
      player_matches,
      won_proc: ->(pm) { pm.introduction_won || 0 },
      total_proc: ->(pm) { (pm.introduction_won || 0) + (pm.introduction_lost || 0) }
    )

    # Average overall ratings (top by average overall_rating)
    rated_pms = player_matches.where.not(overall_rating: nil)
    grouped_ratings = rated_pms.group_by { |pm| pm.player.name.to_s.strip.downcase }
    avg_rows = grouped_ratings.map do |player_key, pms|
      player = pms.find { |pm| pm.player.team_id == @team.id }&.player || pms.first.player
      avg = pms.sum { |pm| (pm.overall_rating || 0).to_f } / (pms.size.nonzero? || 1)
      { player: player, avg: avg.to_f, games: pms.size }
    end
    @average_ratings = avg_rows.sort_by { |r| -r[:avg] }.first(TOP_N)
    # Top performances: return the top N PlayerMatch performances by overall_rating.
    # This allows the same player to appear multiple times (vs different opponents).
    perf_rows = rated_pms.includes(match: [:home_team, :away_team]).map do |pm|
      next unless pm.overall_rating
      match = pm.match
      is_home = (match.home_team_id == @team.id)
      opponent = is_home ? match.away_team : match.home_team
      {
        player: pm.player,
        opponent_name: opponent&.name || "Unknown",
        loc: (is_home ? 'H' : 'A'),
        rating: pm.overall_rating.to_f,
        date: match.date
      }
    end.compact
    @top_performances = perf_rows.sort_by { |r| -r[:rating] }.first(TOP_N)
  end

  private

  def require_team
    team = current_user&.team || current_user&.player&.team
    return if team.present?

    redirect_to root_path, alert: "You are not assigned to a team. Please contact an administrator."
  end

  def base_player_matches
    # Matches for this team (home or away), with optional competition filter
    matches_query = Match.where("home_team_id = ? OR away_team_id = ?", @team.id, @team.id)
                        .order(date: :desc)

    case @competition_filter
    when "cn1"
      matches_query = matches_query.where("competition ILIKE ?", "%CN1%")
    when "cn2"
      matches_query = matches_query.where("competition ILIKE ?", "%CN2%")
    end

    # Limit by period: last game, last 5, or all
    match_ids = case @period_filter
                when "last_game"
                  matches_query.limit(1).pluck(:id)
                when "last_5"
                  matches_query.limit(5).pluck(:id)
                else
                  matches_query.pluck(:id)
                end

    return PlayerMatch.none if match_ids.empty?

    player_matches = PlayerMatch.joins(:player, :match)
                                .where(match_id: match_ids)
                                .where(players: { team_id: @team.id })
                                .where("player_matches.time_played > 0")
                                .includes(:player)

    case @minutes_filter
    when "min_10"
      player_matches = player_matches.where("player_matches.time_played >= 10")
    end

    player_matches
  end

  def build_ratio_ranking(player_matches, won_proc:, total_proc:)
    grouped = player_matches.group_by { |pm| pm.player.name.to_s.strip.downcase }
    rows = grouped.map do |_player_key, pms|
      player = pms.find { |pm| pm.player.team_id == @team.id }&.player || pms.first.player
      won = pms.sum { |pm| won_proc.call(pm) }
      total = pms.sum { |pm| total_proc.call(pm) }
      minutes = pms.sum { |pm| pm.time_played || 0 }

      {
        player: player,
        value: (@minutes_filter == "min_10" ? (minutes.positive? ? ((won.to_f / minutes) * 10.0) : 0.0) : won),
        won: won,
        total: total,
        total_value: won,
        minutes: minutes
      }
    end

    rows
      .select { |row| row[:total].positive? }
      .sort_by { |row| [-row[:value], -row[:total_value]] }
      .first(TOP_N)
  end
end
