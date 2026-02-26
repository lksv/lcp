define_presenter :showcase_recipes do
  model :showcase_recipe
  label "Recipes (Structured)"
  slug "showcase-recipes"
  icon "book-open"

  index do
    description "Demonstrates JSON field nested editing, virtual models, and sub-sections."
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column :title, link_to: :show, sortable: true
    column :cuisine, renderer: :badge, options: {
      color_map: {
        italian: "green", mexican: "orange", japanese: "red",
        indian: "yellow", french: "blue", other: "gray"
      }
    }
    column :servings, renderer: :number
  end

  show do
    description "Recipe details with inline steps and structured ingredients."

    section "Overview", columns: 2 do
      field :title, renderer: :heading
      field :cuisine, renderer: :badge, options: {
        color_map: {
          italian: "green", mexican: "orange", japanese: "red",
          indian: "yellow", french: "blue", other: "gray"
        }
      }
      field :servings, renderer: :number
    end

    json_items_list "Steps", json_field: :steps, columns: 2,
      empty_message: "No steps defined." do
      field :instruction, type: :string, label: "Instruction"
      field :duration_minutes, type: :integer, label: "Duration (min)"
    end

    json_items_list "Ingredients", json_field: :ingredients, target_model: :ingredient_def,
      empty_message: "No ingredients." do
      section "Item", columns: 3 do
        field :name
        field :quantity
        field :unit
      end
      section "Extra", columns: 2 do
        field :notes
        field :optional
      end
    end

    section "Metadata", columns: 2 do
      field :created_at, renderer: :relative_date
      field :updated_at, renderer: :relative_date
    end
  end

  form do
    description "Inline JSON editing with two approaches: presenter-defined fields (Steps) and virtual model fields with sub-sections (Ingredients)."

    section "Recipe Details", columns: 2 do
      field :title, placeholder: "Enter recipe title...", autofocus: true
      field :cuisine, input_type: :select
      field :servings, input_type: :number
    end

    nested_fields "Steps", json_field: :steps,
      description: "Each step is a JSON object. Field types are defined inline in the presenter — no model needed.",
      allow_add: true, allow_remove: true, sortable: true,
      add_label: "Add Step", empty_message: "No steps yet.", columns: 2 do
      field :instruction, type: :string, label: "Instruction"
      field :duration_minutes, type: :integer, label: "Duration (min)", input_type: :number
    end

    nested_fields "Ingredients", json_field: :ingredients, target_model: :ingredient_def,
      description: "Item structure comes from the ingredient_def virtual model. Fields are grouped into collapsible sub-sections.",
      allow_add: true, allow_remove: true, sortable: true,
      add_label: "Add Ingredient", empty_message: "No ingredients yet." do
      section "Item", columns: 2 do
        field :name, placeholder: "e.g. Flour"
        field :quantity, placeholder: "e.g. 200"
        field :unit, input_type: :select
      end
      section "Extra", columns: 1, collapsible: true, collapsed: true do
        field :notes, input_type: :textarea, input_options: { rows: 2 }
        field :optional, input_type: :checkbox
      end
    end
  end

  search do
    searchable_fields :title
    placeholder "Search recipes..."
  end

  action :create, type: :built_in, on: :collection, label: "New Recipe", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
