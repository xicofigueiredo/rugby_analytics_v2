module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!

    def index
      @users = User.includes(:team).order(created_at: :desc)
    end
  end
end
