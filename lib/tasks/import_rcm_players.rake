require 'csv'

namespace :import do
  desc "Import RCM players from CSV file"
  task :rcm_players => :environment do
    csv_file_path = Rails.root.join('lib', 'tasks', 'RCMINFO.csv')

    unless File.exist?(csv_file_path)
      puts "CSV file not found at: #{csv_file_path}"
      return
    end

    puts "Processing CSV file: #{csv_file_path}"
    puts "=" * 50

    # Find Montemor team (case-insensitive)
    team = Team.where("LOWER(name) = ?", 'montemor').first

    unless team
      puts "Team 'Montemor' not found. Please create it first."
      return
    end

    puts "Using team: #{team.name} (ID: #{team.id})"
    puts "=" * 50

    # Position mapping from Portuguese to English
    position_mapping = {
      'Abertura' => 'Fly-half',
      'Formação' => 'Scrum-half',
      'Ponta' => 'Wing',
      '15' => 'Full-back',
      'Primeiro Centro' => 'Centre',
      'Segundo Centro' => 'Centre',
      'Asa fechado (6)' => 'Flanker',
      'Asa aberto (7)' => 'Flanker',
      'Pilar Direito (3)' => 'Tighthead Prop',
      'Pilar esquerdo (1)' => 'Loosehead Prop',
      'Talonador' => 'Hooker',
      'Segunda linha' => 'Lock',
      'Numero 8' => 'Number 8',
      'Número 8' => 'Number 8',
      'Flanker' => 'Flanker'
    }

    created_count = 0
    updated_count = 0
    error_count = 0
    skipped_count = 0

    CSV.foreach(csv_file_path, headers: true, encoding: 'UTF-8') do |row|
      # Skip empty rows
      name = row['Nome']&.strip
      email = row['E-mail']&.strip&.downcase

      next if name.blank? || email.blank?

      # Extract data from CSV
      height = row['Altura em cm']&.to_i
      weight = row['Peso em Kg']&.to_s.gsub(',', '.').to_f
      birthdate_str = row['Data de nascimento']&.strip
      primary_position = row['Posição']&.strip
      secondary_position = row['Posição Secundária']&.strip
      country = row['Nacionalidade']&.strip || 'Portugal'
      caps_str = row['N de jogos OFICIAIS pelo RCM (23/10/2025)']&.strip

      # Skip if essential data is missing
      if height == 0 || weight == 0
        puts "Skipping #{name}: missing height or weight"
        skipped_count += 1
        next
      end

      # Parse birthdate (format: DD/MM/YYYY)
      birthdate = nil
      age = nil
      if birthdate_str.present?
        begin
          day, month, year = birthdate_str.split('/').map(&:to_i)
          # Handle year format (could be 2 or 4 digits)
          # If year is less than 100, assume it's a 2-digit year
          if year < 100
            year += 2000
          end
          # Validate year is reasonable (between 1950 and current year)
          if year < 1950 || year > Date.today.year
            puts "Warning: Invalid year '#{year}' in birthdate '#{birthdate_str}' for #{name}"
            raise "Invalid year"
          end
          birthdate = Date.new(year, month, day)
          # Calculate age from birthdate
          age = Date.today.year - birthdate.year - ((Date.today.month > birthdate.month || (Date.today.month == birthdate.month && Date.today.day >= birthdate.day)) ? 0 : 1)
          # Validate age is reasonable (between 13 and 50 as per model validation)
          if age < 13 || age >= 50
            puts "Warning: Calculated age '#{age}' is outside valid range for #{name}"
          end
        rescue => e
          puts "Warning: Could not parse birthdate '#{birthdate_str}' for #{name}: #{e.message}"
        end
      end

      # Skip if we can't calculate age (age is required)
      if age.nil?
        puts "Skipping #{name}: birthdate is missing or invalid (age cannot be calculated)"
        skipped_count += 1
        next
      end

      # Parse caps (integer, can be empty)
      caps = caps_str.present? ? caps_str.to_i : 0

      # Map positions
      mapped_positions = []

      # Primary position
      if primary_position.present?
        mapped_position = position_mapping[primary_position] || primary_position
        # Only add if it's a valid position
        if Player::VALID_POSITIONS.include?(mapped_position)
          mapped_positions << mapped_position
        end
      end

      # Secondary position
      if secondary_position.present?
        mapped_position = position_mapping[secondary_position] || secondary_position
        if Player::VALID_POSITIONS.include?(mapped_position)
          mapped_positions << mapped_position
        end
      end

      # Remove duplicates
      mapped_positions.uniq!

      # Default to Centre if no positions mapped
      if mapped_positions.empty?
        puts "Warning: No valid positions found for #{name}, defaulting to Centre"
        mapped_positions = ['Centre']
      end

      begin
        ActiveRecord::Base.transaction do
          # Check if user already exists
          user = User.find_by(email: email)
          password = '123456'

          if user
            puts "User already exists: #{email} - updating player data"
            player = user.player

            if player
              # Update existing player
              player.update!(
                name: name,
                age: age,
                positions: mapped_positions,
                weight: weight,
                height: height,
                team: team,
                country: country,
                birthdate: birthdate,
                caps: caps
              )
              updated_count += 1
            else
              # Create player for existing user
              player = Player.create!(
                name: name,
                age: age,
                positions: mapped_positions,
                weight: weight,
                height: height,
                team: team,
                country: country,
                birthdate: birthdate,
                caps: caps
              )
              user.update!(player: player, role: 'player', team: team)
              created_count += 1
            end
          else
            # Create new user and player
            player = Player.create!(
              name: name,
              age: age,
              positions: mapped_positions,
              weight: weight,
              height: height,
              team: team,
              country: country,
              birthdate: birthdate,
              caps: caps
            )

            user = User.create!(
              name: name,
              email: email,
              password: password,
              password_confirmation: password,
              role: 'player',
              team: team,
              player: player
            )

            created_count += 1
          end

          puts "✓ Processed: #{name} (#{email}) - Positions: #{mapped_positions.join(', ')} - Caps: #{caps}"
        end

      rescue ActiveRecord::RecordInvalid => e
        puts "✗ Error processing #{name}: #{e.message}"
        error_count += 1
      rescue => e
        puts "✗ Unexpected error processing #{name}: #{e.message}"
        puts "   #{e.backtrace.first}"
        error_count += 1
      end
    end

    puts "=" * 50
    puts "Import Summary:"
    puts "Team: #{team.name}"
    puts "Created: #{created_count} players"
    puts "Updated: #{updated_count} players"
    puts "Skipped: #{skipped_count} players"
    puts "Errors: #{error_count} players"
    puts "Total players in team: #{team.players.count}"
    puts "=" * 50

    if created_count > 0
      puts "\nNOTE: New users were created with password '123456'"
      puts "Users should change their passwords on first login."
    end
  end
end
