# frozen_string_literal: true

class CrackerBinariesController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource
  # GET /cracker_binaries or /cracker_binaries.json
  def index; end

  # GET /cracker_binaries/1 or /cracker_binaries/1.json
  def show; end

  # GET /cracker_binaries/new
  def new; end

  # GET /cracker_binaries/1/edit
  def edit; end

  # POST /cracker_binaries or /cracker_binaries.json
  def create
    @cracker_binary = CrackerBinary.new(cracker_binary_params)

    respond_to do |format|
      if @cracker_binary.save
        format.html do
          redirect_to cracker_binary_url(@cracker_binary), notice: "Cracker binary was successfully created."
        end
        format.json { render :show, status: :created, location: @cracker_binary }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @cracker_binary.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /cracker_binaries/1 or /cracker_binaries/1.json
  def update
    respond_to do |format|
      if @cracker_binary.update(cracker_binary_params)
        format.html do
          redirect_to cracker_binary_url(@cracker_binary), notice: "Cracker binary was successfully updated."
        end
        format.json { render :show, status: :ok, location: @cracker_binary }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @cracker_binary.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /cracker_binaries/1 or /cracker_binaries/1.json
  def destroy
    @cracker_binary.destroy!

    respond_to do |format|
      format.html { redirect_to cracker_binaries_url, notice: "Cracker binary was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Only allow a list of trusted parameters through.
  def cracker_binary_params
    params.require(:cracker_binary).permit(:version, :active)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_cracker_binary
    @cracker_binary = CrackerBinary.find(params[:id])
  end
end
