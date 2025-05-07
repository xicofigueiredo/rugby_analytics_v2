class TeamsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_team, only: [:show, :edit, :update, :destroy]

  def index
    @teams = Team.all
    @available_levels = Team.distinct.pluck(:level).sort
    @available_countries = Team.distinct.pluck(:country).sort

    # Apply level filter
    if params[:level].present?
      @teams = @teams.where(level: params[:level])
    end

    # Apply country filter

    # Handle both Turbo Frame and regular requests
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @players = @team.players.order(name: :asc)
  end

  def new
    @team = Team.new
  end

  def edit
  end

  def create
    @team = Team.new(team_params)

    if @team.save
      redirect_to teams_path, notice: 'Team was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @team.update(team_params)
      redirect_to teams_path, notice: 'Team was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @team.users.exists?
      redirect_to teams_path, alert: 'Cannot delete team with associated players.'
    else
      @team.destroy
      redirect_to teams_path, notice: 'Team was successfully deleted.'
    end
  end

  private

  def set_team
    @team = Team.find(params[:id])
  end

  def team_params
    params.require(:team).permit(:name, :level, :classification, :abbreviation, :main_color, :secondary_color)
  end
end
