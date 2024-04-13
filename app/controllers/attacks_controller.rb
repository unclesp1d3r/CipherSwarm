# frozen_string_literal: true

class AttacksController < ApplicationController
  before_action :set_attack, only: %i[ show edit update destroy ]

  # GET /attacks or /attacks.json
  def index
    @attacks = Attack.all
  end

  # GET /attacks/1 or /attacks/1.json
  def show; end

  # GET /attacks/new
  def new
    @attack = Attack.new
  end

  # GET /attacks/1/edit
  def edit; end

  # POST /attacks or /attacks.json
  def create
    @attack = Attack.new(attack_params)

    respond_to do |format|
      if @attack.save
        format.html { redirect_to attack_url(@attack), notice: "Attack was successfully created." }
        format.json { render :show, status: :created, location: @attack }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @attack.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /attacks/1 or /attacks/1.json
  def update
    respond_to do |format|
      if @attack.update(attack_params)
        format.html { redirect_to attack_url(@attack), notice: "Attack was successfully updated." }
        format.json { render :show, status: :ok, location: @attack }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @attack.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /attacks/1 or /attacks/1.json
  def destroy
    @attack.destroy!

    respond_to do |format|
      format.html { redirect_to attacks_url, notice: "Attack was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def decrease_position
    attack = Attack.find(params[:id])
    attack.update!(position: attack.position - 1)
  end

  def increase_position
    attack = Attack.find(params[:id])
    attack.update!(position: attack.position + 1)
  end

  private

  # Only allow a list of trusted parameters through.
  def attack_params
    params.require(:attack).permit(
      :name, :description, :attack_mode, :campaign_id, :left_rule, :right_rule, :mask,
      :increment_mode, :increment_minimum, :increment_maximum,
      :custom_charset_1, :custom_charset_2, :custom_charset_3, :custom_charset_4,
      :classic_markov, :disable_markov, :markov_threshold, :optimized, :slow_candidate_generators, :workload_profile,
      word_list_ids: [], rule_list_ids: []
    )
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_attack
    @attack = Attack.find(params[:id])
  end
end
