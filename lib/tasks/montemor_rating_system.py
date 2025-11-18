import pandas as pd
import json
import sys

def calculate_discipline_rating(df):
    """
    Description:
        Computes a discipline rating for each player on a 1-10 scale, with 10 representing perfect discipline. 
        The rating begins at 10 and deducts points based on penalties, mistakes, knock ons, and cards, 
        taking into account both the frequency and severity of infractions. Adjustments are made for 
        playing time, so disciplinary actions have a greater impact for players who play fewer minutes. 
        Larger deductions are issued for yellow and red cards.

    Calculates the discipline rating for each player based on penalties and errors, using a deduction system starting from 10.

    The rating is time-adjusted (greater impact for penalties/errors in shorter playing times) and deductions are weighted:
      - Penalties (attack & defense): Deducted using a non-linear (sqrt) scaling and higher weight.
      - Mistakes (attack & defense): Lower weight.
      - Knock ons: Moderate deduction.
      - Yellow/Red cards: Large fixed deductions.

    Players with 0 minutes played are excluded from the returned ratings.

    Args:
        df (pd.DataFrame): Player statistics, expected to include columns:
            - 'minutes'
            - 'attack_penalties'
            - 'defense_penalties'
            - 'error_made_attack'
            - 'error_made_defense'
            - 'knock_on'
            - 'yellow_cards'
            - 'red_cards'

    Returns:
        List[float]: Discipline ratings (1-10 scale) for players with minutes > 0
    """
    # Filter out players with 0 minutes
    valid_players = df['minutes'] > 0
    minutes = df['minutes']
    
    # Start everyone at 10 (perfect discipline)
    discipline_rating = [10.0] * len(df)
    
    # Penalty deductions (time-adjusted)
    time_multiplier = [1.5 if m <= 20 else (1.3 if m <= 40 else (1.0 if m <= 80 else 1.0)) for m in minutes]
    
    # Different penalty weights
    total_penalties = df.get('attack_penalties', [0] * len(df)) + df.get('defense_penalties', [0] * len(df))
    total_mistakes = df.get('error_made_attack', [0] * len(df)) + df.get('error_made_defense', [0] * len(df))
    knock_ons = df.get('knock_on', [0] * len(df))
    yellow_cards = df.get('yellow_cards', [0] * len(df))
    red_cards = df.get('red_cards', [0] * len(df))
    
    # Calculate deductions (time-adjusted)
    # More serious penalties have higher deductions
    total_penalty_deduction = [pow(tp, 1.5) * 0.8 * tm for tp, tm in zip(total_penalties, time_multiplier)]
    mistake_deduction = [tm_val * 0.1 * tm for tm_val, tm in zip(total_mistakes, time_multiplier)]
    knock_on_deduction = [ko * 0.2 * tm for ko, tm in zip(knock_ons, time_multiplier)]
    yellow_card_deduction = [yc * 1.5 for yc in yellow_cards]
    red_card_deduction = [rc * 3.0 for rc in red_cards]
    
    # Apply deductions
    discipline_rating = [dr - tpd - md - kod - ycd - rcd 
                        for dr, tpd, md, kod, ycd, rcd in 
                        zip(discipline_rating, total_penalty_deduction, mistake_deduction, knock_on_deduction, yellow_card_deduction, 
                            red_card_deduction)]
    
    # Ensure ratings stay within 1-10 range
    discipline_rating = [max(1, min(10, dr)) for dr in discipline_rating]
    
    # Only return ratings for players with valid minutes (exclude others)
    return [dr for dr, valid in zip(discipline_rating, valid_players) if valid]

def calculate_defense_rating(df):
    """
    Description:
        Computes a 1-10 defense rating for each player based on tackle performance (success, quantity, and impact), including bonuses for turnovers and interceptions and deductions for penalties and missed tackles.

    Calculate defense rating for players based on tackle performance (success, quantity, and impact), with bonuses for turnovers and interceptions, and deductions for penalties and missed tackles.

    Args:
        df: DataFrame containing player statistics. Required columns:
            - 'minutes'
            - 'neutral_tackles'
            - 'offensive_tackles'
            - 'defensive_tackles'
            - 'assist_tackles'
            - 'missed_tackles'
            - 'turnovers_won'
            - 'interceptions_made'
            - 'defense_penalties'

    Returns:
        List[float]: Defense ratings (1-10 scale) for players with minutes > 0
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
    tackle_impact = [((ot * 1.5 + nt * 1.0 + dt * 0.3 + at * 1.2) / (tt * 1.5)) if tt > 0 else 0
                     for ot, nt, dt, at, tt in zip(df.get('offensive_tackles', [0] * len(df)),
                                                   df.get('neutral_tackles', [0] * len(df)),
                                                   df.get('defensive_tackles', [0] * len(df)),
                                                   df.get('assist_tackles', [0] * len(df)),
                                                   total_tackles)]
    
    # Calculate base defense rating components (1-10 scale)
    # Tackle success rate: 0% = 1 rating, 100% = 10 rating
    tackle_success_rating = [10.0 if tsr >= 1.0 else tsr * 10 for tsr in tackle_success_rate]
    tackle_success_rating = [max(1, tsr) for tsr in tackle_success_rating]
    
    # Tackle impact: normalize to 1-10 scale (using absolute values)
    tackle_impact_rating = [10.0 if ti >= 1 else ti * 10.0 for ti in tackle_impact]
    tackle_impact_rating = [max(1, tir) for tir in tackle_impact_rating]
    
    # Total tackles rating: normalize to 1-10 scale (using absolute values)
    total_tackles_rating = [10.0 if tt >= 15 else (tt/15) * 10 for tt in total_tackles]
    total_tackles_rating = [max(1, ttr) for ttr in total_tackles_rating]
    
    # Calculate bonuses (time-adjusted)
    time_multiplier = [1.5 if m <= 20 else (1.3 if m <= 40 else (1.0 if m <= 80 else 1.0)) for m in minutes]
    
    # Recoveries bonuses (time-adjusted)
    turnovers_won = df.get('turnovers_won', [0] * len(df))
    interceptions_made = df.get('interceptions_made', [0] * len(df))
    recoveries_made = [tw + im for tw, im in zip(turnovers_won, interceptions_made)]
    recoveries_bonus = [rm * 1 * tm for rm, tm in zip(recoveries_made, time_multiplier)]
    
    # Offside penalty bonuses (time-adjusted)
    defense_penalties = df.get('defense_penalties', [0] * len(df))
    penalty_bonus = [op * -0.75 * tm for op, tm in zip(defense_penalties, time_multiplier)]

    # Missed tackles penalties (time-adjusted)
    # Use the already processed missed_tackles (with NaN handling)
    missed_tackle_penalty = [mt * -0.5 * tm for mt, tm in zip(missed_tackles, time_multiplier)]

    # Other mistakes penalties (time-adjusted)
    error_made_defense = df.get('error_made_defense', [0] * len(df))
    error_force_defense = df.get('error_force_defense', [0] * len(df))
    error_defense_penalty = [(ema * -0.25) + (efd * 0.25)    * tm for ema, efd, tm in zip(error_made_defense, error_force_defense, time_multiplier)]

    # Total bonus points
    total_bonus = [rb + ob + mtp + edp for rb, ob, mtp, edp in 
                  zip(recoveries_bonus, penalty_bonus, missed_tackle_penalty, error_defense_penalty)]
    
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
    base_defense_rating = [ttr * 0.65 + tsr * 0.15 + tir * 0.20 
                          for ttr, tsr, tir in zip(total_tackles_rating, tackle_success_rating, tackle_impact_rating)]
    
    # Base defense rating with bonuses
    base_defense_rating_with_bonuses = [bdr + tb for bdr, tb in zip(base_defense_rating, total_bonus)]
    
    # Calculate defense relative score (fixed 10% weight)
    # Fixed weights for defensive stats only
    defense_weights = {
        'total_tackles': 0.5,
        'tackle_success_rate': 0.3,
        'tackle_impact': 0.3,
        'recoveries_made': 0.1,
        'defense_penalties': -0.1,
        'error_force_defense': 0.05,
        'missed_tackles': -0.1,
        'error_made_defense': -0.05
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
    return [dr for dr, valid in zip(defense_rating, valid_players) if valid]

def calculate_attack_rating(df):
    """
    Description:
        Computes a 1-10 attack rating for each player based on per-minute carry performance and percentage of carries with gain,
        with reliability adjustment for playing time and relative scoring compared to peers. Integrates both efficiency and
        volume, rewarding effective attacking contributions and stabilizing short-game outliers.

    Calculates the attack rating for each player based on carry statistics, with adjustments for playtime reliability and integrated relative scoring.

    The attack rating is based on:
      - Carries with gain per minute (weighted for efficiency)
      - Neutral gain, loss carries, and total carries per minute
      - Percentage of carries with gain
      - Reliability adjustment: Players with fewer minutes are regressed toward the team average, increasing rating stability
      - Integrated relative scoring: Top performers in key carry stats receive additional recognition compared to peers

    Players with 0 minutes played are excluded from returned ratings.

    Args:
        df (pd.DataFrame): Player statistics DataFrame. Expected columns:
            - 'minutes'
            - 'carries_with_gain'
            - 'carries_neutral_gain'
            - 'carries_without_gain'

    Returns:
        List[float]: Attack ratings (1-10 scale) for players with minutes > 0
    """
    # Filter out players with 0 minutes
    valid_players = df['minutes'] > 0
    minutes = df['minutes']
    
    # Per-minute stats for the 3 main carry stats only
    # Use minimum of 10 minutes for per-minute calculations
    carries_with_gain_per_min = df['carries_with_gain'] / minutes
    carries_neutral_gain_per_min = df['carries_neutral_gain'] / minutes
    carries_without_gain_per_min = df['carries_without_gain'] / minutes

    # Calculate total carries per minute
    total_carries_per_min = carries_with_gain_per_min + carries_without_gain_per_min + carries_neutral_gain_per_min
    diff_carries_per_min = carries_with_gain_per_min + carries_neutral_gain_per_min - carries_without_gain_per_min
    
    # Calculate percentage of carries with gain
    carry_percentage = [((dcppm / tcpm) * 100) if tcpm > 0 else 0 
                       for dcppm, tcpm in zip(diff_carries_per_min, total_carries_per_min)]
    
    # Rate total carries per minute (0-10 scale)
    # 0.1875 per min = 15 carries in 80 min = 10 rating
    total_carries_rating = [10.0 if tcpm >= 0.1875 else (tcpm / 0.1875) * 10 
                           for tcpm in total_carries_per_min]
    total_carries_rating = [max(1, tcr) for tcr in total_carries_rating]

    # Rate carries with gain per minute (0-10 scale)
    # 0.05 per min = 4 carries in 80 min = 10 rating
    carries_with_gain_rating = [10.0 if cgpm >= 0.05 else (cgpm / 0.05) * 10 
                               for cgpm in carries_with_gain_per_min]
    carries_with_gain_rating = [max(1, cgr) for cgr in carries_with_gain_rating]

    # Rate carry percentage (0-10 scale)
    # 0% = 0 rating, 50%+ = 10 rating
    carry_percentage_rating = [10.0 if cp >= 50 else (cp / 50) * 10 for cp in carry_percentage]
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
    # 60% total carries, 25% carries with gain, 15% carry percentage
    base_attack_rating = [tcr * 0.60 + cgr * 0.25 + cpr * 0.15 
                         for tcr, cgr, cpr in zip(total_carries_rating, carries_with_gain_rating, carry_percentage_rating)]
    
    # Calculate time-adjusted bonus points
    # <=20 min = 1.5x, <=40 min = 1.3x, >40 min = 1.0x
    time_multiplier = [1.5 if m <= 20 else (1.3 if m <= 40 else 1.0) for m in minutes]

    # Pass bonus calculation (+0.1 for each Passe +, -0.2 for each Passe -)
    passes_good = df.get('passes_good', [0] * len(df))
    passes_bad = df.get('passes_bad', [0] * len(df))
    pass_bonus = [(pg * 0.05 - pb * 0.1) * tm for pg, pb, tm in zip(passes_good, passes_bad, time_multiplier)]
    
    # Time-adjusted bonuses for tries, assists, linebreaks, mod game plues
    try_bonus = [t * 1.0 * tm for t, tm in zip(df['tries'], time_multiplier)]
    assist_bonus = [a * 0.6 * tm for a, tm in zip(df['assists'], time_multiplier)]
    linebreak_bonus = [l * 0.4 * tm for l, tm in zip(df['linebreak'], time_multiplier)]
    linebreak_assists = df.get('linebreak_assists', [0] * len(df))
    linebreak_assist_bonus = [la * 0.4 * tm for la, tm in zip(linebreak_assists, time_multiplier)]
    defenders_beaten_bonus = [db * 0.1 * tm for db, tm in zip(df['defenders_beaten'], time_multiplier)]
    
    # Offload bonuses/penalties (time-adjusted)
    offloads_good = df.get('offloads_good', [0] * len(df))
    offloads_bad = df.get('offloads_bad', [0] * len(df))
    offload_bonus = [(og * 0.4 - ob * 0.2) * tm for og, ob, tm in zip(offloads_good, offloads_bad, time_multiplier)]
    
    # Mistake penalties (time-adjusted)
    knock_on = df.get('knock_on', [0] * len(df))
    turnover_loss = df.get('turnover_loss', [0] * len(df))
    penalty_attack_made = df.get('attack_penalties', [0] * len(df))
    error_made_attack = df.get('error_made_attack', [0] * len(df))
    interception_suffered = df.get('interception_suffered', [0] * len(df))
    mistake_penalty = [(ko * -0.5 + tl * -0.4 + pam * -0.6 + ema * -0.3 + inter * -0.4) * tm for ko, tl, pam, ema, inter, tm in zip(knock_on, turnover_loss, penalty_attack_made, error_made_attack, interception_suffered, time_multiplier)]
    
    # Mod game bonuses/penalties
    mod_game_plus = df.get('mod_game_plus', [0] * len(df))
    mod_game_minus = df.get('mod_game_minus', [0] * len(df))
    mod_game_bonus = [((mgp - mgm)* 0.3) * tm for mgp, mgm, tm in zip(mod_game_plus, mod_game_minus, time_multiplier)]
    
    # Pick and go bonuses/penalties
    pick_and_go_plus = df.get('pick_and_go_plus', [0] * len(df))
    pick_and_go_minus = df.get('pick_and_go_minus', [0] * len(df))
    pick_and_go_bonus = [((pgp - pgm)* 0.1) * tm for pgp, pgm, tm in zip(pick_and_go_plus, pick_and_go_minus, time_multiplier)]
    
    # Conversion/kick bonuses (made = +0.2, missed = -0.2)
    conversions_made = df.get('conversions_made', [0] * len(df))
    conversions_attempted = df.get('conversions_attempted', [0] * len(df))
    conversions_missed = [ca - cm for ca, cm in zip(conversions_attempted, conversions_made)]
    
    # Kick at goal bonuses/penalties
    kick_at_goal_made = df.get('kicks_at_goal_made', [0] * len(df))
    kick_at_goal_attempted = df.get('kicks_at_goal_attempted', [0] * len(df))
    kick_at_goal_missed = [ka - km for ka, km in zip(kick_at_goal_attempted, kick_at_goal_made)]
    
    # Drops bonuses/penalties
    drops_made = df.get('drops_made', [0] * len(df))
    drops_attempted = df.get('drops_attempted', [0] * len(df))
    drops_missed = [da - dm for da, dm in zip(drops_attempted, drops_made)]
    
    # Absolute kick bonuses (no time adjustment)
    # Conversions made/missed: 0.2, others: 0.3
    kick_bonus = [
        (cm * 0.2) + (cms * -0.2) + (km * 0.3) + (kms * -0.3) + (dm * 0.3) + (dms * -0.3)
        for cm, cms, km, kms, dm, dms in zip(conversions_made, conversions_missed, kick_at_goal_made, kick_at_goal_missed, drops_made, drops_missed)
    ]

    # Kick in game bonuses/penalties
    kick_good = df.get('kicks_good', [0] * len(df))
    kick_bad  = df.get('kicks_bad', [0] * len(df))
    kick_pass = df.get('kicks_pass', [0] * len(df))
    kick_in_game_bonus = [(kg * 0.2 + kp * 0.3 - kb * 0.1) * tm for kg, kp, kb, tm in zip(kick_good, kick_pass, kick_bad, time_multiplier)]

    # Ruck bonuses/penalties
    ruck_hit = df.get('rucks_seal', [0] * len(df)) + df.get('rucks_clear', [0] * len(df))
    ruck_lost = df.get('rucks_lost', [0] * len(df))
    ruck_bonus = [(rh * 0.05 - rl * 0.4) * tm for rh, rl, tm in zip(ruck_hit, ruck_lost, time_multiplier)]

    # Lineout success: +0.1 per successful lineout (up to 2.0 max)
    lineouts_won = df.get('lineouts_won', [0] * len(df))
    lineouts_lost = df.get('lineouts_lost', [0] * len(df))
    lineout_success_points = [min(lw * 0.2 - ll * 0.5, 2.0) for lw, ll in zip(lineouts_won, lineouts_lost)]
    
    # Lineout introduction bonuses/penalties
    lineout_intros_won = df.get('lineout_intros_won', [0] * len(df))
    lineout_intros_lost = df.get('lineout_intros_lost', [0] * len(df))
    lineout_intro_points = [min(liw * 0.2 - lil * 0.5, 2.0) for liw, lil in zip(lineout_intros_won, lineout_intros_lost)]
    
    # Total bonus points
    total_bonus = [tb + ab + lb + db + ob + mp + kb + pbv + kigb + ruckb + lsp + mgb + pgb + lbb + lip
                   for tb, ab, lb, db, ob, mp, kb, pbv, kigb, ruckb, lsp, mgb, pgb, lbb, lip in 
                   zip(try_bonus, assist_bonus, linebreak_bonus, defenders_beaten_bonus, 
                       offload_bonus, mistake_penalty, kick_bonus, pass_bonus, kick_in_game_bonus, ruck_bonus, lineout_success_points, mod_game_bonus, pick_and_go_bonus, linebreak_assist_bonus, lineout_intro_points)]
    
    # Base attack rating with bonuses
    base_attack_rating_with_bonuses = [bar + tb for bar, tb in zip(base_attack_rating, total_bonus)]
    
    # Calculate attack relative score (fixed 10% weight)
    # Fixed weights for attacking stats only (excluding kicking)
    attack_weights = {
        'total_carries': 0.4,
        'carries_with_gain': 0.2,
        'carry_percentage': 0.2,
        'tries': 0.1,
        'assists': 0.10,
        'linebreak': 0.10,
        'offloads_good': 0.05,
        'offloads_bad': -0.05,  # Negative weight for bad offloads
        'knock_on': -0.05,
        'attack_penalties': -0.1,
        'passes_good': 0.1,
        'passes_bad': -0.1,
        'kick_in_game_bonus': 0.1,
        'ruck_hit': 0.1,
        'ruck_lost': -0.1,
        'error_made_attack': -0.05,
    }
    
    # Filter valid players for relative scoring
    valid_players_rel = df['minutes'] > 0
    df_valid_rel = df[valid_players_rel].copy()
    
    # Calculate derived fields needed for relative scoring
    if len(df_valid_rel) > 0:
        # Calculate diff_carries (absolute, not per-minute)
        carries_with_gain_rel = df_valid_rel['carries_with_gain'].fillna(0)
        carries_neutral_rel = df_valid_rel.get('carries_neutral_gain', pd.Series([0] * len(df_valid_rel))).fillna(0)
        carries_without_gain_rel = df_valid_rel['carries_without_gain'].fillna(0)
        df_valid_rel['diff_carries'] = carries_with_gain_rel + carries_neutral_rel - carries_without_gain_rel
        
        # Carry percentage already calculated above, add to valid players
        valid_carry_pct = [cp for cp, valid in zip(carry_percentage, valid_players_rel) if valid]
        df_valid_rel['carry_percentage'] = valid_carry_pct
        
        # Kick bonuses (already calculated above, need to extract for valid players)
        valid_kick_bonus = [kb for kb, valid in zip(kick_bonus, valid_players_rel) if valid]
        df_valid_rel['kick_bonus'] = valid_kick_bonus
        
        valid_kick_in_game_bonus = [kigb for kigb, valid in zip(kick_in_game_bonus, valid_players_rel) if valid]
        df_valid_rel['kick_in_game_bonus'] = valid_kick_in_game_bonus
        
        # Ruck stats (already calculated above)
        valid_ruck_hit = [rh for rh, valid in zip(ruck_hit, valid_players_rel) if valid]
        df_valid_rel['ruck_hit'] = valid_ruck_hit
        
        valid_ruck_lost = [rl for rl, valid in zip(ruck_lost, valid_players_rel) if valid]
        df_valid_rel['ruck_lost'] = valid_ruck_lost
        
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
    return [ar for ar, valid in zip(attack_rating, valid_players) if valid]

def calculate_work_rate_rating(df):
    """
    Description:
        Computes a 1-10 work rate rating for each player, reflecting their overall activity by aggregating various action counts per minute (carries, tackles, turnovers, rucks, passes, kicks, offloads, and linebreaks) and applying reliability and min-max normalization for valid players.

    Calculates the work rate rating for each player based on the absolute sum of various action counts including carries, tackles, turnovers, rucks, passes, kicks, offloads, and linebreaks.

    Actions included in the rating (absolute counts):
      - Carries: carries_with_gain + carries_without_gain
      - Tackles: offensive_tackles, neutral_tackles, defensive_tackles, assist_tackles
      - Turnovers won and interceptions suffered
      - Ruck actions: rucks_seal + rucks_clear
      - Passes: passes_good + kicks_pass
      - Kicks: kicks_in_game_good
      - Offloads: offloads_good
      - Linebreaks: linebreak

    The base work rate is calculated as the sum of these actions per minute for each player. Scores are min-max normalized to a 1-10 scale among valid players (minutes > 0), and lightly reliability-adjusted using a factor of N/(N+20) where N is minutes played.

    Returns:
        List[float]: Work rate ratings (1-10 scale) for players with minutes > 0.
    """
    # Filter out players with 0 minutes
    valid_players = df['minutes'] > 0
    minutes = df['minutes']

    # Carries
    carries_with_gain = df.get('carries_with_gain', [0] * len(df))
    carries_neutral_gain = df.get('carries_neutral_gain', [0] * len(df))
    carries_without_gain = df.get('carries_without_gain', [0] * len(df))
    total_carries = [cwg + cng + (cwng * 0.2) for cwg, cng, cwng in zip(carries_with_gain, carries_neutral_gain, carries_without_gain)]

    # Tackles
    offensive_tackles = df.get('offensive_tackles', [0] * len(df))
    neutral_tackles = df.get('neutral_tackles', [0] * len(df))
    assist_tackles = df.get('assist_tackles', [0] * len(df))
    defensive_tackles = df.get('defensive_tackles', [0] * len(df))
    total_tackles = [ot + nt + at + dt * 0.2 for ot, nt, at, dt in zip(offensive_tackles, neutral_tackles, assist_tackles, defensive_tackles)]

    # Rucks
    rucks_seal = df.get('rucks_seal', [0] * len(df))
    rucks_clear = df.get('rucks_clear', [0] * len(df))
    total_rucks_hit = [rs + rc for rs, rc in zip(rucks_seal, rucks_clear)]

    # Turnovers and interceptions
    turnovers_won = df.get('turnovers_won', [0] * len(df))
    interceptions_made = df.get('interceptions_made', [0] * len(df))
    total_turnovers_and_interceptions = [tw + im for tw, im in zip(turnovers_won, interceptions_made)]

    # Passes
    passes_good = df.get('passes_good', [0] * len(df))
    kick_pass = df.get('kicks_pass', [0] * len(df))
    linebreak_assists = df.get('linebreak_assists', [0] * len(df))
    total_passes = [(pg + kp) * 0.5 + la * 1 for pg, kp, la in zip(passes_good, kick_pass, linebreak_assists)]

    # Kicks
    kicks_in_game_good = df.get('kicks_in_game_good', [0] * len(df))
    total_kicks = [kig * 0.5 for kig in kicks_in_game_good]

    #Offloads
    offloads_good = df.get('offloads_good', [0] * len(df))
    total_offloads = [og for og in offloads_good]

    #Linebreaks
    linebreaks = df.get('linebreak', [0] * len(df))
    total_linebreaks = [lb for lb in linebreaks]

    # Pick and go
    pick_and_go = df.get('pick_and_go_plus', [0] * len(df))

    # BASE: total number of actions (absolute)
    total_actions = [tc + tt + tti + trh + tp + tk + to + lb + pg for tc, tt, tti, trh, tp, tk, to, lb, pg in 
    zip(total_carries, total_tackles, total_turnovers_and_interceptions, total_rucks_hit, total_passes, total_kicks, total_offloads, total_linebreaks, pick_and_go)]

    # Reliability adjustment on absolute actions
    reliability = [m / (m + 20) if m > 0 else 0 for m in minutes]
    total_actions_valid = [ta for ta, valid in zip(total_actions, valid_players) if valid]
    minutes_valid = [m for m, valid in zip(minutes, valid_players) if valid]
    actions_per_minute = [ta / m if m > 0 else 0 for ta, m in zip(total_actions_valid, minutes_valid)]
    team_avg_actions_per_minute = sum(actions_per_minute) / len(actions_per_minute) if actions_per_minute else 0
    reliability_valid = [r for r, valid in zip(reliability, valid_players) if valid]
    actions_adj = [am * r + team_avg_actions_per_minute * (1 - r) + team_avg_actions_per_minute * (1 - r) for am, r in zip(actions_per_minute, reliability_valid)]

    # Absolute rating: 40 total actions => 10
    abs_rating = [max(1, (aa / 0.5) * 10.0) for aa in actions_adj] # 30 actions / 80 minutes = 0.375 actions per minute

    # Clamp to 1-7.5
    work_rate_rating = [max(1, min(7.5, ar)) for ar in abs_rating]
    
    # Get bonuses/penalties and filter to only valid players
    extra_wr_bonus_all = df.get('extra_wr_bonus', pd.Series([0] * len(df)))
    extra_wr_penalty_all = df.get('extra_wr_penalty', pd.Series([0] * len(df)))
    
    # Convert to list if Series, ensure it's the right length
    if isinstance(extra_wr_bonus_all, pd.Series):
        extra_wr_bonus_all = extra_wr_bonus_all.fillna(0).tolist()
    if isinstance(extra_wr_penalty_all, pd.Series):
        extra_wr_penalty_all = extra_wr_penalty_all.fillna(0).tolist()
    
    # Filter bonuses/penalties to only valid players
    extra_wr_bonus_valid = [ewb for ewb, valid in zip(extra_wr_bonus_all, valid_players) if valid]
    extra_wr_penalty_valid = [ewp for ewp, valid in zip(extra_wr_penalty_all, valid_players) if valid]
    
    # Apply bonuses/penalties (now all arrays have the same length)
    work_rate_rating = [wrr + ewb * 0.5 - ewp * 1 for wrr, ewb, ewp in zip(work_rate_rating, extra_wr_bonus_valid, extra_wr_penalty_valid)]

    # Clamp to 1-10
    work_rate_rating = [max(1, min(10, wrr)) for wrr in work_rate_rating]
    
    return work_rate_rating
    
def calculate_skills_rating(df):
    """
    Description:
        Computes a skills rating (1-10 scale) for each player, starting from 5 and adjusting based on key technical and attacking skill statistics. Points are awarded or deducted for actions such as successful or missed kicks, offloads, linebreaks, passes, and kicks in play. Each type of action is weighted, and ratings are clamped to the 1-10 scale. Only players with minutes played are evaluated.

    Calculates the skills rating for each player, combining key technical and attacking skills using a point-based system.

    The rating starts at 5 and is adjusted up or down based on positive and negative skill actions:
      - Kicking (conversions, penalties, drops): Rewards for successful kicks, penalties for missed attempts.
      - Offloads: Rewards for successful offloads, penalties for poor offloads.
      - Linebreaks and defenders beaten: Rewards for impactful attacking actions.
      - Passing and kicking in game: Rewards for accurate/good decisions, penalties for mistakes.
    
    Each statistic is weighted, and all point adjustments are combined.  
    The final score is clamped to the 1-10 scale.

    Players with 0 minutes played are excluded from the returned ratings.

    Args:
        df (pd.DataFrame): Player statistics DataFrame. Expected columns (not all are required):
            - 'minutes'
            - 'conversions_made', 'conversions_attempted'
            - 'kicks_made', 'kicks_attempted'
            - 'drops_made', 'drops_attempted'
            - 'offloads_good', 'offloads_bad'
            - 'linebreak'
            - 'defenders_beaten'
            - 'passes_good', 'passes_bad'
            - 'kicks_in_game_good', 'kicks_in_game_bad'

    Returns:
        List[float]: Skills ratings (1-10 scale) for players with minutes > 0
    """
    valid_players = df['minutes'] > 0
    
    # Start everyone at 5
    skills_rating = [5.0] * len(df)
    
    # Kicking bonuses/penalties
    conv_made = df.get('conversions_made', [0] * len(df))
    conv_att = df.get('conversions_attempted', [0] * len(df))
    pen_made = df.get('kicks_made', [0] * len(df))
    pen_att = df.get('kicks_attempted', [0] * len(df))
    drop_made = df.get('drops_made', [0] * len(df))
    drop_att = df.get('drops_attempted', [0] * len(df))
    
    # Conversion points: +0.2 per made, -0.2 per missed
    conv_points = [cm * 0.2 - (ca - cm) * 0.2 for cm, ca in zip(conv_made, conv_att)]
    skills_rating = [sr + cp for sr, cp in zip(skills_rating, conv_points)]
    
    # Penalty points: +0.3 per made, -0.3 per missed
    pen_points = [pm * 0.3 - (pa - pm) * 0.3 for pm, pa in zip(pen_made, pen_att)]
    skills_rating = [sr + pp for sr, pp in zip(skills_rating, pen_points)]
    
    # Drop points: +0.5 per made, -0.3 per missed
    drop_points = [dm * 0.5 - (da - dm) * 0.3 for dm, da in zip(drop_made, drop_att)]
    skills_rating = [sr + dp for sr, dp in zip(skills_rating, drop_points)]
    
    # Offloads: +0.4 per good, -0.2 per bad
    offloads_good = df.get('offloads_good', [0] * len(df))
    offloads_bad = df.get('offloads_bad', [0] * len(df))
    offload_points = [og * 0.4 - ob * 0.2 for og, ob in zip(offloads_good, offloads_bad)]
    skills_rating = [sr + op for sr, op in zip(skills_rating, offload_points)]
    
    # Linebreaks: +0.3 each
    linebreaks = df.get('linebreak', [0] * len(df))
    linebreak_assists = df.get('linebreak_assists', [0] * len(df))
    skills_rating = [sr + (lb + la) * 0.3 for sr, lb, la in zip(skills_rating, linebreaks, linebreak_assists)]
    
    # Defenders Beaten: +0.2 each
    defenders_beaten = df.get('defenders_beaten', [0] * len(df))
    skills_rating = [sr + db * 0.2 for sr, db in zip(skills_rating, defenders_beaten)]

    # Passes: +0.1 per good, -0.3 per bad
    passes_good = df.get('passes_good', [0] * len(df))
    passes_bad = df.get('passes_bad', [0] * len(df))
    pass_points = [pg * 0.1 - pb * 0.3 for pg, pb in zip(passes_good, passes_bad)]
    skills_rating = [sr + pp for sr, pp in zip(skills_rating, pass_points)]

    # Kicks in Game: +0.3 per good, -0.1 per bad
    kicks_in_game_good = df.get('kicks_in_game_good', [0] * len(df))
    kicks_in_game_bad = df.get('kicks_in_game_bad', [0] * len(df))
    kicks_in_game_points = [kig * 0.3 - kib * 0.1 for kig, kib in zip(kicks_in_game_good, kicks_in_game_bad)]
    skills_rating = [sr + kigp for sr, kigp in zip(skills_rating, kicks_in_game_points)]
    
    # Starting Drop Points: +0.2 per good, -0.2 per bad
    starting_drop_good = df.get('starting_drop_good', [0] * len(df))
    starting_drop_bad = df.get('starting_drop_bad', [0] * len(df))
    starting_drop_points = [sd * 0.3 - sb * 0.3 for sd, sb in zip(starting_drop_good, starting_drop_bad)]
    skills_rating = [sr + sdp for sr, sdp in zip(skills_rating, starting_drop_points)]
    
    # Turnovers won: +0.5 each
    turnovers_won = df.get('turnovers_won', [0] * len(df))
    turnovers_lost = df.get('turnovers_lost', [0] * len(df))
    turnover_points = [tw * 0.5 - tl * 0.5 for tw, tl in zip(turnovers_won, turnovers_lost)]
    skills_rating = [sr + tp for sr, tp in zip(skills_rating, turnover_points)]
    
    # Interceptions: +0.6 per good, -0.4 per bad
    interceptions_made = df.get('interceptions_made', [0] * len(df))
    interceptions_suffered = df.get('interception_suffered', [0] * len(df))
    interception_points = [im * 0.6 - isuf * 0.4 for isuf, im in zip(interceptions_suffered, interceptions_made)]
    skills_rating = [sr + ip for sr, ip in zip(skills_rating, interception_points)]
    
    # Aerial duels: +0.5 per won, -0.1 per lost
    aerial_won = df.get('aerial_duels_won', [0] * len(df))
    aerial_lost = df.get('aerial_duels_lost', [0] * len(df))
    aerial_receptions = df.get('aerial_receptions', [0] * len(df))
    aerial_points = [aw * 0.5 - al * 0.2 + ar * 0.2 for aw, al, ar in zip(aerial_won, aerial_lost, aerial_receptions)]
    skills_rating = [sr + ap for sr, ap in zip(skills_rating, aerial_points)]
    
    # Lineout success: +0.1 per successful lineout (up to 2.0 max)
    lineouts_won = df.get('lineouts_won', [0] * len(df))
    lineouts_lost = df.get('lineouts_lost', [0] * len(df))
    lineout_success_points = [min(lw * 0.2 - ll * 0.4, 2.0) for lw, ll in zip(lineouts_won, lineouts_lost)]
    skills_rating = [sr + lsp for sr, lsp in zip(skills_rating, lineout_success_points)]
    
    # Lineout introductions: +0.1 per successful intro (up to 2 max)
    lineout_intros_won = df.get('lineout_intros_won', [0] * len(df))
    lineout_intros_lost = df.get('lineout_intros_lost', [0] * len(df))
    lineout_intro_points = [min(liw * 0.2 - lil * 0.4, 2) for liw, lil in zip(lineout_intros_won, lineout_intros_lost)]
    skills_rating = [sr + lip for sr, lip in zip(skills_rating, lineout_intro_points)]
    
    # Mistakes and errors: penalties
    knock_ons = df.get('knock_on', [0] * len(df))
    total_mistakes = df.get('error_made_attack', [0] * len(df)) + df.get('error_made_defense', [0] * len(df))
    mistake_penalty = [ko * -0.4 + tm * -0.3 for ko, tm in zip(knock_ons, total_mistakes)]
    skills_rating = [sr + mp for sr, mp in zip(skills_rating, mistake_penalty)]
    
    # Only adjust scores outside 1-10 range (don't change scores already in range)
    skills_rating = [max(1, min(10, sr)) for sr in skills_rating]
    
    # Only return ratings for players with valid minutes (exclude others)
    return [sr for sr, valid in zip(skills_rating, valid_players) if valid]

def calculate_consistency_rating(df):
    """
    Description:
        Produces a 1-10 consistency rating for each player by combining skill execution rates (such as kicking, tackling, lineout introductions) and penalizing for mistakes, accounting for both positive contributions and errors. The system is designed to reflect overall reliability and execution quality, for each player with nonzero minutes.

    Calculates a consistency rating for each player based on a variety of skill execution rates and penalizes for mistakes, producing a score on a 1-10 scale.

    The rating formula starts each player at 10 and applies positive or negative adjustments based on the following:

    - Kicking consistency: Weighted accuracy percent for conversions, penalty kicks, and drops (lower accuracy reduces score).
    - Tackling consistency: Proportion of tackles made out of total attempts (lower success reduces score proportionally).
    - Lineout introduction consistency: Percentage of successful introductions (lower success reduces score).
    - (Further consistency factors, such as mod game plus/minus, aerial duel success, offload success, and carries with gain success may be included in future versions.)

    Penalties to the rating are also applied for:
    - Penalties committed
    - Knock-ons
    - Other mistakes (errors in attack or defense)

    The resulting score is capped between 1 and 10. Players with 0 minutes played are excluded.

    Args:
        df (pd.DataFrame): Player statistics DataFrame. Expected columns:
            - 'minutes'
            - Kicking columns: ['conversions_made', 'conversions_attempted', 'kicks_made', 'kicks_attempted', 'drops_made', 'drops_attempted']
            - Tackling columns: ['offensive_tackles', 'neutral_tackles', 'defensive_tackles', 'missed_tackles']
            - Lineout columns: ['lineout_intros_won', 'lineout_intros_total']
            - Mistake columns: ['error_made_attack', 'error_made_defense', 'knock_on']
            - Penalty columns as relevant

    Returns:
        List[float]: Consistency ratings (1-10 scale) for players with minutes > 0
    """
    valid_players = df['minutes'] > 0
    
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
    
    # Kicking consistency: 100% = +0, 0% = -2 (linear scaling)
    kicking_consistency = [(kp - 100) / 50 for kp in kicking_pct]  # -2 point at 0%
    consistency_rating = [cr + kc for cr, kc in zip(consistency_rating, kicking_consistency)]
    
    # 2. Tackling consistency
    tackles_made = [ot + nt + dt for ot, nt, dt in zip(df.get('offensive_tackles', [0] * len(df)), df.get('neutral_tackles', [0] * len(df)), df.get('defensive_tackles', [0] * len(df)))]
    tackles_missed = df.get('missed_tackles', [0] * len(df))
    # Handle NaN values in missed_tackles by converting to 0
    tackles_missed = [0 if pd.isna(tm) else tm for tm in tackles_missed]
    total_tackles = [tm + tms for tm, tms in zip(tackles_made, tackles_missed)]
    
    tackle_pct = [(tm / tt) * 100 if tt > 0 else 100 for tm, tt in zip(tackles_made, total_tackles)]
    
    # Tackling consistency: 100% = +0, 0% = -5 (linear scaling)
    tackle_consistency = [(tp - 100) / 20 for tp in tackle_pct]  # -5 at 0%
    consistency_rating = [cr + tc for cr, tc in zip(consistency_rating, tackle_consistency)]
    
    # 3. Lineout introductions consistency
    lineout_intros_won = df.get('lineout_intros_won', [0] * len(df))
    lineout_intros_total = df.get('lineout_intros_total', [0] * len(df))
    
    lineout_intro_pct = [(liw / lit) * 100 if lit > 0 else 100 for liw, lit in zip(lineout_intros_won, lineout_intros_total)]
    
    # Lineout intro consistency: 100% = +0, 0% = -2 (linear scaling)
    lineout_intro_consistency = [(lip - 100) / 50 for lip in lineout_intro_pct]  # -2 at 0%
    consistency_rating = [cr + lic for cr, lic in zip(consistency_rating, lineout_intro_consistency)]
    
    # 4. Passes consistency
    passes_good  = df.get('passes_good', [0] * len(df))
    passes_bad = df.get('passes_bad', [0] * len(df))
    total_passes = [pg + pb for pg, pb in zip(passes_good, passes_bad)]
    
    pass_pct = [(pg / tp) * 100 if tp > 0 else 100 for pg, tp in zip(passes_good, total_passes)]
    
    # Pass consistency: 100% = +0, 0% = -5 (linear scaling)
    pass_consistency = [(pp - 100) / 20 for pp in pass_pct]  # -5 at 0%
    consistency_rating = [cr + pc for cr, pc in zip(consistency_rating, pass_consistency)]
    
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
    
    # 8. Kick in Game consistency
    kicks_in_game_good = df.get('kicks_in_game_good', [0] * len(df))
    kicks_in_game_bad = df.get('kicks_in_game_bad', [0] * len(df))
    total_kicks_in_game = [kig + kib for kig, kib in zip(kicks_in_game_good, kicks_in_game_bad)]

    kick_in_game_pct = [(kig / tkig) * 100 if tkig > 0 else 100 for kig, tkig in zip(kicks_in_game_good, total_kicks_in_game)]

    # Kick in Game consistency: 100% = +0, 0% = -2 (linear scaling)
    kick_in_game_consistency = [(kigp - 100) / 50 for kigp in kick_in_game_pct]  # -2 at 0%
    consistency_rating = [cr + kigc for cr, kigc in zip(consistency_rating, kick_in_game_consistency)]
    
    # 9. Drop in Game consistency
    drops_in_game_good = df.get('drops_in_game_good', [0] * len(df))
    drops_in_game_bad = df.get('drops_in_game_bad', [0] * len(df))
    total_drops_in_game = [dig + didg for dig, didg in zip(drops_in_game_good, drops_in_game_bad)]

    drop_in_game_pct = [(dig / tdig) * 100 if tdig > 0 else 100 for dig, tdig in zip(drops_in_game_good, total_drops_in_game)]
    
    # Drop in Game consistency: 100% = +0, 0% = -2 (linear scaling)
    drop_in_game_consistency = [(dip - 100) / 50 for dip in drop_in_game_pct]  # -2 at 0%
    consistency_rating = [cr + dic for cr, dic in zip(consistency_rating, drop_in_game_consistency)]
    
    # Mod game consistency
    mod_game_plus = df.get('mod_game_plus', [0] * len(df))
    mod_game_minus = df.get('mod_game_minus', [0] * len(df))
    total_mod_game = [mgp + mgm for mgp, mgm in zip(mod_game_plus, mod_game_minus)]

    mod_game_pct = [(mmp / tm) * 100 if tm > 0 else 100 for mmp, tm in zip(mod_game_plus, total_mod_game)]

    # Mod game consistency: 100% = +0, 0% = -2 (linear scaling)
    mod_game_consistency = [(mmp - 100) / 50 for mmp in mod_game_pct]  # -2 at 0%
    consistency_rating = [cr + mgc for cr, mgc in zip(consistency_rating, mod_game_consistency)]
    
    # Pick and go consistency: 100% = +0, 0% = -2 (linear scaling)
    pick_and_go_plus = df.get('pick_and_go_plus', [0] * len(df))
    pick_and_go_minus = df.get('pick_and_go_minus', [0] * len(df))
    total_pick_and_go = [pgp + pgm for pgp, pgm in zip(pick_and_go_plus, pick_and_go_minus)]

    pick_and_go_pct = [(ppg / tp) * 100 if tp > 0 else 100 for ppg, tp in zip(pick_and_go_plus, total_pick_and_go)]

    # Pick and go consistency: 100% = +0, 0% = -1 (linear scaling)
    pick_and_go_consistency = [(pgp - 100) / 100 for pgp in pick_and_go_pct]  # -1 at 0%
    consistency_rating = [cr + pc for cr, pc in zip(consistency_rating, pick_and_go_consistency)]
    
    #  Only adjust scores outside 1-10 range (don't change scores already in range)
    consistency_rating = [max(1, min(10, cr)) for cr in consistency_rating]
    
    return [cr for cr, valid in zip(consistency_rating, valid_players) if valid]

def calculate_weighted_overall_rating(df):
    """
    Description:
        Generates a comprehensive weighted overall performance rating for each player on a 1-10 scale, by combining their scores from all key performance dimensions—attack, defense, discipline, work rate, consistency, and skills—according to predetermined weights. This rating allows direct comparison of overall player impact. Only players who have participated (minutes > 0) receive a rating; others are marked as NaN.

    Calculates the weighted overall rating for each player on a 1-10 scale.

    The overall rating is a weighted sum of key performance categories:
      - Attack: 30%
      - Defense: 30%
      - Discipline: 20%
      - Work Rate: 10%
      - Consistency: 5%
      - Skills: 5%

    Only players with minutes > 0 receive a rating; others receive NaN.

    Args:
        df (pd.DataFrame): Player statistics DataFrame including all necessary rating columns.

    Returns:
        List[float]: Weighted overall ratings (1-10 scale) for every player in the DataFrame (NaN where not valid).
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
    
    # Verify all rating arrays have the same length
    rating_lengths = {
        'attack': len(attack_ratings),
        'defense': len(defense_ratings),
        'discipline': len(discipline_ratings),
        'work_rate': len(work_rate_ratings),
        'skills': len(skills_ratings),
        'consistency': len(consistency_ratings)
    }
    
    # Get the expected length (number of valid players)
    num_valid = valid_players.sum()
    
    # Check if all arrays have the expected length
    if not all(length == num_valid for length in rating_lengths.values()):
        # Find which arrays have mismatched lengths
        mismatched = {name: length for name, length in rating_lengths.items() if length != num_valid}
        raise ValueError(
            f"Rating array length mismatch. Expected {num_valid} ratings (valid players), but got: "
            f"{rating_lengths}. Mismatched: {mismatched}. "
            f"This may indicate an issue in one of the rating calculation functions."
        )
    
    # Calculate weighted overall ratings for valid players only
    overall_ratings = []
    valid_index = 0
    for i in range(len(df)):
        if valid_players.iloc[i]:
            # Use the valid_index to access the filtered rating arrays
            if valid_index >= len(attack_ratings):
                # Safety check to prevent index out of range
                overall_ratings.append(float('nan'))
            else:
                overall_rating = (attack_ratings[valid_index] * 0.3 + defense_ratings[valid_index] * 0.3 + 
                                work_rate_ratings[valid_index] * 0.10 + consistency_ratings[valid_index] * 0.05 + 
                                discipline_ratings[valid_index] * 0.20 + skills_ratings[valid_index] * 0.05)
                overall_ratings.append(overall_rating)
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