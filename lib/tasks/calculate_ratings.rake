namespace :ratings do
  desc "Calculate ratings for all player matches and team stats"
  task calculate_all: :environment do
    puts "Calculating ratings for all player matches..."

    player_matches_count = 0
    player_matches_errors = 0

    PlayerMatch.find_each do |player_match|
      begin
        player_match.calculate_ratings!
        player_matches_count += 1
        print "." if player_matches_count % 10 == 0
      rescue => e
        player_matches_errors += 1
        puts "\nError calculating ratings for PlayerMatch #{player_match.id}: #{e.message}"
      end
    end

    puts "\nCalculated ratings for #{player_matches_count} player matches (#{player_matches_errors} errors)"

    puts "Calculating ratings for all team stats..."

    teamstats_count = 0
    teamstats_errors = 0

    Teamstat.find_each do |teamstat|
      begin
        teamstat.calculate_ratings!
        teamstats_count += 1
        print "." if teamstats_count % 10 == 0
      rescue => e
        teamstats_errors += 1
        puts "\nError calculating ratings for Teamstat #{teamstat.id}: #{e.message}"
      end
    end

    puts "\nCalculated ratings for #{teamstats_count} team stats (#{teamstats_errors} errors)"
    puts "Rating calculation complete!"
    puts "All ratings are now normalized to 0-10 scale."
  end

  desc "Calculate ratings for a specific match"
  task :calculate_match, [:match_id] => :environment do |t, args|
    match_id = args[:match_id]

    if match_id.blank?
      puts "Please provide a match ID: rake ratings:calculate_match[123]"
      exit
    end

    match = Match.find(match_id)
    puts "Calculating ratings for match: #{match.home_team.name} vs #{match.away_team.name} (#{match.date})"

    # Calculate player ratings
    player_count = 0
    player_errors = 0

    match.player_matches.each do |player_match|
      begin
        player_match.calculate_ratings!
        player_count += 1
        puts "✓ Calculated ratings for #{player_match.player.name}"
        puts "  Attack: #{player_match.attack_rating}/10, Defense: #{player_match.defense_rating}/10, Overall: #{player_match.overall_rating}/10"
      rescue => e
        player_errors += 1
        puts "✗ Error calculating ratings for #{player_match.player.name}: #{e.message}"
      end
    end

    # Calculate team ratings
    team_count = 0
    team_errors = 0

    match.teamstat.each do |teamstat|
      begin
        teamstat.calculate_ratings!
        team_count += 1
        team_name = Team.find(teamstat.team_id).name
        puts "✓ Calculated team ratings for #{team_name}"
        puts "  Attack: #{teamstat.attack_rating}/10, Defense: #{teamstat.defense_rating}/10, Overall: #{teamstat.overall_rating}/10"
      rescue => e
        team_errors += 1
        puts "✗ Error calculating team ratings: #{e.message}"
      end
    end

    puts "\nSummary:"
    puts "Player ratings: #{player_count} calculated, #{player_errors} errors"
    puts "Team ratings: #{team_count} calculated, #{team_errors} errors"
    puts "All ratings are on a 0-10 scale."
  end
end
