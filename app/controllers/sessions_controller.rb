class SessionsController < ApplicationController
  def new
    # Login form
  end

  def create
    # Handle login logic here
    flash[:notice] = "This feature is coming soon!"
    redirect_to root_path
  end

  def destroy
    # Handle logout logic here
    flash[:notice] = "Logged out successfully!"
    redirect_to root_path
  end
end
