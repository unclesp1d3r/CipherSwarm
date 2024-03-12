class CrackersController < ApplicationController
  before_action :set_cracker, only: %i[ show edit update destroy ]

  # GET /crackers or /crackers.json
  def index
    @crackers = Cracker.accessible_by(current_ability)
  end

  # GET /crackers/1 or /crackers/1.json
  def show
    authorize! :read, @cracker
  end

  # GET /crackers/new
  def new
    authorize :create, Cracker
    @cracker = Cracker.new
  end

  # GET /crackers/1/edit
  def edit
    authorize! :edit, @cracker
  end

  # POST /crackers or /crackers.json
  def create
    authorize! :create, Cracker
    @cracker = Cracker.new(cracker_params)

    respond_to do |format|
      if @cracker.save
        format.html { redirect_to cracker_url(@cracker), notice: "Cracker was successfully created." }
        format.json { render :show, status: :created, location: @cracker }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @cracker.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /crackers/1 or /crackers/1.json
  def update
    authorize! :update, @cracker
    respond_to do |format|
      if @cracker.update(cracker_params)
        format.html { redirect_to cracker_url(@cracker), notice: "Cracker was successfully updated." }
        format.json { render :show, status: :ok, location: @cracker }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @cracker.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /crackers/1 or /crackers/1.json
  def destroy
    authorize! :destroy, @cracker
    @cracker.destroy!

    respond_to do |format|
      format.html { redirect_to crackers_url, notice: "Cracker was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_cracker
    @cracker = Cracker.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def cracker_params
    params.require(:cracker).permit(:name, cracker_binaries_id: [])
  end
end
