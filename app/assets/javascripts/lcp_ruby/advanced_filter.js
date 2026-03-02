// LCP Ruby — Advanced Filter Builder
// Vanilla JS, IIFE pattern, event delegation
(function() {
  "use strict";

  var KNOWN_OPERATORS = [
    "eq", "not_eq", "cont", "not_cont", "start", "not_start", "end", "not_end",
    "gt", "gteq", "lt", "lteq", "between", "in", "not_in",
    "present", "blank", "null", "not_null",
    "true", "not_true", "false", "not_false",
    "last_n_days", "this_week", "this_month", "this_quarter", "this_year"
  ];

  // Sort by length desc so longer operator names match first
  var SORTED_OPERATORS = KNOWN_OPERATORS.slice().sort(function(a, b) { return b.length - a.length; });

  function t(key, fallback) {
    var parts = key.split(".");
    var obj = window.LcpI18n;
    for (var i = 0; i < parts.length; i++) {
      if (!obj) return fallback || key;
      obj = obj[parts[i]];
    }
    return obj || fallback || key;
  }

  function initFilterBuilders() {
    var containers = document.querySelectorAll(".lcp-advanced-filter");
    for (var i = 0; i < containers.length; i++) {
      if (!containers[i].dataset.lcpFilterInitialized) {
        initFilterBuilder(containers[i]);
        containers[i].dataset.lcpFilterInitialized = "true";
      }
    }
  }

  function initFilterBuilder(container) {
    var metadata = JSON.parse(container.dataset.lcpFilterMetadata);
    var actionUrl = container.dataset.lcpFilterAction;
    var rowsContainer = container.querySelector(".lcp-filter-rows");
    var state = parseCurrentFiltersFromUrl(metadata);

    // If there are active filters, auto-expand
    if (state.conditions.length > 0 || state.groups.length > 0) {
      var body = container.querySelector(".lcp-filter-body");
      if (body) body.style.display = "";
    }

    renderFilterRows(rowsContainer, state, metadata);

    // Toggle button
    container.querySelector(".lcp-filter-toggle-btn").addEventListener("click", function() {
      var body = container.querySelector(".lcp-filter-body");
      if (body.style.display === "none") {
        body.style.display = "";
        // Add initial row if empty
        if (state.conditions.length === 0 && state.groups.length === 0) {
          state.conditions.push({ field: "", operator: "", value: "" });
          renderFilterRows(rowsContainer, state, metadata);
        }
      } else {
        body.style.display = "none";
      }
    });

    // Add filter
    container.querySelector(".lcp-filter-add-btn").addEventListener("click", function() {
      state.conditions.push({ field: "", operator: "", value: "" });
      renderFilterRows(rowsContainer, state, metadata);
    });

    // Add OR group
    var addGroupBtn = container.querySelector(".lcp-filter-add-group-btn");
    if (addGroupBtn) {
      addGroupBtn.addEventListener("click", function() {
        state.groups.push({ combinator: "or", conditions: [{ field: "", operator: "", value: "" }] });
        renderFilterRows(rowsContainer, state, metadata);
      });
    }

    // Apply filters
    container.querySelector(".lcp-filter-apply-btn").addEventListener("click", function() {
      applyFilters(actionUrl, state);
    });

    // Clear filters
    container.querySelector(".lcp-filter-clear-btn").addEventListener("click", function() {
      clearFilters(actionUrl);
    });
  }

  function parseCurrentFiltersFromUrl(metadata) {
    var params = new URLSearchParams(window.location.search);
    var conditions = [];
    var groups = [];
    var fieldNames = metadata.fields.map(function(f) { return f.name; });

    // Sort field names by length desc so "category.name" matches before "name"
    var sortedFieldNames = fieldNames.slice().sort(function(a, b) { return b.length - a.length; });

    params.forEach(function(value, key) {
      // Match f[key]=value or f[g][idx][key]=value
      var topMatch = key.match(/^f\[([^\]]+)\]$/);
      if (topMatch) {
        var ransackKey = topMatch[1];
        // Skip group params
        if (ransackKey === "g") return;

        var parsed = parseRansackKey(ransackKey, sortedFieldNames);
        if (parsed) {
          conditions.push({ field: parsed.field, operator: parsed.operator, value: value });
        }
      }
    });

    // Parse grouped conditions: f[g][0][m]=or, f[g][0][field_pred]=value
    var groupParams = {};
    params.forEach(function(value, key) {
      var groupMatch = key.match(/^f\[g\]\[(\d+)\]\[([^\]]+)\]$/);
      if (groupMatch) {
        var idx = groupMatch[1];
        var subKey = groupMatch[2];
        if (!groupParams[idx]) groupParams[idx] = {};
        groupParams[idx][subKey] = value;
      }
    });

    Object.keys(groupParams).forEach(function(idx) {
      var gp = groupParams[idx];
      var combinator = gp.m || "or";
      delete gp.m;
      var groupConditions = [];
      Object.keys(gp).forEach(function(ransackKey) {
        var parsed = parseRansackKey(ransackKey, sortedFieldNames);
        if (parsed) {
          groupConditions.push({ field: parsed.field, operator: parsed.operator, value: gp[ransackKey] });
        }
      });
      if (groupConditions.length > 0) {
        groups.push({ combinator: combinator, conditions: groupConditions });
      }
    });

    return { conditions: conditions, groups: groups };
  }

  function parseRansackKey(ransackKey, sortedFieldNames) {
    // Try to match known field names (in Ransack format: dots become underscores)
    for (var i = 0; i < sortedFieldNames.length; i++) {
      var fieldName = sortedFieldNames[i];
      var ransackField = fieldName.replace(/\./g, "_");
      if (ransackKey.indexOf(ransackField + "_") === 0) {
        var operatorSuffix = ransackKey.substring(ransackField.length + 1);
        if (KNOWN_OPERATORS.indexOf(operatorSuffix) !== -1) {
          return { field: fieldName, operator: operatorSuffix };
        }
      }
    }
    // Fallback: try to extract any known operator suffix
    for (var j = 0; j < SORTED_OPERATORS.length; j++) {
      var op = SORTED_OPERATORS[j];
      var suffix = "_" + op;
      if (ransackKey.length > suffix.length && ransackKey.slice(-suffix.length) === suffix) {
        var field = ransackKey.slice(0, -suffix.length).replace(/_/g, ".");
        return { field: field, operator: op };
      }
    }
    return null;
  }

  function renderFilterRows(container, state, metadata) {
    // Destroy existing Tom Select instances
    destroyTomSelectInstances(container);
    container.innerHTML = "";

    state.conditions.forEach(function(condition, idx) {
      if (idx > 0) {
        var combinator = document.createElement("div");
        combinator.className = "lcp-filter-combinator";
        combinator.textContent = t("filter.combinator_and", "AND");
        container.appendChild(combinator);
      }
      addConditionRow(container, condition, metadata, function() {
        state.conditions.splice(idx, 1);
        renderFilterRows(container, state, metadata);
      });
    });

    state.groups.forEach(function(group, gIdx) {
      if (state.conditions.length > 0 || gIdx > 0) {
        var combinator = document.createElement("div");
        combinator.className = "lcp-filter-combinator";
        combinator.textContent = t("filter.combinator_and", "AND");
        container.appendChild(combinator);
      }
      addGroupBlock(container, group, metadata, function() {
        state.groups.splice(gIdx, 1);
        renderFilterRows(container, state, metadata);
      }, function() {
        renderFilterRows(container, state, metadata);
      });
    });
  }

  function addConditionRow(parent, condition, metadata, onRemove) {
    var row = document.createElement("div");
    row.className = "lcp-filter-row";

    // Field select
    var fieldSelect = renderFieldSelect(metadata, condition.field);
    row.appendChild(fieldSelect);

    // Operator select (populated based on field)
    var operatorContainer = document.createElement("div");
    operatorContainer.className = "lcp-filter-operator-select";
    row.appendChild(operatorContainer);

    // Value input (populated based on field + operator)
    var valueContainer = document.createElement("div");
    valueContainer.className = "lcp-filter-value-input";
    row.appendChild(valueContainer);

    // Remove button
    var removeBtn = document.createElement("button");
    removeBtn.type = "button";
    removeBtn.className = "lcp-filter-remove-btn";
    removeBtn.innerHTML = "&times;";
    removeBtn.addEventListener("click", onRemove);
    row.appendChild(removeBtn);

    parent.appendChild(row);

    var fieldMeta = findFieldMeta(metadata, condition.field);
    if (fieldMeta) {
      renderOperatorSelect(operatorContainer, metadata, fieldMeta, condition.operator, function(op) {
        condition.operator = op;
        renderValueInput(valueContainer, metadata, fieldMeta, op, condition, function(val) {
          condition.value = val;
        });
      });
      renderValueInput(valueContainer, metadata, fieldMeta, condition.operator, condition, function(val) {
        condition.value = val;
      });
    }

    // Field change handler
    fieldSelect.querySelector("select").addEventListener("change", function(e) {
      condition.field = e.target.value;
      condition.operator = "";
      condition.value = "";
      var newFieldMeta = findFieldMeta(metadata, condition.field);

      destroyTomSelectInstances(operatorContainer);
      operatorContainer.innerHTML = "";
      destroyTomSelectInstances(valueContainer);
      valueContainer.innerHTML = "";

      if (newFieldMeta) {
        renderOperatorSelect(operatorContainer, metadata, newFieldMeta, "", function(op) {
          condition.operator = op;
          destroyTomSelectInstances(valueContainer);
          valueContainer.innerHTML = "";
          renderValueInput(valueContainer, metadata, newFieldMeta, op, condition, function(val) {
            condition.value = val;
          });
        });
      }
    });
  }

  function addGroupBlock(parent, group, metadata, onRemoveGroup, onRerender) {
    var block = document.createElement("div");
    block.className = "lcp-filter-group";

    var header = document.createElement("div");
    header.className = "lcp-filter-group-header";

    var label = document.createElement("span");
    label.className = "lcp-filter-group-label";
    label.textContent = t("filter.group_label", "OR");
    header.appendChild(label);

    var removeGroupBtn = document.createElement("button");
    removeGroupBtn.type = "button";
    removeGroupBtn.className = "lcp-filter-group-remove";
    removeGroupBtn.textContent = t("filter.remove_group", "Remove group");
    removeGroupBtn.addEventListener("click", onRemoveGroup);
    header.appendChild(removeGroupBtn);

    block.appendChild(header);

    var rowsContainer = document.createElement("div");
    rowsContainer.className = "lcp-filter-group-rows";

    group.conditions.forEach(function(condition, cIdx) {
      if (cIdx > 0) {
        var combinator = document.createElement("div");
        combinator.className = "lcp-filter-combinator";
        combinator.textContent = t("filter.group_label", "OR");
        rowsContainer.appendChild(combinator);
      }
      addConditionRow(rowsContainer, condition, metadata, function() {
        group.conditions.splice(cIdx, 1);
        if (group.conditions.length === 0) {
          onRemoveGroup();
        } else {
          onRerender();
        }
      });
    });

    block.appendChild(rowsContainer);

    var addBtn = document.createElement("button");
    addBtn.type = "button";
    addBtn.className = "btn lcp-filter-group-add-btn";
    addBtn.textContent = t("filter.add_condition", "+ Add condition");
    addBtn.addEventListener("click", function() {
      group.conditions.push({ field: "", operator: "", value: "" });
      onRerender();
    });
    block.appendChild(addBtn);

    parent.appendChild(block);
  }

  function renderFieldSelect(metadata, selectedField) {
    var wrapper = document.createElement("div");
    wrapper.className = "lcp-filter-field-select";

    var select = document.createElement("select");
    select.innerHTML = '<option value="">' + t("filter.select_field", "Select field...") + '</option>';

    // Group fields by group
    var groups = {};
    var directFields = [];
    metadata.fields.forEach(function(f) {
      if (f.group) {
        if (!groups[f.group]) groups[f.group] = [];
        groups[f.group].push(f);
      } else {
        directFields.push(f);
      }
    });

    // Direct fields
    if (directFields.length > 0) {
      var optgroup = document.createElement("optgroup");
      optgroup.label = t("filter.field_groups_direct", "Fields");
      directFields.forEach(function(f) {
        var opt = document.createElement("option");
        opt.value = f.name;
        opt.textContent = f.label;
        if (f.name === selectedField) opt.selected = true;
        optgroup.appendChild(opt);
      });
      select.appendChild(optgroup);
    }

    // Grouped fields (associations)
    Object.keys(groups).forEach(function(groupName) {
      var optgroup = document.createElement("optgroup");
      optgroup.label = groupName;
      groups[groupName].forEach(function(f) {
        var opt = document.createElement("option");
        opt.value = f.name;
        opt.textContent = f.label;
        if (f.name === selectedField) opt.selected = true;
        optgroup.appendChild(opt);
      });
      select.appendChild(optgroup);
    });

    wrapper.appendChild(select);

    // Initialize Tom Select on field selects for better UX
    if (typeof TomSelect !== "undefined") {
      new TomSelect(select, {
        allowEmptyOption: true,
        controlInput: null
      });
    }

    return wrapper;
  }

  function renderOperatorSelect(container, metadata, fieldMeta, selectedOp, onChange) {
    var select = document.createElement("select");
    select.innerHTML = '<option value="">' + t("filter.select_operator", "Select operator...") + '</option>';

    var operators = fieldMeta.operators || [];
    operators.forEach(function(op) {
      var option = document.createElement("option");
      option.value = op;
      option.textContent = metadata.operator_labels[op] || op;
      if (op === selectedOp) option.selected = true;
      select.appendChild(option);
    });

    container.appendChild(select);

    select.addEventListener("change", function() {
      onChange(select.value);
    });
  }

  function renderValueInput(container, metadata, fieldMeta, operator, condition, onChange) {
    destroyTomSelectInstances(container);
    container.innerHTML = "";

    if (!operator) return;

    // No-value operators
    if (metadata.no_value_operators.indexOf(operator) !== -1) {
      return; // No value input needed
    }

    var fieldType = fieldMeta.type;
    var value = condition.value || "";

    // Range operators (between)
    if (metadata.range_operators.indexOf(operator) !== -1) {
      renderBetweenInput(container, fieldType, value, onChange);
      return;
    }

    // Parameterized operators (last_n_days)
    if (metadata.parameterized_operators.indexOf(operator) !== -1) {
      renderParameterizedInput(container, value, onChange);
      return;
    }

    // Multi-value operators
    if (metadata.multi_value_operators.indexOf(operator) !== -1) {
      if (fieldMeta.enum_values) {
        renderMultiEnumSelect(container, fieldMeta.enum_values, value, onChange);
      } else {
        renderMultiValueTextarea(container, value, onChange);
      }
      return;
    }

    // Enum + single-value operators
    if (fieldMeta.enum_values && (operator === "eq" || operator === "not_eq")) {
      renderEnumSelect(container, fieldMeta.enum_values, value, onChange);
      return;
    }

    // Type-specific inputs
    switch (fieldType) {
      case "date":
        renderInput(container, "date", value, onChange);
        break;
      case "datetime":
        renderInput(container, "datetime-local", value, onChange);
        break;
      case "integer":
      case "float":
      case "decimal":
        renderInput(container, "number", value, onChange);
        break;
      default:
        renderInput(container, "text", value, onChange);
    }
  }

  function renderInput(container, type, value, onChange) {
    var input = document.createElement("input");
    input.type = type;
    input.value = value;
    input.placeholder = t("filter.enter_value", "Enter value...");

    if (type === "number") {
      input.step = "any";
    }

    input.addEventListener("input", function() {
      onChange(input.value);
    });
    container.appendChild(input);
  }

  function renderBetweenInput(container, fieldType, value, onChange) {
    var wrapper = document.createElement("div");
    wrapper.className = "lcp-filter-between";

    var vals = Array.isArray(value) ? value : (typeof value === "string" && value.includes(",") ? value.split(",") : [value || "", ""]);

    var inputType = "text";
    if (fieldType === "date") inputType = "date";
    else if (fieldType === "datetime") inputType = "datetime-local";
    else if (fieldType === "integer" || fieldType === "float" || fieldType === "decimal") inputType = "number";

    var fromInput = document.createElement("input");
    fromInput.type = inputType;
    fromInput.value = vals[0] || "";
    fromInput.placeholder = t("filter.enter_value", "Enter value...");
    if (inputType === "number") fromInput.step = "any";

    var separator = document.createElement("span");
    separator.className = "lcp-filter-between-separator";
    separator.textContent = t("filter.between_separator", "\u2014");

    var toInput = document.createElement("input");
    toInput.type = inputType;
    toInput.value = vals[1] || "";
    toInput.placeholder = t("filter.enter_value", "Enter value...");
    if (inputType === "number") toInput.step = "any";

    function emitChange() {
      onChange([fromInput.value, toInput.value]);
    }

    fromInput.addEventListener("input", emitChange);
    toInput.addEventListener("input", emitChange);

    wrapper.appendChild(fromInput);
    wrapper.appendChild(separator);
    wrapper.appendChild(toInput);
    container.appendChild(wrapper);
  }

  function renderParameterizedInput(container, value, onChange) {
    var wrapper = document.createElement("div");
    wrapper.className = "lcp-filter-parameterized";

    var input = document.createElement("input");
    input.type = "number";
    input.min = "1";
    input.value = value || "";
    input.placeholder = "N";

    var suffix = document.createElement("span");
    suffix.className = "lcp-filter-parameterized-suffix";
    suffix.textContent = t("filter.last_n_days_suffix", "days");

    input.addEventListener("input", function() {
      onChange(input.value);
    });

    wrapper.appendChild(input);
    wrapper.appendChild(suffix);
    container.appendChild(wrapper);
  }

  function renderEnumSelect(container, enumValues, value, onChange) {
    var select = document.createElement("select");
    select.innerHTML = '<option value="">' + t("filter.select_field", "Select...") + '</option>';

    enumValues.forEach(function(ev) {
      var opt = document.createElement("option");
      opt.value = ev[0];
      opt.textContent = ev[1];
      if (ev[0] === value) opt.selected = true;
      select.appendChild(opt);
    });

    select.addEventListener("change", function() {
      onChange(select.value);
    });

    container.appendChild(select);

    if (typeof TomSelect !== "undefined") {
      new TomSelect(select, { allowEmptyOption: true });
    }
  }

  function renderMultiEnumSelect(container, enumValues, value, onChange) {
    var select = document.createElement("select");
    select.multiple = true;

    var selectedValues = Array.isArray(value) ? value : (typeof value === "string" && value ? value.split(",") : []);

    enumValues.forEach(function(ev) {
      var opt = document.createElement("option");
      opt.value = ev[0];
      opt.textContent = ev[1];
      if (selectedValues.indexOf(ev[0]) !== -1) opt.selected = true;
      select.appendChild(opt);
    });

    container.appendChild(select);

    if (typeof TomSelect !== "undefined") {
      var ts = new TomSelect(select, {
        plugins: ["remove_button"],
        onItemAdd: emitMultiChange,
        onItemRemove: emitMultiChange
      });

      function emitMultiChange() {
        onChange(ts.getValue());
      }
    } else {
      select.addEventListener("change", function() {
        var vals = [];
        for (var i = 0; i < select.options.length; i++) {
          if (select.options[i].selected) vals.push(select.options[i].value);
        }
        onChange(vals);
      });
    }
  }

  function renderMultiValueTextarea(container, value, onChange) {
    var textarea = document.createElement("textarea");
    textarea.rows = 2;
    textarea.placeholder = t("filter.enter_values", "Enter values separated by commas");
    textarea.value = Array.isArray(value) ? value.join(", ") : (value || "");

    textarea.addEventListener("input", function() {
      var vals = textarea.value.split(",").map(function(v) { return v.trim(); }).filter(Boolean);
      onChange(vals);
    });
    container.appendChild(textarea);
  }

  function applyFilters(actionUrl, state) {
    var params = buildUrlParams(state);
    var url = new URL(actionUrl, window.location.origin);

    // Preserve qs and filter params
    var currentParams = new URLSearchParams(window.location.search);
    if (currentParams.has("qs")) url.searchParams.set("qs", currentParams.get("qs"));
    if (currentParams.has("filter")) url.searchParams.set("filter", currentParams.get("filter"));

    // Add filter params
    Object.keys(params).forEach(function(key) {
      var val = params[key];
      if (Array.isArray(val)) {
        val.forEach(function(v) {
          url.searchParams.append(key, v);
        });
      } else {
        url.searchParams.set(key, val);
      }
    });

    // Do not preserve page param (reset to page 1)
    window.location.href = url.toString();
  }

  function clearFilters(actionUrl) {
    var url = new URL(actionUrl, window.location.origin);
    var currentParams = new URLSearchParams(window.location.search);

    // Preserve only qs and filter
    if (currentParams.has("qs")) url.searchParams.set("qs", currentParams.get("qs"));
    if (currentParams.has("filter")) url.searchParams.set("filter", currentParams.get("filter"));

    window.location.href = url.toString();
  }

  function encodeCondition(params, prefix, condition) {
    if (!condition.field || !condition.operator) return;
    var ransackField = condition.field.replace(/\./g, "_");
    var key = prefix + "[" + ransackField + "_" + condition.operator + "]";

    if (Array.isArray(condition.value)) {
      if (condition.value.length === 2 && condition.operator === "between") {
        params[prefix + "[" + ransackField + "_gteq]"] = condition.value[0];
        params[prefix + "[" + ransackField + "_lteq]"] = condition.value[1];
        return;
      }
      condition.value.forEach(function(v) {
        if (!params[key + "[]"]) params[key + "[]"] = [];
        if (!Array.isArray(params[key + "[]"])) params[key + "[]"] = [params[key + "[]"]];
        params[key + "[]"].push(v);
      });
    } else {
      params[key] = condition.value;
    }
  }

  function buildUrlParams(state) {
    var params = {};

    state.conditions.forEach(function(c) {
      encodeCondition(params, "f", c);
    });

    state.groups.forEach(function(group, gIdx) {
      var prefix = "f[g][" + gIdx + "]";
      params[prefix + "[m]"] = group.combinator || "or";
      group.conditions.forEach(function(c) {
        encodeCondition(params, prefix, c);
      });
    });

    return params;
  }

  function findFieldMeta(metadata, fieldName) {
    if (!fieldName) return null;
    for (var i = 0; i < metadata.fields.length; i++) {
      if (metadata.fields[i].name === fieldName) return metadata.fields[i];
    }
    return null;
  }

  function destroyTomSelectInstances(container) {
    var selects = container.querySelectorAll("select");
    for (var i = 0; i < selects.length; i++) {
      if (selects[i].tomselect) {
        selects[i].tomselect.destroy();
      }
    }
  }

  // Initialize on DOM ready
  document.addEventListener("DOMContentLoaded", initFilterBuilders);

  // Also handle Turbo/Turbolinks page transitions
  document.addEventListener("turbo:load", initFilterBuilders);
  document.addEventListener("turbolinks:load", initFilterBuilders);
})();
