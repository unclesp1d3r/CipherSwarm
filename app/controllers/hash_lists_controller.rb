# frozen_string_literal: true

class HashListsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource
  # GET /hash_lists or /hash_lists.json
  def index
    @hash_lists = HashList.includes(%i[project hash_type]).accessible_by(current_ability)
  end

  # GET /hash_lists/1 or /hash_lists/1.json
  def show; end

  # GET /hash_lists/new
  def new
    @hash_list = HashList.new
  end

  # GET /hash_lists/1/edit
  def edit; end

  # POST /hash_lists or /hash_lists.json
  def create
    @hash_list = HashList.new(hash_list_params)

    respond_to do |format|
      if @hash_list.save
        format.html { redirect_to hash_list_url(@hash_list), notice: "Hash list was successfully created." }
        format.json { render :show, status: :created, location: @hash_list }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @hash_list.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /hash_lists/1 or /hash_lists/1.json
  def update
    respond_to do |format|
      if @hash_list.update(hash_list_params)
        format.html { redirect_to hash_list_url(@hash_list), notice: "Hash list was successfully updated." }
        format.json { render :show, status: :ok, location: @hash_list }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @hash_list.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /hash_lists/1 or /hash_lists/1.json
  def destroy
    @hash_list.destroy!

    respond_to do |format|
      format.html { redirect_to hash_lists_url, notice: "Hash list was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Only allow a list of trusted parameters through.
  def hash_list_params
    params.require(:hash_list).permit(:name, :description, :file, :line_count, :sensitive, :hash_mode)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_hash_list
    @hash_list = HashList.find(params[:id])
  end
end
