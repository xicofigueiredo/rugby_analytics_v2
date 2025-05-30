class PwaController < ApplicationController
  skip_before_action :authenticate_user!, only: [:manifest]

  def manifest
    render file: Rails.root.join('app/views/pwa/manifest.json.erb'), content_type: 'application/json'
  end

end
