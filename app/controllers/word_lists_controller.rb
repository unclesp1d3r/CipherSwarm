class WordListsController < ApplicationController
  before_action :set_word_list, only: %i[ show edit update destroy ]

  # GET /word_lists or /word_lists.json
  def index
    @word_lists = WordList.all
  end

  # GET /word_lists/1 or /word_lists/1.json
  def show
  end

  # GET /word_lists/new
  def new
    @word_list = WordList.new
  end

  # GET /word_lists/1/edit
  def edit
  end

  # POST /word_lists or /word_lists.json
  def create
    @word_list = WordList.new(word_list_params)

    respond_to do |format|
      if @word_list.save
        format.html { redirect_to word_list_url(@word_list), notice: "Word list was successfully created." }
        format.json { render :show, status: :created, location: @word_list }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @word_list.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /word_lists/1 or /word_lists/1.json
  def update
    respond_to do |format|
      if @word_list.update(word_list_params)
        format.html { redirect_to word_list_url(@word_list), notice: "Word list was successfully updated." }
        format.json { render :show, status: :ok, location: @word_list }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @word_list.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /word_lists/1 or /word_lists/1.json
  def destroy
    @word_list.destroy!

    respond_to do |format|
      format.html { redirect_to word_lists_url, notice: "Word list was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_word_list
      @word_list = WordList.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def word_list_params
      params.require(:word_list).permit(:name, :description, :file, :line_count, :sensitive)
    end
end
