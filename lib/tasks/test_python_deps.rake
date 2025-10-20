namespace :python do
  desc "Test Python dependencies for rating system"
  task test_deps: :environment do
    puts "Testing Python dependencies..."

    # Test Python executable
    python_executable = Rails.env.production? ? "python3" : (File.exist?(Rails.root.join('venv', 'bin', 'python')) ? Rails.root.join('venv', 'bin', 'python').to_s : "python3")

    puts "Using Python executable: #{python_executable}"

    # Test Python version
    version_output = `#{python_executable} --version 2>&1`
    if $?.success?
      puts "✓ Python version: #{version_output.strip}"
    else
      puts "✗ Python not found or not working"
      exit 1
    end

    # Test pandas
    pandas_test = `#{python_executable} -c "import pandas; print('pandas version:', pandas.__version__)" 2>&1`
    if $?.success?
      puts "✓ #{pandas_test.strip}"
    else
      puts "✗ pandas not available: #{pandas_test.strip}"
      exit 1
    end

    # Test numpy
    numpy_test = `#{python_executable} -c "import numpy; print('numpy version:', numpy.__version__)" 2>&1`
    if $?.success?
      puts "✓ #{numpy_test.strip}"
    else
      puts "✗ numpy not available: #{numpy_test.strip}"
      exit 1
    end

    # Test the rating script
    script_path = Rails.root.join('lib', 'tasks', 'sport_rating_system_v1.py')
    test_data = '[{"minutes":80,"tries":1,"assists":0,"conversions_made":0,"conversions_attempted":0,"kicks_made":0,"kicks_attempted":0,"drops_made":0,"drops_attempted":0,"offensive_tackles":8,"neutral_tackles":5,"defensive_tackles":2,"assist_tackles":3,"missed_tackles":1,"carries_with_gain":12,"carries_without_gain":3,"linebreak":2,"linebreak_assists":1,"offloads_good":2,"offloads_bad":0,"turnovers_won":1,"total_penalties":2,"offside_penalties":1,"ruck_penalties":1,"scrum_penalties":0,"other_penalties":0,"knock_on":1,"other_mistakes":0,"yellow_cards":0,"red_cards":0,"aerial_duels_won":3,"aerial_duels_lost":1,"lineout_steals":0,"own_lineouts_won":5,"lineout_intros_won":4,"lineout_intros_total":5,"scrum_dominant":2,"mod_game_plus":3,"mod_game_minus":1}]'

    require 'open3'
    begin
      result = nil
      Open3.popen3(python_executable, script_path.to_s) do |stdin, stdout, stderr, wait_thr|
        stdin.write(test_data)
        stdin.close

        output = stdout.read
        error_output = stderr.read

        if wait_thr.value.success?
          result = JSON.parse(output)
          puts "✓ Rating script working correctly"
          puts "  Sample result: #{result.first}"
        else
          puts "✗ Rating script failed: #{error_output}"
          exit 1
        end
      end
    rescue => e
      puts "✗ Error testing rating script: #{e.message}"
      exit 1
    end

    puts "\n🎉 All Python dependencies are working correctly!"
  end
end
