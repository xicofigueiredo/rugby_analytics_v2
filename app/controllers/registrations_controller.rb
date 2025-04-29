class RegistrationsController < ApplicationController
  def new
    # Registration form
  end

  def create
    # Handle registration logic here
    flash[:notice] = "This feature is coming soon!"
    redirect_to root_path
  end
end
