class RuleListsController < ApplicationController
  before_action :set_rule_list, only: %i[ show edit update destroy ]

  # GET /rule_lists or /rule_lists.json
  def index
    @rule_lists = RuleList.all
  end

  # GET /rule_lists/1 or /rule_lists/1.json
  def show
  end

  # GET /rule_lists/new
  def new
    @rule_list = RuleList.new
  end

  # GET /rule_lists/1/edit
  def edit
  end

  # POST /rule_lists or /rule_lists.json
  def create
    @rule_list = RuleList.new(rule_list_params)

    respond_to do |format|
      if @rule_list.save
        format.html { redirect_to rule_list_url(@rule_list), notice: "Rule list was successfully created." }
        format.json { render :show, status: :created, location: @rule_list }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @rule_list.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /rule_lists/1 or /rule_lists/1.json
  def update
    respond_to do |format|
      if @rule_list.update(rule_list_params)
        format.html { redirect_to rule_list_url(@rule_list), notice: "Rule list was successfully updated." }
        format.json { render :show, status: :ok, location: @rule_list }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @rule_list.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /rule_lists/1 or /rule_lists/1.json
  def destroy
    @rule_list.destroy!

    respond_to do |format|
      format.html { redirect_to rule_lists_url, notice: "Rule list was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_rule_list
      @rule_list = RuleList.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def rule_list_params
      params.require(:rule_list).permit(:name, :description, :file, :line_count, :sensitive)
    end
end
