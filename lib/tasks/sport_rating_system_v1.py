import pandas as pd
import json
import sys

def calculate_discipline_rating(df):
    """
    Calculate discipline rating for players starting at 10 and deducting for penalties/errors

    Args:
        df: DataFrame with player statistics

    Returns:
        Series of discipline ratings (1-10 scale)
    """
    # Filter out players with 0 minutes
    valid_players = df['minutes'] > 0
    minutes = df['minutes']

    # Start everyone at 10 (perfect discipline)
    discipline_rating = [10.0] * len(df)

    # Penalty deductions (time-adjusted)
    time_multiplier = [1.5 if m <= 20 else (1.3 if m <= 40 else (1.0 if m <= 80 else 1.0)) for m in minutes]

    # Different penalty weights
    total_penalties = df.get('total_penalties', [0] * len(df))
    offside_penalties = df.get('offside_penalties', [0] * len(df))
    ruck_penalties = df.get('ruck_penalties', [0] * len(df))
    scrum_penalties = df.get('scrum_penalties', [0] * len(df))
    other_penalties = df.get('other_penalties', [0] * len(df))
    other_mistakes = df.get('other_mistakes', [0] * len(df))
    knock_ons = df.get('knock_on', [0] * len(df))
    yellow_cards = df.get('yellow_cards', [0] * len(df))
    red_cards = df.get('red_cards', [0] * len(df))

    # Calculate deductions (time-adjusted)
    # More serious penalties have higher deductions
    total_penalty_deduction = [pow(tp, 1.5) * 0.8 * tm for tp, tm in zip(total_penalties, time_multiplier)]
    offside_deduction = [op * 0.4 * tm for op, tm in zip(offside_penalties, time_multiplier)]
    ruck_deduction = [rp * 0.3 * tm for rp, tm in zip(ruck_penalties, time_multiplier)]
    scrum_deduction = [sp * 0.2 * tm for sp, tm in zip(scrum_penalties, time_multiplier)]
    other_penalty_deduction = [op * 0.2 * tm for op, tm in zip(other_penalties, time_multiplier)]
    mistake_deduction = [om * 0.1 * tm for om, tm in zip(other_mistakes, time_multiplier)]
    knock_on_deduction = [ko * 0.2 * tm for ko, tm in zip(knock_ons, time_multiplier)]
    yellow_card_deduction = [yc * 1.5 for yc in yellow_cards]
    red_card_deduction = [rc * 3.0 for rc in red_cards]

    # Apply deductions
    discipline_rating = [dr - tpd - od - rd - sd - opd - md - kod - ycd - rcd
                        for dr, tpd, od, rd, sd, opd, md, kod, ycd, rcd in
                        zip(discipline_rating, total_penalty_deduction, offside_deduction,
                            ruck_deduction, scrum_deduction, other_penalty_deduction,
                            mistake_deduction, knock_on_deduction, yellow_card_deduction,
                            red_card_deduction)]

    # Ensure ratings stay within 1-10 range
    discipline_rating = [max(1, min(10, dr)) for dr in discipline_rating]

    # Only return ratings for players with valid minutes (exclude others)
    return [round(dr, 2) for dr, valid in zip(discipline_rating, valid_players) if valid]

def calculate_defense_rating(df):
    """
    Calculate defense rating for players with tackles as base and turnovers/offside penalties as bonuses

    Args:
        df: DataFrame with player statistics

    Returns:
        Series of defense ratings (1-10 scale)
    """
    # Filter out players with 0 minutes
    valid_players = df['minutes'] > 0
    minutes = df['minutes']

    # Calculate tackle success rate (including assist tackles)
    total_tackles = df.get('neutral_tackles', [0] * len(df)) + df.get('offensive_tackles', [0] * len(df)) + df.get('defensive_tackles', [0] * len(df)) + df.get('assist_tackles', [0] * len(df))
    missed_tackles = df.get('missed_tackles', [0] * len(df))
    # Handle NaN values in missed_tackles by converting to 0
    missed_tackles = [0 if pd.isna(mt) else mt for mt in missed_tackles]
    tackle_success_rate = [tt / (tt + mt) if (tt + mt) > 0 else 0
                          for tt, mt in zip(total_tackles, missed_tackles)]

    # Calculate tackle impact score (weighted tackles including assist tackles with 0.8 weight)
    tackle_impact = (df.get('offensive_tackles', [0] * len(df)) * 1.5 +
                   df.get('neutral_tackles', [0] * len(df)) * 1.0 +
                   df.get('defensive_tackles', [0] * len(df)) * 0.3 +
                   df.get('assist_tackles', [0] * len(df)) * 0.8)

    # Calculate base defense rating components (1-10 scale)
    # Tackle success rate: 0% = 1 rating, 100% = 10 rating
    tackle_success_rating = [10.0 if tsr >= 1.0 else tsr * 10 for tsr in tackle_success_rate]
    tackle_success_rating = [max(1, tsr) for tsr in tackle_success_rating]

    # Tackle impact: normalize to 1-10 scale (using absolute values)
    tackle_impact_rating = [10.0 if ti >= 10 else (ti/10) * 10.0 for ti in tackle_impact]
    tackle_impact_rating = [max(1, tir) for tir in tackle_impact_rating]

    # Total tackles rating: normalize to 1-10 scale (using absolute values)
    total_tackles_rating = [10.0 if tt >= 15 else (tt/15) * 10 for tt in total_tackles]
    total_tackles_rating = [max(1, ttr) for ttr in total_tackles_rating]

    # Calculate bonuses (time-adjusted)
    time_multiplier = [1.5 if m <= 20 else (1.3 if m <= 40 else (1.0 if m <= 80 else 1.0)) for m in minutes]

    # Turnover bonuses (time-adjusted)
    turnovers_won = df.get('turnovers_won', [0] * len(df))
    turnover_bonus = [tw * 1 * tm for tw, tm in zip(turnovers_won, time_multiplier)]

    # Lineout steals bonuses (time-adjusted)
    lineout_steals = df.get('lineout_steals', [0] * len(df))
    lineout_steal_bonus = [ls * 0.5 * tm for ls, tm in zip(lineout_steals, time_multiplier)]

    # Offside penalty bonuses (time-adjusted)
    offside_penalties = df.get('offside_penalties', [0] * len(df))
    offside_bonus = [op * -0.6 * tm for op, tm in zip(offside_penalties, time_multiplier)]

    # Missed tackles penalties (time-adjusted)
    # Use the already processed missed_tackles (with NaN handling)
    missed_tackle_penalty = [mt * -0.5 * tm for mt, tm in zip(missed_tackles, time_multiplier)]

    # Other mistakes penalties (time-adjusted)
    other_mistakes = df.get('other_mistakes', [0] * len(df))
    other_mistake_penalty = [om * -0.2 * tm for om, tm in zip(other_mistakes, time_multiplier)]

    # Total bonus points
    total_bonus = [tb + lsb + ob + mtp + omp for tb, lsb, ob, mtp, omp in
                  zip(turnover_bonus, lineout_steal_bonus, offside_bonus, missed_tackle_penalty, other_mistake_penalty)]

    # Calculate reliability factor: N/(N+k) where N=minutes, k=20
    reliability = [m / (m + 20) for m in minutes]

    # Calculate team average ratings for reliability adjustment
    valid_tackles = [ttr for ttr, valid in zip(total_tackles_rating, valid_players) if valid]
    valid_success = [tsr for tsr, valid in zip(tackle_success_rating, valid_players) if valid]
    valid_impact = [tir for tir, valid in zip(tackle_impact_rating, valid_players) if valid]

    team_avg_total_tackles = sum(valid_tackles) / len(valid_tackles) if valid_tackles else 5.0
    team_avg_tackle_success = sum(valid_success) / len(valid_success) if valid_success else 5.0
    team_avg_tackle_impact = sum(valid_impact) / len(valid_impact) if valid_impact else 5.0

    # Apply reliability adjustment to individual tackle ratings
    total_tackles_rating = [ttr * r + team_avg_total_tackles * (1 - r)
                           for ttr, r in zip(total_tackles_rating, reliability)]
    tackle_success_rating = [tsr * r + team_avg_tackle_success * (1 - r)
                            for tsr, r in zip(tackle_success_rating, reliability)]
    tackle_impact_rating = [tir * r + team_avg_tackle_impact * (1 - r)
                           for tir, r in zip(tackle_impact_rating, reliability)]

    # Recalculate base defense rating with reliability-adjusted components
    base_defense_rating = [ttr * 0.65 + tsr * 0.10 + tir * 0.25
                          for ttr, tsr, tir in zip(total_tackles_rating, tackle_success_rating, tackle_impact_rating)]

    # Base defense rating with bonuses
    base_defense_rating_with_bonuses = [bdr + tb for bdr, tb in zip(base_defense_rating, total_bonus)]

    # Calculate defense relative score (fixed 10% weight)
    # Fixed weights for defensive stats only
    defense_weights = {
        'total_tackles': 0.45,
        'tackle_success_rate': 0.25,
        'tackle_impact': 0.2,
        'turnovers_won': 0.15,
        'offside_penalties': -0.03,
        'assist_tackles': 0.08,
        'missed_tackles': -0.08,
        'other_mistakes': -0.02
    }

    # Filter valid players for relative scoring
    valid_players_rel = df['minutes'] > 0
    df_valid_rel = df[valid_players_rel].copy()

    # Add calculated stats to the DataFrame for relative scoring
    df_valid_rel['total_tackles'] = [tt for tt, valid in zip(total_tackles, valid_players_rel) if valid]
    df_valid_rel['tackle_success_rate'] = [tsr for tsr, valid in zip(tackle_success_rate, valid_players_rel) if valid]
    df_valid_rel['tackle_impact'] = [ti for ti, valid in zip(tackle_impact, valid_players_rel) if valid]

    if len(df_valid_rel) > 0:
        # Initialize relative scores
        relative_scores = [0.0] * len(df_valid_rel)

        for stat, weight in defense_weights.items():
            if stat in df_valid_rel.columns:
                stat_values = df_valid_rel[stat].tolist()
                if len(stat_values) > 0:
                    min_val = min(stat_values)
                    max_val = max(stat_values)

                    if max_val > min_val:
                        # Normalize to 1-10 scale
                        normalized = [1 + (sv - min_val) / (max_val - min_val) * 9 for sv in stat_values]
                    else:
                        normalized = [5.0] * len(stat_values)  # Default middle value

                    relative_scores = [rs + n * weight for rs, n in zip(relative_scores, normalized)]

        # Ensure relative score is in 1-10 range
        relative_scores = [max(1, min(10, rs)) for rs in relative_scores]
    else:
        relative_scores = [5.0] * len(df)  # Default middle value if no valid players

    # Combine: 90% base + 10% relative
    # Create full-length relative scores array
    full_relative_scores = [5.0] * len(df)  # Default middle value
    for i, (valid, rs) in enumerate(zip(valid_players_rel, relative_scores)):
        if valid:
            full_relative_scores[i] = rs

    defense_rating = [bdr + rs * 0.1 for bdr, rs in zip(base_defense_rating_with_bonuses, full_relative_scores)]

    # Only adjust scores outside 1-10 range (don't change scores already in range)
    defense_rating = [max(1, min(10, dr)) for dr in defense_rating]

    # Only return ratings for players with valid minutes (exclude others)
    return [round(dr, 2) for dr, valid in zip(defense_rating, valid_players) if valid]

def calculate_attack_rating(df):
    """
    Calculate attack rating for players centered around carries with integrated relative scoring

    Args:
        df: DataFrame with player statistics

    Returns:
        Series of attack ratings (1-10 scale)
    """
    # Filter out players with 0 minutes
    valid_players = df['minutes'] > 0
    minutes = df['minutes']

    # Per-minute stats for the 3 main carry stats only
    # Use minimum of 10 minutes for per-minute calculations
    carries_with_gain_per_min = df['carries_with_gain'] / minutes
    carries_without_gain_per_min = df['carries_without_gain'] / minutes

    # Calculate total carries per minute
    total_carries_per_min = carries_with_gain_per_min + carries_without_gain_per_min

    # Calculate percentage of carries with gain
    carry_percentage = [((cgpm / tcpm) * 100) if tcpm > 0 else 0
                       for cgpm, tcpm in zip(carries_with_gain_per_min, total_carries_per_min)]

    # Rate total carries per minute (0-10 scale)
    # 0.15 per min = 12 carries in 80 min = 10 rating
    total_carries_rating = [10.0 if tcpm >= 0.15 else (tcpm / 0.15) * 10
                           for tcpm in total_carries_per_min]
    total_carries_rating = [max(1, tcr) for tcr in total_carries_rating]

    # Rate carries with gain per minute (0-10 scale)
    # 0.05 per min = 4 carries in 80 min = 10 rating
    carries_with_gain_rating = [10.0 if cgpm >= 0.05 else (cgpm / 0.05) * 10
                               for cgpm in carries_with_gain_per_min]
    carries_with_gain_rating = [max(1, cgr) for cgr in carries_with_gain_rating]

    # Rate carry percentage (0-10 scale)
    # 0% = 0 rating, 40%+ = 10 rating
    carry_percentage_rating = [10.0 if cp >= 40 else (cp / 40) * 10 for cp in carry_percentage]
    carry_percentage_rating = [max(1, cpr) for cpr in carry_percentage_rating]

    # Calculate reliability factor: N/(N+k) where N=minutes, k=20
    reliability = [m / (m + 20) for m in minutes]

    # Calculate team average ratings for reliability adjustment
    valid_total_carries = [tcr for tcr, valid in zip(total_carries_rating, valid_players) if valid]
    valid_carries_with_gain = [cgr for cgr, valid in zip(carries_with_gain_rating, valid_players) if valid]
    valid_carry_percentage = [cpr for cpr, valid in zip(carry_percentage_rating, valid_players) if valid]

    team_avg_total_carries = sum(valid_total_carries) / len(valid_total_carries) if valid_total_carries else 5.0
    team_avg_carries_with_gain = sum(valid_carries_with_gain) / len(valid_carries_with_gain) if valid_carries_with_gain else 5.0
    team_avg_carry_percentage = sum(valid_carry_percentage) / len(valid_carry_percentage) if valid_carry_percentage else 5.0

    # Apply reliability adjustment to individual carry ratings
    total_carries_rating = [tcr * r + team_avg_total_carries * (1 - r)
                           for tcr, r in zip(total_carries_rating, reliability)]
    carries_with_gain_rating = [cgr * r + team_avg_carries_with_gain * (1 - r)
                               for cgr, r in zip(carries_with_gain_rating, reliability)]
    carry_percentage_rating = [cpr * r + team_avg_carry_percentage * (1 - r)
                              for cpr, r in zip(carry_percentage_rating, reliability)]

    # Calculate base attack rating with weights
    # 75% total carries, 15% carries with gain, 10% carry percentage
    base_attack_rating = [tcr * 0.65 + cgr * 0.25 + cpr * 0.10
                         for tcr, cgr, cpr in zip(total_carries_rating, carries_with_gain_rating, carry_percentage_rating)]

    # Calculate time-adjusted bonus points
    # 80 min = 1x, 40 min = 1.3x, 20 min = 1.5x
    time_multiplier = [1.0 if m <= 80 else (1.3 if m <= 40 else (1.5 if m <= 20 else 1.0)) for m in minutes]

    # Time-adjusted bonuses for tries, assists, linebreaks, mod game plues
    try_bonus = [t * 1.0 * tm for t, tm in zip(df['tries'], time_multiplier)]
    assist_bonus = [a * 0.6 * tm for a, tm in zip(df['assists'], time_multiplier)]
    linebreak_bonus = [l * 0.4 * tm for l, tm in zip(df['linebreak'], time_multiplier)]
    linebreak_assist_bonus = [la * 0.5 * tm for la, tm in zip(df.get('linebreak_assists', [0] * len(df)), time_multiplier)]
    mod_game_plus_bonus = [mgp * 0.3 * tm for mgp, tm in zip(df.get('mod_game_plus', [0] * len(df)), time_multiplier)]

    # Offload bonuses/penalties (time-adjusted)
    offloads_good = df.get('offloads_good', [0] * len(df))
    offloads_bad = df.get('offloads_bad', [0] * len(df))
    offload_bonus = [(og * 0.3 - ob * 0.3) * tm for og, ob, tm in zip(offloads_good, offloads_bad, time_multiplier)]

    # Mistake penalties (time-adjusted)
    knock_on = df.get('knock_on', [0] * len(df))
    mod_game_minus = df.get('mod_game_minus', [0] * len(df))
    mistake_penalty = [(ko * -0.3 + mgm * -0.2) * tm for ko, mgm, tm in zip(knock_on, mod_game_minus, time_multiplier)]

    # Conversion/kick bonuses (made = +0.2, missed = -0.2)
    conversions_made = df.get('conversions_made', [0] * len(df))
    conversions_attempted = df.get('conversions_attempted', [0] * len(df))
    conversions_missed = [ca - cm for ca, cm in zip(conversions_attempted, conversions_made)]

    kicks_made = df.get('kicks_made', [0] * len(df))
    kicks_attempted = df.get('kicks_attempted', [0] * len(df))
    kicks_missed = [ka - km for ka, km in zip(kicks_attempted, kicks_made)]

    drops_made = df.get('drops_made', [0] * len(df))
    drops_attempted = df.get('drops_attempted', [0] * len(df))
    drops_missed = [da - dm for da, dm in zip(drops_attempted, drops_made)]

    # Absolute kick bonuses (no time adjustment)
    # Conversions made/missed: 0.2, others: 0.3
    kick_bonus = [
        (cm * 0.2) + (cms * -0.2) + (km * 0.3) + (kms * -0.3) + (dm * 0.3) + (dms * -0.3)
        for cm, cms, km, kms, dm, dms in zip(conversions_made, conversions_missed, kicks_made, kicks_missed, drops_made, drops_missed)
    ]

    # Total bonus points
    total_bonus = [tb + ab + lb + lab + ob + mp + kb + mgpb
                   for tb, ab, lb, lab, ob, mp, kb, mgpb in
                   zip(try_bonus, assist_bonus, linebreak_bonus, linebreak_assist_bonus,
                       offload_bonus, mistake_penalty, kick_bonus, mod_game_plus_bonus)]

    # Base attack rating with bonuses
    base_attack_rating_with_bonuses = [bar + tb for bar, tb in zip(base_attack_rating, total_bonus)]

    # # Calculate reliability factor: N/(N+k) where N=minutes, k=20
    # reliability = minutes / (minutes + 20)


    # # Apply reliability adjustment: individual * reliability + team_avg * (1-reliability)
    # base_attack_rating_with_bonuses = (base_attack_rating_with_bonuses * reliability +
    #                                  team_average_rating * (1 - reliability))

    # Calculate attack relative score (fixed 10% weight)
    # Fixed weights for attacking stats only (excluding kicking)
    attack_weights = {
        'tries': 0.15,
        'assists': 0.10,
        'linebreak': 0.10,
        'linebreak_assists': 0.10,
        'carries_with_gain': 0.20,
        'total_carries': 0.3,
        'offloads_good': 0.05,
        'offloads_bad': -0.05,  # Negative weight for bad offloads
        'knock_on': -0.05,  # Negative weight for knock-ons
        'carry_percentage': 0.1,
        'mod_game_plus': 0.03,
        'mod_game_minus': -0.03
    }

    # Filter valid players for relative scoring
    valid_players_rel = df['minutes'] > 0
    df_valid_rel = df[valid_players_rel].copy()

    if len(df_valid_rel) > 0:
        # Initialize relative scores
        relative_scores = [0.0] * len(df_valid_rel)

        # Process each attacking stat
        for stat, weight in attack_weights.items():
            if stat in df_valid_rel.columns:
                # Get the stat values
                stat_values = df_valid_rel[stat].fillna(0)

                # Skip if all values are the same (no variation)
                if stat_values.nunique() <= 1:
                    continue

                # Min-max normalization to 1-10 scale
                min_val = stat_values.min()
                max_val = stat_values.max()

                if max_val > min_val:  # Avoid division by zero
                    normalized = [1 + ((sv - min_val) / (max_val - min_val)) * 9 for sv in stat_values]
                else:
                    normalized = [5.5] * len(stat_values)  # Middle value if no variation

                # Add weighted contribution to relative score
                relative_scores = [rs + n * weight for rs, n in zip(relative_scores, normalized)]

        # Ensure scores are between 1-10
        relative_scores = [max(1, min(10, rs)) for rs in relative_scores]

        # Create result array with original length
        relative_score = [float('nan')] * len(df)
        for i, (valid, rs) in enumerate(zip(valid_players_rel, relative_scores)):
            if valid:
                relative_score[i] = rs
    else:
        relative_score = [5.0] * len(df)  # Default middle value if no valid players

    # Combine: 90% base + 10% relative
    attack_rating = [barwb + (rs * 0.1 if not pd.isna(rs) else 0)
                    for barwb, rs in zip(base_attack_rating_with_bonuses, relative_score)]

    # Only adjust scores outside 1-10 range (don't change scores already in range)
    attack_rating = [max(1, min(10, ar)) for ar in attack_rating]

    # Only return ratings for players with valid minutes (exclude others)
    return [round(ar, 2) for ar, valid in zip(attack_rating, valid_players) if valid]

def calculate_work_rate_rating(df):
    """
    Calculate work rate rating with BASE = total number of actions.

    Actions considered (absolute counts):
    - Carries: carries_with_gain + carries_without_gain
    - Tackles: offensive + neutral + defensive + assist_tackles
    - Turnovers won
    - Mod. JOGO + (counted as actions)

    The base rating is derived from actions per minute (with a minimum 10 minutes divisor),
    min-max normalized to 1-10 among valid players, and lightly reliability-adjusted with N/(N+20).
    """
    # Filter out players with 0 minutes
    valid_players = df['minutes'] > 0
    minutes = df['minutes']

    # Gather inputs
    carries_with_gain = df.get('carries_with_gain', [0] * len(df))
    carries_without_gain = df.get('carries_without_gain', [0] * len(df))
    total_carries = [cwg + cwog for cwg, cwog in zip(carries_with_gain, carries_without_gain)]

    offensive_tackles = df.get('offensive_tackles', [0] * len(df))
    neutral_tackles = df.get('neutral_tackles', [0] * len(df))
    defensive_tackles = df.get('defensive_tackles', [0] * len(df))
    assist_tackles = df.get('assist_tackles', [0] * len(df))
    total_tackles = [ot + nt + dt + at for ot, nt, dt, at in zip(offensive_tackles, neutral_tackles, defensive_tackles, assist_tackles)]

    linebreak_assists = df.get('linebreak_assists', [0] * len(df))
    offloads_good = df.get('offloads_good', [0] * len(df))
    lineout_steals = df.get('lineout_steals', [0] * len(df))
    scrum_dominant = df.get('scrum_dominant', [0] * len(df))
    turnovers_won = df.get('turnovers_won', [0] * len(df))
    mod_plus = df.get('mod_game_plus', [0] * len(df))

    # BASE: total number of actions (absolute)
    total_actions = [tc + tt + tw + mp + la + og + ls + sd for tc, tt, tw, mp, la, og, ls, sd in zip(total_carries, total_tackles, turnovers_won, mod_plus, linebreak_assists, offloads_good, lineout_steals, scrum_dominant)]

    # Reliability adjustment on absolute actions
    reliability = [m / (m + 20) for m in minutes]
    total_actions_valid = [ta for ta, valid in zip(total_actions, valid_players) if valid]
    team_avg_actions = sum(total_actions_valid) / len(total_actions_valid) if total_actions_valid else 0
    actions_adj = [ta * r + team_avg_actions * (1 - r) for ta, r in zip(total_actions, reliability)]

    # Absolute rating: 25 total actions => 10
    abs_rating = [10.0 if aa >= 20 else (aa / 20.0) * 10.0 for aa in actions_adj]
    abs_rating = [max(1, ar) for ar in abs_rating]

    # Relative rating: min-max of total actions to 1-10 (no reliability here)
    if any(valid_players):
        min_val = min(total_actions_valid)
        max_val = max(total_actions_valid)
        if max_val > min_val:
            rel_rating_all = [1 + (ta - min_val) / (max_val - min_val) * 9 for ta in total_actions]
        else:
            rel_rating_all = [5.5] * len(df)
    else:
        rel_rating_all = [5.5] * len(df)

    # Combine: 90% absolute + 10% relative
    work_rate_rating = [ar * 0.9 + rr * 0.1 for ar, rr in zip(abs_rating, rel_rating_all)]

    # Clamp to 1-10
    work_rate_rating = [max(1, min(10, wrr)) for wrr in work_rate_rating]

    return [round(wrr, 2) for wrr, valid in zip(work_rate_rating, valid_players) if valid]

def calculate_skills_rating(df):
    """
    Skills rating: Start at 5, add/subtract points based on stats.
    Min 1, Max 10.

    Args:
        df: DataFrame with player statistics

    Returns:
        Series of skills ratings (1-10 scale)
    """
    valid_players = df['minutes'] > 0
    minutes = df['minutes']

    # Start everyone at 5
    skills_rating = [5.0] * len(df)

    # Kicking bonuses/penalties
    conv_made = df.get('conversions_made', [0] * len(df))
    conv_att = df.get('conversions_attempted', [0] * len(df))
    pen_made = df.get('kicks_made', [0] * len(df))
    pen_att = df.get('kicks_attempted', [0] * len(df))
    drop_made = df.get('drops_made', [0] * len(df))
    drop_att = df.get('drops_attempted', [0] * len(df))

    # Conversion points: +0.5 per made, -0.3 per missed
    conv_points = [cm * 0.2 - (ca - cm) * 0.1 for cm, ca in zip(conv_made, conv_att)]
    skills_rating = [sr + cp for sr, cp in zip(skills_rating, conv_points)]

    # Penalty points: +0.4 per made, -0.4 per missed
    pen_points = [pm * 0.3 - (pa - pm) * 0.2 for pm, pa in zip(pen_made, pen_att)]
    skills_rating = [sr + pp for sr, pp in zip(skills_rating, pen_points)]

    # Drop points: +0.3 per made, -0.3 per missed
    drop_points = [dm * 0.4 - (da - dm) * 0.2 for dm, da in zip(drop_made, drop_att)]
    skills_rating = [sr + dp for sr, dp in zip(skills_rating, drop_points)]

    # Offloads: +0.2 per good, -0.2 per bad
    offloads_good = df.get('offloads_good', [0] * len(df))
    offloads_bad = df.get('offloads_bad', [0] * len(df))
    offload_points = [og * 0.7 - ob * 0.4 for og, ob in zip(offloads_good, offloads_bad)]
    skills_rating = [sr + op for sr, op in zip(skills_rating, offload_points)]

    # Linebreak assists: +0.5 each
    lba = df.get('linebreak_assists', [0] * len(df))
    skills_rating = [sr + lba_val * 0.5 for sr, lba_val in zip(skills_rating, lba)]

    # Linebreaks: +0.6 each
    linebreaks = df.get('linebreak', [0] * len(df))
    skills_rating = [sr + lb * 0.4 for sr, lb in zip(skills_rating, linebreaks)]

    # Turnovers won: +0.4 each
    turnovers = df.get('turnovers_won', [0] * len(df))
    skills_rating = [sr + t * 0.8 for sr, t in zip(skills_rating, turnovers)]

    # Aerial duels: +0.2 per won, -0.1 per lost
    aerial_won = df.get('aerial_duels_won', [0] * len(df))
    aerial_lost = df.get('aerial_duels_lost', [0] * len(df))
    aerial_points = [aw * 0.3 - al * 0.1 for aw, al in zip(aerial_won, aerial_lost)]
    skills_rating = [sr + ap for sr, ap in zip(skills_rating, aerial_points)]

    # Lineout steals: +0.3 each
    lineout_steals = df.get('lineout_steals', [0] * len(df))
    skills_rating = [sr + ls * 0.5 for sr, ls in zip(skills_rating, lineout_steals)]

    # Lineout success: +0.1 per successful lineout (up to 2.0 max)
    own_lineouts_with_jump = df.get('own_lineouts_with_jump', [0] * len(df))
    lineout_success_points = [min(olw * 0.1, 2.0) for olw in own_lineouts_with_jump]
    skills_rating = [sr + lsp for sr, lsp in zip(skills_rating, lineout_success_points)]

    # Lineout introductions: +0.1 per successful intro (up to 2 max)
    lineout_intros_won = df.get('lineout_intros_won', [0] * len(df))
    lineout_intro_points = [min(liw * 0.1, 2) for liw in lineout_intros_won]
    skills_rating = [sr + lip for sr, lip in zip(skills_rating, lineout_intro_points)]

    # Scrum dominance: +0.2 each
    scrum_dominant = df.get('scrum_dominant', [0] * len(df))
    skills_rating = [sr + sd * 0.5 for sr, sd in zip(skills_rating, scrum_dominant)]

    # Mistakes and errors: penalties
    knock_ons = df.get('knock_on', [0] * len(df))
    other_mistakes = df.get('other_mistakes', [0] * len(df))
    mistake_penalty = [ko * -0.4 + om * -0.2 for ko, om in zip(knock_ons, other_mistakes)]
    skills_rating = [sr + mp for sr, mp in zip(skills_rating, mistake_penalty)]

    # Time bonus removed - no adjustment based on minutes played

    # Only adjust scores outside 1-10 range (don't change scores already in range)
    skills_rating = [max(1, min(10, sr)) for sr in skills_rating]

    # Only return ratings for players with valid minutes (exclude others)
    return [round(sr, 2) for sr, valid in zip(skills_rating, valid_players) if valid]

def calculate_consistency_rating(df):
    """
    Consistency rating: Start at 10, calculate percentages for various skills,
    and penalize for mistakes. Min 1, Max 10.

    Calculates percentages for:
    - Kicking accuracy (conversions, penalties, drops)
    - Tackling success rate
    - Lineout introductions success rate
    - Mod game plus/minus ratio
    - Aerial duel success rate
    - Offload success rate
    - Carries with gain success rate

    Penalties for:
    - Penalties committed
    - Knock-ons and other mistakes

    Args:
        df: DataFrame with player statistics

    Returns:
        Series of consistency ratings (1-10 scale)
    """
    valid_players = df['minutes'] > 0
    minutes = df['minutes']

    # Start everyone at 10
    consistency_rating = [10.0] * len(df)

    # 1. Kicking consistency (conversions, penalties, drops)
    conv_made = df.get('conversions_made', [0] * len(df))
    conv_att = df.get('conversions_attempted', [0] * len(df))
    pen_made = df.get('kicks_made', [0] * len(df))
    pen_att = df.get('kicks_attempted', [0] * len(df))
    drop_made = df.get('drops_made', [0] * len(df))
    drop_att = df.get('drops_attempted', [0] * len(df))

    # Calculate kicking percentages
    conv_pct = [(cm / ca) * 100 if ca > 0 else 100 for cm, ca in zip(conv_made, conv_att)]
    pen_pct = [(pm / pa) * 100 if pa > 0 else 100 for pm, pa in zip(pen_made, pen_att)]
    drop_pct = [(dm / da) * 100 if da > 0 else 100 for dm, da in zip(drop_made, drop_att)]

    # Average kicking percentage (only if any kicks attempted)
    total_kicks = [ca + pa + da for ca, pa, da in zip(conv_att, pen_att, drop_att)]
    kicking_pct = [(cp * ca + pp * pa + dp * da) / tk if tk > 0 else 100
                  for cp, ca, pp, pa, dp, da, tk in zip(conv_pct, conv_att, pen_pct, pen_att, drop_pct, drop_att, total_kicks)]

    # Kicking consistency: 100% = +0, 0% = -1 (linear scaling)
    kicking_consistency = [(kp - 100) / 100 for kp in kicking_pct]  # -1 point at 0%
    consistency_rating = [cr + kc for cr, kc in zip(consistency_rating, kicking_consistency)]

    # 2. Tackling consistency
    tackles_made = [ot + nt + dt for ot, nt, dt in zip(df.get('offensive_tackles', [0] * len(df)), df.get('neutral_tackles', [0] * len(df)), df.get('defensive_tackles', [0] * len(df)))]
    tackles_missed = df.get('missed_tackles', [0] * len(df))
    # Handle NaN values in missed_tackles by converting to 0
    tackles_missed = [0 if pd.isna(tm) else tm for tm in tackles_missed]
    total_tackles = [tm + tms for tm, tms in zip(tackles_made, tackles_missed)]

    tackle_pct = [(tm / tt) * 100 if tt > 0 else 100 for tm, tt in zip(tackles_made, total_tackles)]

    # Tackling consistency: 100% = +0, 0% = -5 (linear scaling)
    tackle_consistency = [(tp - 100) / 20 * 1 for tp in tackle_pct]  # -5 at 0%
    consistency_rating = [cr + tc for cr, tc in zip(consistency_rating, tackle_consistency)]

    # 3. Lineout introductions consistency
    lineout_intros_won = df.get('lineout_intros_won', [0] * len(df))
    lineout_intros_total = df.get('lineout_intros_total', [0] * len(df))

    lineout_intro_pct = [(liw / lit) * 100 if lit > 0 else 100 for liw, lit in zip(lineout_intros_won, lineout_intros_total)]

    # Lineout intro consistency: 100% = +0, 0% = -1 (linear scaling)
    lineout_intro_consistency = [(lip - 100) / 100 for lip in lineout_intro_pct]  # -1 at 0%
    consistency_rating = [cr + lic for cr, lic in zip(consistency_rating, lineout_intro_consistency)]

    # 4. Mod game plus/minus consistency
    mod_plus = df.get('mod_game_plus', [0] * len(df))
    mod_minus = df.get('mod_game_minus', [0] * len(df))
    total_mod = [mp + mm for mp, mm in zip(mod_plus, mod_minus)]

    mod_ratio = [mp / tm if tm > 0 else 0.5 for mp, tm in zip(mod_plus, total_mod)]  # 0.5 = neutral

    # Mod game consistency: -0.4 per 0.1 below 0.5, 0 at 0.5, positive values above 0.5 are ignored (no bonus)
    mod_consistency = [(mr - 0.5) * 4 if mr < 0.5 else 0 for mr in mod_ratio]  # -0.4 per 0.1 below 0.5
    consistency_rating = [cr + mc for cr, mc in zip(consistency_rating, mod_consistency)]

    # 5. Aerial duel consistency
    aerial_won = df.get('aerial_duels_won', [0] * len(df))
    aerial_lost = df.get('aerial_duels_lost', [0] * len(df))
    total_aerial = [aw + al for aw, al in zip(aerial_won, aerial_lost)]

    aerial_pct = [(aw / ta) * 100 if ta > 0 else 100 for aw, ta in zip(aerial_won, total_aerial)]

    # Aerial consistency: 100% = +0, 0% = -1 (linear scaling)
    aerial_consistency = [(ap - 100) / 100 for ap in aerial_pct]  # -1 at 0%
    consistency_rating = [cr + ac for cr, ac in zip(consistency_rating, aerial_consistency)]

    # 6. Offload consistency
    offloads_good = df.get('offloads_good', [0] * len(df))
    offloads_bad = df.get('offloads_bad', [0] * len(df))
    total_offloads = [og + ob for og, ob in zip(offloads_good, offloads_bad)]

    offload_pct = [(og / to) * 100 if to > 0 else 100 for og, to in zip(offloads_good, total_offloads)]

    # Offload consistency: 100% = +0, 0% = -1 (linear scaling)
    offload_consistency = [(op - 100) / 100 for op in offload_pct]  # -1 at 0%
    consistency_rating = [cr + oc for cr, oc in zip(consistency_rating, offload_consistency)]

    # 7. Carries with gain consistency
    carries_with_gain = df.get('carries_with_gain', [0] * len(df))
    carries_without_gain = df.get('carries_without_gain', [0] * len(df))
    total_carries = [cwg + cwog for cwg, cwog in zip(carries_with_gain, carries_without_gain)]

    carry_pct = [(cwg / tc) * 100 if tc > 0 else 100 for cwg, tc in zip(carries_with_gain, total_carries)]

    # Carry consistency: +0 if >=50%, -0.2 per 10% below 50%
    carry_consistency = [0 if cp >= 50 else ((cp - 50) // 10) * 0.2 for cp in carry_pct]
    consistency_rating = [cr + cc for cr, cc in zip(consistency_rating, carry_consistency)]

    # 8. Penalty for mistakes (fixed penalties)
    total_penalties = df.get('total_penalties', [0] * len(df))
    knock_ons = df.get('knock_on', [0] * len(df))
    other_mistakes = df.get('other_mistakes', [0] * len(df))

    # Fixed penalties: -0.3 per penalty, -0.4 per knock-on, -0.2 per other mistake
    # Exponential penalty for total_penalties, linear for others
    mistake_penalty = [pow(1.5, tp) - 1 + ko * 0.4 + om * 0.2 for tp, ko, om in zip(total_penalties, knock_ons, other_mistakes)]
    consistency_rating = [cr - mp for cr, mp in zip(consistency_rating, mistake_penalty)]

    #  Only adjust scores outside 1-10 range (don't change scores already in range)
    consistency_rating = [max(1, min(10, cr)) for cr in consistency_rating]

    return [round(cr, 2) for cr, valid in zip(consistency_rating, valid_players) if valid]

def calculate_weighted_overall_rating(df):
    """
    Calculate weighted overall rating for all players:
    - Attack & Defense: 35% each
    - Work Rate & Consistency: 10% each
    - Discipline & Skills: 5% each

    Args:
        df: DataFrame with player statistics

    Returns:
        Series of weighted overall ratings (1-10 scale)
    """
    # Filter out players with 0 minutes
    valid_players = df['minutes'] > 0

    # Calculate all individual ratings (these return filtered arrays)
    attack_ratings = calculate_attack_rating(df)
    defense_ratings = calculate_defense_rating(df)
    discipline_ratings = calculate_discipline_rating(df)
    work_rate_ratings = calculate_work_rate_rating(df)
    skills_ratings = calculate_skills_rating(df)
    consistency_ratings = calculate_consistency_rating(df)

    # Calculate weighted overall ratings for valid players only
    overall_ratings = []
    valid_index = 0
    for i in range(len(df)):
        if valid_players.iloc[i]:
            # Use the valid_index to access the filtered rating arrays
            overall_rating = (attack_ratings[valid_index] * 0.35 + defense_ratings[valid_index] * 0.35 +
                            work_rate_ratings[valid_index] * 0.10 + consistency_ratings[valid_index] * 0.10 +
                            discipline_ratings[valid_index] * 0.05 + skills_ratings[valid_index] * 0.05)
            overall_ratings.append(round(overall_rating, 2))
            valid_index += 1
        else:
            overall_ratings.append(float('nan'))

    return overall_ratings

def calculate_player_ratings_from_json(json_data):
    """
    Main function to calculate ratings from JSON input and return JSON output

    Args:
        json_data: JSON string containing player statistics

    Returns:
        JSON string with calculated ratings for each player
    """
    try:
        # Parse input JSON
        data = json.loads(json_data)

        # Convert to DataFrame
        df = pd.DataFrame(data)

        # Calculate all ratings
        attack_ratings = calculate_attack_rating(df)
        defense_ratings = calculate_defense_rating(df)
        discipline_ratings = calculate_discipline_rating(df)
        work_rate_ratings = calculate_work_rate_rating(df)
        skills_ratings = calculate_skills_rating(df)
        consistency_ratings = calculate_consistency_rating(df)
        overall_ratings = calculate_weighted_overall_rating(df)

        # Prepare results
        results = []
        valid_players = df['minutes'] > 0
        valid_indices = [i for i, valid in enumerate(valid_players) if valid]

        for i, player_idx in enumerate(valid_indices):
            results.append({
                'player_index': player_idx,
                'attack_rating': attack_ratings[i],
                'defense_rating': defense_ratings[i],
                'discipline_rating': discipline_ratings[i],
                'work_rate_rating': work_rate_ratings[i],
                'skills_rating': skills_ratings[i],
                'consistency_rating': consistency_ratings[i],
                'overall_rating': overall_ratings[player_idx]
            })

        return json.dumps(results)

    except Exception as e:
        return json.dumps({'error': str(e)})

if __name__ == "__main__":
    # Read JSON from stdin
    input_data = sys.stdin.read()
    result = calculate_player_ratings_from_json(input_data)
    print(result)
