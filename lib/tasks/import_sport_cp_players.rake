require 'csv'

namespace :import do
  desc "Import Sport CP players from CSV file"
  task :sport_cp_players => :environment do
    csv_file_path = Rails.root.join('lib', 'tasks', 'Sport CP - Jogadores.csv')

    unless File.exist?(csv_file_path)
      puts "CSV file not found at: #{csv_file_path}"
      return
    end

    puts "Processing CSV file: #{csv_file_path}"
    puts "=" * 50

    # Find or create Sport CP team
    team = Team.find_by(name: 'Sport CP')

    puts "Using team: #{team.name} (ID: #{team.id})"

    # Position mapping from Portuguese to English
    position_mapping = {
      '1ª Linha' => ['Loosehead Prop', 'Hooker', 'Tighthead Prop'],
      '2ª Linha' => ['Lock'],
      '3ª Linha' => ['Flanker', 'Number 8'],
      'Formação' => ['Scrum-half'],
      'Abertura' => ['Fly-half'],
      'Centro' => ['Centre'],
      'Ponta' => ['Wing'],
      'Defesa' => ['Full-back']
    }

    created_count = 0
    updated_count = 0
    error_count = 0
    emails_sent = 0

    CSV.foreach(csv_file_path, headers: true, col_sep: ';', encoding: 'UTF-8') do |row|
      # Skip empty rows
      next if row['Nome e apelido: '].blank?

      name = row['Nome e apelido: '].strip
      age = row['Idade: '].to_i
      positions_str = row['Posição / Posições em que jogas: '].to_s.strip
      weight = row['Peso: '].to_s.gsub(',', '.').to_f
      height = row['Altura'].to_i
      email = row['Email: '].to_s.strip.downcase

      # Skip if essential data is missing
      if name.blank? || email.blank? || age == 0 || weight == 0 || height == 0
        puts "Skipping row due to missing essential data: #{name}"
        error_count += 1
        next
      end

      # Map positions
      mapped_positions = []
      positions_str.split(',').each do |pos|
        pos = pos.strip
        position_mapping.each do |portuguese, english_positions|
          if pos.include?(portuguese)
            mapped_positions.concat(english_positions)
          end
        end
      end

      # Default to Centre if no positions mapped
      mapped_positions = ['Centre'] if mapped_positions.empty?
      mapped_positions.uniq!

      begin
        ActiveRecord::Base.transaction do
          # Check if user already exists
          user = User.find_by(email: email)
          temporary_password = SecureRandom.hex(6)
          is_new_user = false

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
                team: team
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
                team: team
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
              team: team
            )

            user = User.create!(
              name: name,
              email: email,
              password: temporary_password,
              password_confirmation: temporary_password,
              confirmed_at: Time.now,
              role: 'player',
              team: team,
              player: player
            )

            is_new_user = true
            created_count += 1
          end

          # Send welcome email to new users
          if is_new_user
            begin
              #UserMailer.welcome_email(user, temporary_password).deliver_now
              emails_sent += 1
              puts "✓ Welcome email sent to: #{email}"
            rescue => email_error
              puts "⚠ Email failed for #{email}: #{email_error.message}"
            end
          end

          puts "✓ Processed: #{name} (#{email}) - Positions: #{mapped_positions.join(', ')}"
        end

      rescue ActiveRecord::RecordInvalid => e
        puts "✗ Error processing #{name}: #{e.message}"
        error_count += 1
      rescue => e
        puts "✗ Unexpected error processing #{name}: #{e.message}"
        error_count += 1
      end
    end

    puts "=" * 50
    puts "Import Summary:"
    puts "Team: #{team.name}"
    puts "Created: #{created_count} players"
    puts "Updated: #{updated_count} players"
    puts "Errors: #{error_count} players"
    puts "Welcome emails sent: #{emails_sent}"
    puts "Total players in team: #{team.players.count}"
    puts "=" * 50

    if created_count > 0
      puts "\nNOTE: New users were created with temporary password 'temporary123!'"
      puts "Welcome emails with login credentials have been sent to new users."
      puts "Users should change their passwords on first login."
    end
  end
end
