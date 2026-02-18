# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Controller for managing hash lists.
#
# This controller provides actions to manage hash lists, such as listing, creating, updating,
# viewing, and deleting hash lists. It ensures user authentication and authorization before
# performing any actions.
#
# Filters:
# - `authenticate_user!`: Ensures only authenticated users can access actions.
# - `set_projects`: Sets the list of accessible projects for specific actions.
# - `load_and_authorize_resource`: Handles resource loading and checks authorization.
class HashListsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_projects, only: %i[new edit create update]
  load_and_authorize_resource

  # GET /hash_lists or /hash_lists.json
  #
  # Fetches all hash lists that are accessible by the current user based on their abilities.
  # The method preloads associated `project` and `hash_type` records for optimization.
  #
  # @return [void] The method does not return a value but assigns the filtered and preloaded hash lists to the instance variable `@hash_lists`.
  #   - `@hash_lists` contains the collection of hash lists accessible by the current user's abilities.
  def index
    @hash_lists = HashList.includes(%i[project hash_type]).accessible_by(current_ability).chronological
  end

  # GET /hash_lists/:id or /hash_lists/:id.json
  #
  # Retrieves and displays the hash list along with its associated hash items.
  # Hash items are fetched in descending order of their creation date and can be filtered
  # based on their state (e.g., uncracked, cracked, or all). Pagination is applied to
  # the hash items, limiting the number of displayed items per page, and the method also
  # leverages HTTP caching to improve performance.
  #
  # - If `params[:item_state]` is "uncracked", only uncracked hash items are displayed.
  # - If `params[:item_state]` is "cracked", only cracked hash items are displayed.
  # - If `params[:item_state]` is not specified or is invalid, all hash items are displayed by default.
  #
  # @return [void] The method assigns several instance variables:
  #   - `@hash_items`: The filtered and paginated collection of hash items.
  #   - `@state`: The current filtering state, indicating the applied filter ("uncracked", "cracked", or "all").
  #   - `@pagy`: Pagy instance to handle pagination metadata for the view layer.
  def show
    @hash_items = @hash_list.hash_items.order(created_at: :desc)

    case params[:item_state]
    when "uncracked"
      @hash_items = @hash_items.uncracked
      @state = "uncracked"
    when "cracked"
      @hash_items = @hash_items.cracked
      @state = "cracked"
    else
      @hash_items = @hash_items
      @state = "all"
    end

    @pagy, @hash_items = pagy(@hash_items, items: 50, anchor_string: 'data-remote="true"')
    fresh_when(@hash_list)
  end

  # GET /resource/new
  #
  # Initializes a new instance of the resource. Typically used to prepare a form
  # for creating a new resource.
  #
  # This method does not perform any database operations or persist data. It is
  # intended for setting up a fresh resource object for user interaction.
  #
  # @return [void] The method does not return a value but is expected to prepare a fresh instance of the resource.
  def new; end

  # GET /hash_lists/:id/edit
  #
  # Prepares the necessary data and state for editing an existing hash list.
  #
  # This method does not perform any database operations or modifications. Its main purpose is to
  # set up the context required for rendering the edit form, ensuring that the `@hash_list` and
  # any related data are available for the view.
  #
  # @return [void] The method does not explicitly return a value but is expected to provide
  #   the necessary data and state for the edit view.
  def edit; end

  # POST /hash_lists or /hash_lists.json
  def create
    @hash_list = HashList.new(hash_list_params)
    @hash_list.creator = current_user

    respond_to do |format|
      if @hash_list.save
        format.html { redirect_to hash_list_url(@hash_list), notice: "Hash list was successfully created." }
        format.json { render :show, status: :created, location: @hash_list }
      else
        format.html { render :new, status: :unprocessable_content, error: "Hash list could not be created." }
        format.json { render json: @hash_list.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /hash_lists/:id or /hash_lists/:id.json
  #
  # Updates the attributes of an existing hash list and triggers associated processes if required.
  # If a file is provided as part of the update, the hash list's `processed` attribute is set to `false`,
  # and background processing of the hash list is scheduled via the `ProcessHashListJob`.
  #
  # Responds to both HTML and JSON formats:
  # - On successful update, redirects or renders the updated hash list.
  # - On failure, re-renders the edit form or returns an error response.
  #
  # @return [void] The method does not explicitly return a value. It handles rendering or redirecting based on the outcome.
  #   - On success, the response includes information about the updated hash list.
  #   - On failure, the response includes validation errors for the hash list.
  def update
    if hash_list_params[:file].present?
      @hash_list.processed = false
    end

    respond_to do |format|
      if @hash_list.update(hash_list_params)
        ProcessHashListJob.perform_later(@hash_list.id) if hash_list_params[:file].present?
        format.html { redirect_to hash_list_url(@hash_list), notice: "Hash list was successfully updated." }
        format.json { render :show, status: :ok, location: @hash_list }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @hash_list.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /hash_lists/:id or /hash_lists/:id.json
  #
  # Permanently deletes the specified hash list from the database using a destructive operation.
  # The `destroy!` method is used and will raise an exception if the record cannot be destroyed.
  #
  # Responds to both HTML and JSON formats:
  # - For HTML, redirects to the hash lists index page with a success notice.
  # - For JSON, responds with `head :no_content` to indicate successful deletion without a response body.
  #
  # @return [void] The method does not explicitly return a value but performs the following actions:
  #   - Permanently removes the hash list from the database.
  #   - Redirects or responds based on the specified format.
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
    params.expect(hash_list: %i[name description file line_count sensitive project_id hash_type_id])
  end

  def set_projects
    @projects = Project.accessible_by(current_ability).chronological
  end
end
