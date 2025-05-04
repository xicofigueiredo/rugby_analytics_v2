class MatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_match, only: [:show, :edit, :update, :destroy]
  before_action :set_opponents, only: [:new, :edit, :create, :update]

  def index
    @matches = Match.for_team(current_user.team&.name)
                   .order(date: :desc, created_at: :desc)
  end

  def show
  end

  def new
    @match = Match.new
    15.times do
      @match.player_matches.build(started: true, on_field: true)
    end
    8.times do
      @match.player_matches.build(started: false, on_field: false)
    end
  end

  def create
    @match = Match.new(match_params)
    set_teams_based_on_location

    if @match.save
      redirect_to @match, notice: 'Match was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @match.update(match_params)
      redirect_to @match, notice: 'Match was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @match.destroy
    redirect_to matches_url, notice: 'Match was successfully deleted.'
  end

  private

  def set_match
    @match = Match.find(params[:id])
  end

  def set_opponents
    @opponents = Team.where.not(id: current_user.team_id)
  end

  def match_params
    params.require(:match).permit(
      :season,
      :competition,
      :description,
      :date,
      :home_team,
      :away_team,
      :location_type,
      :opponent_id,
      :result,
      player_matches_attributes: [:id, :player_id, :position, :started, :on_field, :_destroy]
    )
  end

  def set_teams_based_on_location
    if params[:match][:location_type] == 'home'
      @match.home_team = current_user.team.name
      @match.away_team = Team.find(params[:match][:opponent_id]).name
    else
      @match.away_team = current_user.team.name
      @match.home_team = Team.find(params[:match][:opponent_id]).name
    end
  end

  def ensure_user_has_team
    unless current_user.team
      redirect_to teams_path, alert: 'You need to be part of a team to create matches.'
    end
  end
end
