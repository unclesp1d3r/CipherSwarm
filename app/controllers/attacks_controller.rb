# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# AttacksController is responsible for managing the lifecycle of Attack resources.
# It provides actions for creating, viewing, updating, and destroying attacks,
# along with necessary authorization and context setting.
#
# Note that this controller depends on nested resource associations,
# where an attack belongs to a specific campaign.
class AttacksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_attack_resources, only: %i[ new create edit update ]
  load_and_authorize_resource :campaign
  load_and_authorize_resource :attack, through: :campaign

  # GET /attacks/1 or /attacks/1.json
  def show; end

  # GET /attacks/new
  def new
    attack_mode = params[:attack_mode] || "dictionary"
    @attack = @campaign.attacks.build(attack_mode: attack_mode, optimized: true, workload_profile: 4)
  end

  # GET /attacks/1/edit
  def edit; end

  # POST /attacks or /attacks.json
  def create
    @attack = @campaign.attacks.build(attack_params)

    respond_to do |format|
      if @attack.save
        format.html { redirect_to campaign_path(@attack.campaign), notice: "Attack was successfully created." }
        format.json { render :show, status: :created, location: @attack }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @attack.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /attacks/1 or /attacks/1.json
  def update
    respond_to do |format|
      if @attack.update(attack_params)
        @attack.abandon! if @attack.can_abandon?
        format.html { redirect_to campaigns_path(@attack.campaign), notice: "Attack was successfully updated." }
        format.json { render :show, status: :ok, location: @attack }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @attack.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /attacks/1 or /attacks/1.json
  def destroy
    @attack.destroy!

    respond_to do |format|
      format.html { redirect_to campaigns_path, notice: "Attack was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Only allow a list of trusted parameters through.
  def attack_params
    params.require(:attack).permit(
      :name, :description, :attack_mode, :campaign_id, :left_rule, :right_rule, :mask,
      :increment_mode, :increment_minimum, :increment_maximum,
      :custom_charset_1, :custom_charset_2, :custom_charset_3, :custom_charset_4,
      :classic_markov, :disable_markov, :markov_threshold, :optimized, :slow_candidate_generators, :workload_profile,
      :word_list_id, :rule_list_id, :mask_list_id
    )
  end

  def set_attack_resources
    @word_lists = WordList.accessible_by(current_ability)
    @rule_lists = RuleList.accessible_by(current_ability)
    @mask_lists = MaskList.accessible_by(current_ability)
  end
end
