require 'csv'

namespace :csv do
  desc "Process CSV file and extract non-empty columns (ignoring start time and duration)"
  task :process_rugby_data => :environment do
    csv_file_path = Rails.root.join('lib', 'tasks', 'CSV CDUP vs Lousã.csv')

    unless File.exist?(csv_file_path)
      puts "CSV file not found at: #{csv_file_path}"
      return
    end

    puts "Processing CSV file: #{csv_file_path}"
    puts "=" * 50

    # Track which columns to ignore (by index)
    ignored_columns = []
    non_empty_rows = []
    row_number = 0

    CSV.foreach(csv_file_path, headers: true, encoding: 'UTF-8') do |row|
      row_number += 1
      # On first row, identify which columns to ignore
      if ignored_columns.empty?
        row.headers.each_with_index do |header, index|
          if header&.downcase&.include?('start time') || header&.downcase&.include?('duration')
            ignored_columns << index
            puts "Ignoring column #{index}: '#{header}'"
          end
        end
        puts "=" * 50
      end

      # Extract non-empty values from non-ignored columns
      non_empty_values = []
      row.headers.each_with_index do |header, index|
        # Skip ignored columns
        next if ignored_columns.include?(index)

        field = row[header]
        # Skip empty values
        next if field.nil? || field.strip.empty?

        non_empty_values << field.strip
      end

      # Only add rows that have at least one non-empty value
      if non_empty_values.any?
        non_empty_rows << non_empty_values
        puts "Row #{row_number}: #{non_empty_values.inspect}"
      end
    end

    puts "=" * 50
    puts "Summary:"
    puts "Total rows processed: #{row_number}"
    puts "Rows with non-empty data: #{non_empty_rows.length}"
    puts "Ignored columns: #{ignored_columns.length}"

    # Example of accessing the processed data
    non_empty_rows.each_with_index do |row_data, index|
      puts "  Row #{index + 1}: #{row_data.inspect}"
    end

    # You can now use non_empty_rows array for further processing
    # For example, save to database, export to another format, etc.

  end
end
