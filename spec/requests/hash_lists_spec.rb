require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to test the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator. If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails. There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.

RSpec.describe "/hash_lists", type: :request do
  # This should return the minimal set of attributes required to create a valid
  # HashList. As you add validations to HashList, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {
    skip("Add a hash of attributes valid for your model")
  }

  let(:invalid_attributes) {
    skip("Add a hash of attributes invalid for your model")
  }

  describe "GET /index" do
    it "renders a successful response" do
      HashList.create! valid_attributes
      get hash_lists_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      hash_list = HashList.create! valid_attributes
      get hash_list_url(hash_list)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_hash_list_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      hash_list = HashList.create! valid_attributes
      get edit_hash_list_url(hash_list)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new HashList" do
        expect {
          post hash_lists_url, params: { hash_list: valid_attributes }
        }.to change(HashList, :count).by(1)
      end

      it "redirects to the created hash_list" do
        post hash_lists_url, params: { hash_list: valid_attributes }
        expect(response).to redirect_to(hash_list_url(HashList.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new HashList" do
        expect {
          post hash_lists_url, params: { hash_list: invalid_attributes }
        }.to change(HashList, :count).by(0)
      end


      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post hash_lists_url, params: { hash_list: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) {
        skip("Add a hash of attributes valid for your model")
      }

      it "updates the requested hash_list" do
        hash_list = HashList.create! valid_attributes
        patch hash_list_url(hash_list), params: { hash_list: new_attributes }
        hash_list.reload
        skip("Add assertions for updated state")
      end

      it "redirects to the hash_list" do
        hash_list = HashList.create! valid_attributes
        patch hash_list_url(hash_list), params: { hash_list: new_attributes }
        hash_list.reload
        expect(response).to redirect_to(hash_list_url(hash_list))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        hash_list = HashList.create! valid_attributes
        patch hash_list_url(hash_list), params: { hash_list: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested hash_list" do
      hash_list = HashList.create! valid_attributes
      expect {
        delete hash_list_url(hash_list)
      }.to change(HashList, :count).by(-1)
    end

    it "redirects to the hash_lists list" do
      hash_list = HashList.create! valid_attributes
      delete hash_list_url(hash_list)
      expect(response).to redirect_to(hash_lists_url)
    end
  end
end