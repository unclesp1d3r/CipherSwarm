# frozen_string_literal: true

class WordListsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_word_list, only: %i[ show edit update destroy ]
  load_and_authorize_resource

  # GET /word_lists or /word_lists.json
  def index
  end

  # GET /word_lists/1 or /word_lists/1.json
  def show; end

  # GET /word_lists/new
  def new
    @word_list = WordList.new
  end

  # GET /word_lists/1/edit
  def edit; end

  # POST /word_lists or /word_lists.json
  def create
    @word_list = WordList.new(word_list_params)

    respond_to do |format|
      if @word_list.save
        format.html { redirect_to word_list_url(@word_list), notice: "Word list was successfully created." }
        format.json { render :show, status: :created, location: @word_list }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @word_list.errors, status: :unprocessable_content }
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
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @word_list.errors, status: :unprocessable_content }
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

  def file_content
    max_lines = params[:limit] ||= 1000
    authorize! :read, @word_list
    @word_list = WordList.find(params[:id])
    @word_list.file.blob.open do |file|
      @file_content = file.read
    end
    if @file_content.lines.count > max_lines
      @file_content = @file_content.lines.first(max_lines).join
    end
    render turbo_stream: turbo_stream.replace(:file_content,
                                              partial: "word_lists/file_content",
                                              locals: { file_content: @file_content })
  end

  def view_file
    authorize! :read, @word_list
    @word_list = WordList.find(params[:id])
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_word_list
    @word_list = WordList.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def word_list_params
    params.require(:word_list).permit(:name, :description, :file, :line_count, :sensitive, project_ids: [])
  end
end
