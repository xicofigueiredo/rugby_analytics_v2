class MatchesController < ApplicationController
  def index
    @matches = Match.all
  end

  def show
    @match = Match.find(params[:id])
  end

  def new
    @match = Match.new
  end

  def create
    @match = Match.new(match_params)

    if @match.save
      redirect_to @match, notice: 'Match was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @match = Match.find(params[:id])
  end

  def update
    @match = Match.find(params[:id])

    if @match.update(match_params)
      redirect_to @match, notice: 'Match was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @match = Match.find(params[:id])
    @match.destroy

    redirect_to matches_url, notice: 'Match was successfully deleted.'
  end

  private

  def match_params
    params.require(:match).permit(
      :season,
      :competition,
      :description,
      :date,
      :home_team,
      :away_team,
      :result
    )
  end
end
