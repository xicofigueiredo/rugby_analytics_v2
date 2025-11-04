module ApplicationHelper
  def country_flag_code(country_name)
    return 'pt' if country_name.blank?

    # Map common country names to ISO 3166-1 alpha-2 codes
    country_map = {
      'Portugal' => 'pt',
      'Spain' => 'es',
      'France' => 'fr',
      'Italy' => 'it',
      'England' => 'gb',
      'United Kingdom' => 'gb',
      'UK' => 'gb',
      'Ireland' => 'ie',
      'Scotland' => 'gb',
      'Wales' => 'gb',
      'Brazil' => 'br',
      'Argentina' => 'ar',
      'South Africa' => 'za',
      'Australia' => 'au',
      'New Zealand' => 'nz',
      'Fiji' => 'fj',
      'Samoa' => 'ws',
      'Tonga' => 'to',
      'Japan' => 'jp',
      'United States' => 'us',
      'USA' => 'us',
      'Canada' => 'ca',
      'Germany' => 'de',
      'Netherlands' => 'nl',
      'Belgium' => 'be',
      'Switzerland' => 'ch',
      'Austria' => 'at',
      'Sweden' => 'se',
      'Norway' => 'no',
      'Denmark' => 'dk',
      'Finland' => 'fi',
      'Poland' => 'pl',
      'Czech Republic' => 'cz',
      'Romania' => 'ro',
      'Georgia' => 'ge',
      'Russia' => 'ru',
      'Ukraine' => 'ua',
      'Greece' => 'gr',
      'Turkey' => 'tr',
      'Israel' => 'il',
      'Uruguay' => 'uy',
      'Chile' => 'cl',
      'Namibia' => 'na',
      'Zimbabwe' => 'zw',
      'Kenya' => 'ke',
      'Madagascar' => 'mg',
      'Morocco' => 'ma',
      'Tunisia' => 'tn',
      'Algeria' => 'dz',
      'Egypt' => 'eg'
    }

    # Normalize country name (remove extra spaces, case insensitive)
    normalized = country_name.to_s.strip

    # Try exact match first
    code = country_map[normalized] || country_map[normalized.capitalize]

    # If not found, try partial match
    if code.nil?
      code = country_map.find { |key, _| normalized.downcase.include?(key.downcase) || key.downcase.include?(normalized.downcase) }&.last
    end

    # Default to Portugal if not found
    code || 'pt'
  end

  def country_flag_url(country_name, size = '24x18')
    code = country_flag_code(country_name)
    "https://flagcdn.com/#{size}/#{code.downcase}.png"
  end
end
