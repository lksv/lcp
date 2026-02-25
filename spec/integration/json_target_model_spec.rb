require "spec_helper"
require "support/integration_helper"

RSpec.describe "JSON Field with Target Model", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("json_target_model_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("json_target_model_test")
  end

  before(:each) do
    load_integration_metadata!("json_target_model_test")
    stub_current_user(role: "admin")
    LcpRuby.registry.model_for("recipe").delete_all
  end

  let(:recipe_model) { LcpRuby.registry.model_for("recipe") }

  describe "virtual model loading" do
    it "does not register virtual model in registry" do
      expect { LcpRuby.registry.model_for("step_definition") }.to raise_error(LcpRuby::Error)
    end

    it "keeps virtual model definition in loader" do
      expect(LcpRuby.loader.model_definitions["step_definition"]).to be_present
    end
  end

  describe "form rendering with target_model" do
    it "renders form with json_field section" do
      get "/recipes/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Steps")
      expect(response.body).to include("Add Step")
      expect(response.body).to include("lcp-nested-section")
    end

    it "renders existing items on edit form" do
      recipe = recipe_model.create!(
        title: "Pasta",
        steps: [
          { "instruction" => "Boil water", "duration_minutes" => "10" },
          { "instruction" => "Add pasta", "duration_minutes" => "8" }
        ]
      )

      get "/recipes/#{recipe.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Boil water")
      expect(response.body).to include("Add pasta")
    end
  end

  describe "CRUD with target_model validation" do
    it "creates a recipe with valid json field items" do
      expect {
        post "/recipes", params: {
          record: {
            title: "Pasta Recipe",
            steps: {
              "0" => { instruction: "Boil water", duration_minutes: "10", optional: "0" },
              "1" => { instruction: "Add pasta", duration_minutes: "8", optional: "0" }
            }
          }
        }
      }.to change { recipe_model.count }.by(1)

      expect(response).to have_http_status(:redirect)
      recipe = recipe_model.last
      expect(recipe.steps).to be_an(Array)
      expect(recipe.steps.size).to eq(2)
      expect(recipe.steps[0]["instruction"]).to eq("Boil water")
    end

    it "rejects items that fail target_model validations" do
      post "/recipes", params: {
        record: {
          title: "Validation Test",
          steps: {
            "0" => { instruction: "", duration_minutes: "5" }
          }
        }
      }

      # The item has blank instruction which violates presence validation
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates a recipe with valid items" do
      recipe = recipe_model.create!(title: "Update Test", steps: [ { "instruction" => "Old step" } ])

      patch "/recipes/#{recipe.id}", params: {
        record: {
          title: "Update Test",
          steps: {
            "0" => { instruction: "New step 1", duration_minutes: "5" },
            "1" => { instruction: "New step 2", duration_minutes: "10" }
          }
        }
      }

      expect(response).to have_http_status(:redirect)
      recipe.reload
      expect(recipe.steps.size).to eq(2)
      expect(recipe.steps[0]["instruction"]).to eq("New step 1")
    end

    it "removes items flagged with _destroy" do
      recipe = recipe_model.create!(title: "Remove Test", steps: [
        { "instruction" => "Keep" },
        { "instruction" => "Remove" }
      ])

      patch "/recipes/#{recipe.id}", params: {
        record: {
          title: "Remove Test",
          steps: {
            "0" => { instruction: "Keep", _destroy: "0" },
            "1" => { instruction: "Remove", _destroy: "1" }
          }
        }
      }

      expect(response).to have_http_status(:redirect)
      recipe.reload
      expect(recipe.steps.size).to eq(1)
      expect(recipe.steps[0]["instruction"]).to eq("Keep")
    end

    it "whitelists only target_model field keys" do
      post "/recipes", params: {
        record: {
          title: "Whitelist Test",
          steps: {
            "0" => { instruction: "Step", duration_minutes: "5", evil_field: "hacked" }
          }
        }
      }

      expect(response).to have_http_status(:redirect)
      recipe = recipe_model.last
      expect(recipe.steps[0].keys).not_to include("evil_field")
    end

    it "filters out blank items" do
      post "/recipes", params: {
        record: {
          title: "Blank Test",
          steps: {
            "0" => { instruction: "Valid step", duration_minutes: "5" },
            "1" => { instruction: "", duration_minutes: "", optional: "" }
          }
        }
      }

      expect(response).to have_http_status(:redirect)
      recipe = recipe_model.last
      expect(recipe.steps.size).to eq(1)
    end
  end
end
