namespace :email do
  desc "Debug email authentication issues"
  task :debug => :environment do
    puts "🔍 Email Authentication Debug"
    puts "=" * 50

    # Check environment variables
    puts "Environment Variables:"
    puts "  EMAIL_USERNAME: #{ENV['EMAIL_USERNAME'] || 'NOT SET'}"
    puts "  EMAIL_PASSWORD: #{ENV['EMAIL_PASSWORD'] ? '*' * ENV['EMAIL_PASSWORD'].length : 'NOT SET'}"

    # Check current SMTP settings
    smtp_settings = Rails.application.config.action_mailer.smtp_settings
    puts "\nCurrent SMTP Settings:"
    smtp_settings.each do |key, value|
      if key == :password
        puts "  #{key}: #{'*' * (value&.length || 0)}"
      else
        puts "  #{key}: #{value}"
      end
    end

    puts "\n🔧 Trying different authentication methods..."

    # Test different authentication methods
    auth_methods = [:plain, :login, :cram_md5]
    server = smtp_settings[:address]
    port = smtp_settings[:port]
    username = smtp_settings[:user_name]
    password = smtp_settings[:password]
    domain = smtp_settings[:domain]

    auth_methods.each do |auth_method|
      puts "\n🧪 Testing #{auth_method} authentication..."

      begin
        require 'net/smtp'

        smtp = Net::SMTP.new(server, port)
        smtp.enable_starttls_auto if smtp_settings[:enable_starttls_auto]

        smtp.start(domain, username, password, auth_method) do |connection|
          puts "✅ #{auth_method.upcase} authentication successful!"
        end

      rescue => e
        puts "❌ #{auth_method.upcase} failed: #{e.message}"
      end
    end

    puts "\n🔧 Trying different ports..."

    # Test different ports
    ports = [25, 587, 465, 2525]
    ports.each do |test_port|
      puts "\n🧪 Testing port #{test_port}..."

      begin
        require 'net/smtp'

        smtp = Net::SMTP.new(server, test_port)

        # Configure SSL/TLS based on port
        case test_port
        when 465
          smtp.enable_tls
        when 25, 587, 2525
          smtp.enable_starttls_auto
        end

        smtp.start(domain, username, password, :plain) do |connection|
          puts "✅ Port #{test_port} connection successful!"
        end

      rescue => e
        puts "❌ Port #{test_port} failed: #{e.message}"
      end
    end

    puts "\n💡 Recommendations:"
    puts "1. Double-check your email password in your webmail"
    puts "2. Try logging into #{server} webmail directly to verify credentials"
    puts "3. Contact your hosting provider for exact SMTP settings"
    puts "4. Some hosts require enabling SMTP in control panel"
    puts "5. Try using the full email address as username"

    puts "\n📝 Alternative SMTP servers to try:"
    puts "- mail.breakdownlab.me"
    puts "- smtp.breakdownlab.me"
    puts "- breakdownlab.me"

    puts "\n" + "=" * 50
  end

  desc "Test with manual credentials"
  task :test_manual => :environment do
    puts "🧪 Manual Credential Test"
    puts "=" * 50
    puts "This will prompt you for credentials to test different combinations"

    print "Enter SMTP server (current: webdomain02.dnscpanel.com): "
    server = STDIN.gets.chomp
    server = 'webdomain02.dnscpanel.com' if server.empty?

    print "Enter port (current: 587): "
    port = STDIN.gets.chomp
    port = port.empty? ? 587 : port.to_i

    print "Enter username (e.g., admin@breakdownlab.me): "
    username = STDIN.gets.chomp

    print "Enter password: "
    system "stty -echo"
    password = STDIN.gets.chomp
    system "stty echo"
    puts

    print "Enter domain (current: breakdownlab.me): "
    domain = STDIN.gets.chomp
    domain = 'breakdownlab.me' if domain.empty?

    puts "\n🔧 Testing connection with provided credentials..."

    begin
      require 'net/smtp'

      smtp = Net::SMTP.new(server, port)
      smtp.enable_starttls_auto if port != 465
      smtp.enable_tls if port == 465

      smtp.start(domain, username, password, :plain) do |connection|
        puts "✅ Connection successful with these settings!"
        puts "\nAdd these to your Rails configuration:"
        puts "config.action_mailer.smtp_settings = {"
        puts "  address:              '#{server}',"
        puts "  port:                 #{port},"
        puts "  domain:               '#{domain}',"
        puts "  user_name:            '#{username}',"
        puts "  password:             'your_password',"
        puts "  authentication:       'plain',"
        puts "  enable_starttls_auto: #{port != 465}"
        puts "}"
      end

    rescue => e
      puts "❌ Connection failed: #{e.message}"
    end
  end
end
