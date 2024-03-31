class Api::V1::Client::AttacksController < Api::V1::BaseController
  def show
    @attack = Attack.find(params[:id])
  end

  def hash_list
    @attack = Attack.find(params[:id])
    if @attack.nil?
      render json: { error: "Attack not found." }, status: :not_found
      return
    end
    send_data @attack.campaign.hash_list.uncracked_list,
              filename: "#{@attack.campaign.hash_list.id}.txt"
  end
end
