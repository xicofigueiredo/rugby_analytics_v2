class MatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_match, only: [:show, :edit, :update, :destroy]
  before_action :set_opponents, only: [:new, :edit, :create, :update]

  def index
    @matches = Match.all

    @current_team = current_user.team if current_user.team

    # Apply team filter
    if params[:team_id].present?
      @matches = @matches.where("home_team_id = ? OR away_team_id = ?", params[:team_id], params[:team_id])
    end

    # Apply season filter
    if params[:season].present?
      @matches = @matches.where(season: params[:season])
    end

    # Apply month filter
    if params[:month].present?
      @matches = @matches.where("EXTRACT(MONTH FROM date) = ?", params[:month])
    end

    # Apply sorting
    @sort_direction = params[:sort_direction] == 'asc' ? 'asc' : 'desc'
    @matches = @matches.order(date: @sort_direction, created_at: @sort_direction)

    # Handle both Turbo Frame and regular requests
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
  end

  def new
    @match = Match.new
  end

  def create
    @match = Match.new(match_params)
    @match.current_team_id = current_user.team&.id

    if @match.save
      redirect_to @match, notice: 'Match was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Set the location_type based on whether the current user's team is home or away
    @match.location_type = if @match.home_team_id == current_user.team&.id
                            'home'
                          else
                            'away'
                          end

    # Set the opponent_id by finding the opponent team
    @match.opponent_id = if @match.location_type == 'home'
                          @match.away_team_id
                        else
                          @match.home_team_id
                        end
  end

  def update
    @match.current_team_id = current_user.team&.id

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
      :location_type,
      :opponent_id,
      :result
    )
  end

  def ensure_user_has_team
    unless current_user.team
      redirect_to teams_path, alert: 'You need to be part of a team to create matches.'
    end
  end
end
