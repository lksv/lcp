require "spec_helper"
require "support/integration_helper"

RSpec.describe "JSON Field Inline Mode", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("json_field_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("json_field_test")
  end

  before(:each) do
    load_integration_metadata!("json_field_test")
    stub_current_user(role: "admin")
    LcpRuby.registry.model_for("recipe").delete_all
  end

  let(:recipe_model) { LcpRuby.registry.model_for("recipe") }

  describe "form rendering" do
    it "renders json_field nested section on new form" do
      get "/recipes/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Steps")
      expect(response.body).to include("Add Step")
      expect(response.body).to include("lcp-nested-section")
    end

    it "renders json item fields with correct input types" do
      get "/recipes/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Instruction")
      expect(response.body).to include("Duration (min)")
      expect(response.body).to include("Optional")
    end

    it "renders data-lcp-condition-scope on json field rows" do
      recipe = recipe_model.create!(title: "Test", steps: [ { "instruction" => "Step 1" } ])

      get "/recipes/#{recipe.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-lcp-condition-scope")
    end

    it "renders template row for JS cloning" do
      get "/recipes/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-lcp-nested-template")
      expect(response.body).to include("NEW_RECORD")
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

  describe "CRUD with json field items" do
    it "creates a recipe with json field items" do
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
      expect(recipe.steps[1]["instruction"]).to eq("Add pasta")
    end

    it "updates a recipe with json field items" do
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

    it "enforces max item limit" do
      # Temporarily set max: 2 on the json_field section
      presenter = LcpRuby.loader.presenter_definitions["recipe"]
      json_section = presenter.form_config["sections"].find { |s| s["json_field"] == "steps" }
      json_section["max"] = 2

      post "/recipes", params: {
        record: {
          title: "Max Test",
          steps: {
            "0" => { instruction: "Step 1", duration_minutes: "1" },
            "1" => { instruction: "Step 2", duration_minutes: "2" },
            "2" => { instruction: "Step 3", duration_minutes: "3" }
          }
        }
      }

      # Max exceeded: record fails validation, re-renders form with error
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("too many items")
    ensure
      json_section&.delete("max")
    end

    it "whitelists only allowed field keys" do
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
  end
end
