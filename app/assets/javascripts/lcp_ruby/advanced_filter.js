// LCP Ruby — Advanced Filter Builder
// Vanilla JS, IIFE pattern, event delegation
// State model: recursive { combinator: "and"|"or", children: [leaf|group] }
//   leaf = { field, operator, value }
//   group = { combinator, children }
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

  var NO_VALUE_OPS = [
    "present", "blank", "null", "not_null", "true", "not_true", "false", "not_false",
    "this_week", "this_month", "this_quarter", "this_year"
  ];

  function t(key, fallback) {
    var parts = key.split(".");
    var obj = window.LcpI18n;
    for (var i = 0; i < parts.length; i++) {
      if (!obj) return fallback || key;
      obj = obj[parts[i]];
    }
    return obj || fallback || key;
  }

  function isLeaf(node) {
    return node && node.hasOwnProperty("field");
  }

  function isGroup(node) {
    return node && node.hasOwnProperty("children");
  }

  function hasActiveChildren(node) {
    if (!node || !node.children) return false;
    return node.children.length > 0;
  }

  function enterQlMode(container, toggleBtn, state) {
    var qlSection = container.querySelector(".lcp-ql-section");
    qlSection.style.display = "";
    container.querySelector(".lcp-filter-rows").style.display = "none";
    container.querySelector(".lcp-filter-actions-row").style.display = "none";
    toggleBtn.textContent = t("filter.ql_toggle_visual", "Visual mode");
    qlSection.querySelector(".lcp-ql-input").value = serializeToQl(state);
  }

  function emptyLeaf() {
    return { field: "", operator: "", value: "" };
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
    var maxNestingDepth = (metadata.config && metadata.config.max_nesting_depth) || 2;

    // State is always a root group
    var state = parseCurrentFiltersFromUrl(metadata);
    container._lcpFilterState = state;

    // If there are active filters, auto-expand
    if (hasActiveChildren(state)) {
      var body = container.querySelector(".lcp-filter-body");
      if (body) body.style.display = "";
    }

    // Render preset bar (if presets exist)
    renderPresetBar(container, metadata, actionUrl, state);

    renderChildren(rowsContainer, state, metadata, 1, maxNestingDepth);

    // Toggle button
    container.querySelector(".lcp-filter-toggle-btn").addEventListener("click", function() {
      var body = container.querySelector(".lcp-filter-body");
      if (body.style.display === "none") {
        body.style.display = "";
        // Add initial row if empty
        if (!hasActiveChildren(state)) {
          state.children.push(emptyLeaf());
          renderChildren(rowsContainer, state, metadata, 1, maxNestingDepth);
        }
      } else {
        body.style.display = "none";
      }
    });

    // Add filter
    container.querySelector(".lcp-filter-add-btn").addEventListener("click", function() {
      state.children.push(emptyLeaf());
      renderChildren(rowsContainer, state, metadata, 1, maxNestingDepth);
    });

    // Add OR group
    var addGroupBtn = container.querySelector(".lcp-filter-add-group-btn");
    if (addGroupBtn) {
      addGroupBtn.addEventListener("click", function() {
        // New sub-group combinator alternates from parent
        var childCombinator = state.combinator === "and" ? "or" : "and";
        state.children.push({ combinator: childCombinator, children: [emptyLeaf()] });
        renderChildren(rowsContainer, state, metadata, 1, maxNestingDepth);
      });
    }

    // QL toggle state — restore from URL param
    var qlMode = state._qlMode || false;
    var qlToggleBtn = container.querySelector(".lcp-ql-toggle-btn");

    // Apply filters
    container.querySelector(".lcp-filter-apply-btn").addEventListener("click", function() {
      if (qlMode) {
        applyFromQl(container, actionUrl, state, metadata, rowsContainer, maxNestingDepth);
      } else {
        applyFilters(actionUrl, state);
      }
    });

    // Clear filters
    container.querySelector(".lcp-filter-clear-btn").addEventListener("click", function() {
      clearFilters(actionUrl);
    });

    // QL toggle
    if (qlToggleBtn) {
      if (qlMode) enterQlMode(container, qlToggleBtn, state);

      qlToggleBtn.addEventListener("click", function() {
        qlMode = !qlMode;
        if (qlMode) {
          enterQlMode(container, qlToggleBtn, state);
        } else {
          var qlSection = container.querySelector(".lcp-ql-section");
          var textarea = qlSection.querySelector(".lcp-ql-input");
          var parseQlUrl = container.dataset.lcpParseQlUrl;
          if (textarea.value.trim()) {
            parseQlToState(textarea.value, parseQlUrl, state, function() {
              renderChildren(rowsContainer, state, metadata, 1, maxNestingDepth);
            });
          }
          qlSection.style.display = "none";
          container.querySelector(".lcp-filter-rows").style.display = "";
          container.querySelector(".lcp-filter-actions-row").style.display = "";
          qlToggleBtn.textContent = t("filter.ql_toggle", "Edit as QL");
        }
      });
    }
  }

  // --- Preset bar ---

  function renderPresetBar(container, metadata, actionUrl, state) {
    var presets = metadata.presets;
    if (!presets || presets.length === 0) return;

    var body = container.querySelector(".lcp-filter-body");
    if (!body) return;

    var bar = document.createElement("div");
    bar.className = "lcp-filter-presets";

    var label = document.createElement("span");
    label.className = "lcp-filter-presets-label";
    label.textContent = t("advanced_filter.presets_label", "Presets:");
    bar.appendChild(label);

    presets.forEach(function(preset) {
      var btn = document.createElement("button");
      btn.type = "button";
      btn.className = "lcp-preset-btn";
      btn.textContent = preset.label || preset.name;
      btn.dataset.presetName = preset.name;

      // Highlight if current filters match this preset
      if (matchesPreset(state, preset)) {
        btn.classList.add("active");
      }

      btn.addEventListener("click", function() {
        applyPreset(actionUrl, preset);
      });

      bar.appendChild(btn);
    });

    // Insert at the top of the filter body (before rows)
    body.insertBefore(bar, body.firstChild);
  }

  function matchesPreset(state, preset) {
    var conditions = preset.conditions || [];
    if (conditions.length === 0) return false;

    // Only match against flat AND conditions (no nested groups)
    var leaves = (state.children || []).filter(isLeaf);
    if (leaves.length !== conditions.length) return false;
    if (state.combinator !== "and") return false;

    // Every preset condition must match a leaf
    return conditions.every(function(pc) {
      return leaves.some(function(leaf) {
        if (leaf.field !== pc.field) return false;
        if (leaf.operator !== pc.operator) return false;

        // No-value operators: value is irrelevant for matching
        if (NO_VALUE_OPS.indexOf(pc.operator) !== -1) return true;

        // Value comparison: normalize to string for simple comparison
        var pcVal = pc.value;
        var leafVal = leaf.value;

        if (pcVal === undefined || pcVal === null) pcVal = "";
        if (leafVal === undefined || leafVal === null) leafVal = "";

        if (Array.isArray(pcVal) && Array.isArray(leafVal)) {
          return pcVal.length === leafVal.length &&
            pcVal.every(function(v, i) { return String(v) === String(leafVal[i]); });
        }

        return String(pcVal) === String(leafVal);
      });
    });
  }

  function applyPreset(actionUrl, preset) {
    var conditions = (preset.conditions || []).map(function(c) {
      return { field: c.field, operator: c.operator, value: c.value || "" };
    });

    var presetState = { combinator: "and", children: conditions };
    applyFilters(actionUrl, presetState);
  }

  // --- URL parsing: build recursive state from f[...] and f[g][...] params ---

  function parseCurrentFiltersFromUrl(metadata) {
    var params = new URLSearchParams(window.location.search);
    var rootChildren = [];
    var fieldNames = metadata.fields.map(function(f) { return f.name; });

    // Sort field names by length desc so "category.name" matches before "name"
    var sortedFieldNames = fieldNames.slice().sort(function(a, b) { return b.length - a.length; });

    // Collect cf[...] field names for parsing
    var cfFieldNames = metadata.fields
      .filter(function(f) { return f.custom_field && f.name.indexOf("cf[") === 0; })
      .map(function(f) { return f.name; });
    var cfBaseNames = cfFieldNames.map(function(n) {
      return n.substring(3, n.length - 1); // strip "cf[" and "]"
    }).sort(function(a, b) { return b.length - a.length; });

    // Collect all values by normalized key (strip trailing [] for array params).
    // URLSearchParams iterates f[key][]=v1, f[key][]=v2 as separate entries;
    // we merge them into a single array value.
    var collected = {};
    params.forEach(function(value, key) {
      var normalizedKey = key.replace(/\[\]$/, "");
      if (!collected[normalizedKey]) collected[normalizedKey] = [];
      collected[normalizedKey].push(value);
    });

    // Parse flat f[key] and cf[key] params as top-level leaf conditions
    Object.keys(collected).forEach(function(key) {
      var values = collected[key];

      // Match cf[key] (custom field filters)
      var cfMatch = key.match(/^cf\[([^\]]+)\]$/);
      if (cfMatch) {
        var cfKey = cfMatch[1];
        var cfParsed = parseCfKey(cfKey, cfBaseNames);
        if (cfParsed) {
          var cfValue = values.length === 1 ? values[0] : values;
          rootChildren.push({ field: "cf[" + cfParsed.field + "]", operator: cfParsed.operator, value: cfValue });
        }
        return;
      }

      // Match f[key] (skip group/combinator keys)
      var topMatch = key.match(/^f\[([^\]]+)\]$/);
      if (topMatch) {
        var ransackKey = topMatch[1];
        if (ransackKey === "g" || ransackKey === "m") return;
        var parsed = parseRansackKey(ransackKey, sortedFieldNames);
        if (parsed) {
          var value = values.length === 1 ? values[0] : values;
          rootChildren.push({ field: parsed.field, operator: parsed.operator, value: value });
        }
      }
    });

    // Parse grouped conditions recursively: f[g][0][...] -> nested groups
    var groupChildren = parseGroupParams(params, "f", sortedFieldNames);
    rootChildren = rootChildren.concat(groupChildren);

    // Read root combinator from f[m] param (defaults to "and")
    var rootCombinator = params.get("f[m]") || "and";
    var result = { combinator: rootCombinator, children: rootChildren };
    if (params.get("ql_mode") === "1") result._qlMode = true;
    return result;
  }

  function parseGroupParams(params, prefix, sortedFieldNames) {
    // Collect all params that start with prefix[g][N][...]
    var groupPrefix = prefix + "[g]";
    var groups = {};

    params.forEach(function(value, key) {
      if (key.indexOf(groupPrefix + "[") !== 0) return;
      var rest = key.substring(groupPrefix.length + 1); // after "[g]["
      var idxMatch = rest.match(/^(\d+)\](.*)$/);
      if (!idxMatch) return;
      var idx = idxMatch[1];
      var remaining = idxMatch[2]; // e.g., "[m]", "[field_eq]", "[g][0][...]"
      if (!groups[idx]) groups[idx] = [];
      groups[idx].push({ remaining: remaining, value: value, fullKey: key });
    });

    var result = [];
    Object.keys(groups).sort().forEach(function(idx) {
      var entries = groups[idx];
      var combinator = "or";
      var children = [];
      var subPrefix = groupPrefix + "[" + idx + "]";

      // First pass: extract combinator and collect leaf values by ransack key
      var leafMap = {};
      entries.forEach(function(entry) {
        // [m] -> combinator
        if (entry.remaining === "[m]") {
          combinator = entry.value;
          return;
        }
        // [g][...] -> recursive sub-group (handled separately below)
        if (entry.remaining.indexOf("[g]") === 0) return;
        // [field_op] or [field_op][] -> leaf condition
        var normalizedRemaining = entry.remaining.replace(/\[\]$/, "");
        var subMatch = normalizedRemaining.match(/^\[([^\]]+)\]$/);
        if (subMatch) {
          var rKey = subMatch[1];
          if (!leafMap[rKey]) leafMap[rKey] = [];
          leafMap[rKey].push(entry.value);
        }
      });

      // Second pass: build children from collected leaf values
      Object.keys(leafMap).forEach(function(rKey) {
        var parsed = parseRansackKey(rKey, sortedFieldNames);
        if (parsed) {
          var values = leafMap[rKey];
          var value = values.length === 1 ? values[0] : values;
          children.push({ field: parsed.field, operator: parsed.operator, value: value });
        }
      });

      // Recursively parse sub-groups
      var subGroupChildren = parseGroupParams(params, subPrefix, sortedFieldNames);
      children = children.concat(subGroupChildren);

      if (children.length > 0) {
        result.push({ combinator: combinator, children: children });
      }
    });

    return result;
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

  function parseCfKey(cfKey, sortedBaseNames) {
    for (var i = 0; i < sortedBaseNames.length; i++) {
      var baseName = sortedBaseNames[i];
      var prefix = baseName + "_";
      if (cfKey.indexOf(prefix) === 0) {
        var operatorSuffix = cfKey.substring(prefix.length);
        if (KNOWN_OPERATORS.indexOf(operatorSuffix) !== -1) {
          return { field: baseName, operator: operatorSuffix };
        }
      }
    }
    return null;
  }

  // --- Recursive rendering ---

  function renderChildren(container, node, metadata, depth, maxNestingDepth) {
    destroyTomSelectInstances(container);
    container.innerHTML = "";

    var children = node.children || [];
    var combinator = node.combinator || "and";

    children.forEach(function(child, idx) {
      // Combinator label between siblings
      if (idx > 0) {
        var combinatorEl = document.createElement("div");
        combinatorEl.className = "lcp-filter-combinator";
        combinatorEl.textContent = combinator.toUpperCase();
        container.appendChild(combinatorEl);
      }

      if (isLeaf(child)) {
        addConditionRow(container, child, metadata, function() {
          node.children.splice(idx, 1);
          renderChildren(container, node, metadata, depth, maxNestingDepth);
        });
      } else if (isGroup(child)) {
        addGroupBlock(container, child, node, idx, metadata, depth, maxNestingDepth, function() {
          renderChildren(container, node, metadata, depth, maxNestingDepth);
        });
      }
    });
  }

  function addConditionRow(parent, condition, metadata, onRemove) {
    // Build field tree once and cache on metadata
    if (!metadata._fieldTree) metadata._fieldTree = buildFieldTree(metadata);

    var row = document.createElement("div");
    row.className = "lcp-filter-row";

    // Operator select (populated based on field)
    var operatorContainer = document.createElement("div");
    operatorContainer.className = "lcp-filter-operator-select";

    // Value input (populated based on field + operator)
    var valueContainer = document.createElement("div");
    valueContainer.className = "lcp-filter-value-input";

    // Field change handler
    function onFieldChange(fieldName) {
      condition.field = fieldName;
      condition.operator = "";
      condition.value = "";
      var newFieldMeta = findFieldMeta(metadata, fieldName);

      destroyTomSelectInstances(operatorContainer);
      operatorContainer.innerHTML = "";
      destroyTomSelectInstances(valueContainer);
      valueContainer.innerHTML = "";

      if (newFieldMeta && newFieldMeta.type === "scope") {
        // Scope field: render parameter inputs instead of operator/value
        condition.operator = "scope";
        condition.params = condition.params || {};
        renderScopeParams(valueContainer, newFieldMeta.scope_parameters || [], condition);
      } else if (newFieldMeta) {
        renderOperatorSelect(operatorContainer, metadata, newFieldMeta, "", function(op) {
          condition.operator = op;
          destroyTomSelectInstances(valueContainer);
          valueContainer.innerHTML = "";
          renderValueInput(valueContainer, metadata, newFieldMeta, op, condition, function(val) {
            condition.value = val;
          });
        });
      }
    }

    // Cascading field select
    var fieldSelect = renderCascadeFieldSelect(metadata._fieldTree, metadata, condition.field, onFieldChange);
    row.appendChild(fieldSelect);

    row.appendChild(operatorContainer);
    row.appendChild(valueContainer);

    // Remove button
    var removeBtn = document.createElement("button");
    removeBtn.type = "button";
    removeBtn.className = "lcp-filter-remove-btn";
    removeBtn.innerHTML = "&times;";
    removeBtn.addEventListener("click", onRemove);
    row.appendChild(removeBtn);

    parent.appendChild(row);

    // Populate operator and value for pre-existing conditions
    var fieldMeta = findFieldMeta(metadata, condition.field);
    if (fieldMeta && fieldMeta.type === "scope") {
      // Scope condition: render parameter inputs
      condition.operator = "scope";
      condition.params = condition.params || {};
      renderScopeParams(valueContainer, fieldMeta.scope_parameters || [], condition);
    } else if (fieldMeta) {
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
  }

  function addGroupBlock(parent, group, parentNode, groupIdx, metadata, depth, maxNestingDepth, onRerender) {
    var block = document.createElement("div");
    block.className = "lcp-filter-group";
    // Add depth-based styling
    var depthClass = "lcp-filter-depth-" + Math.min(depth, 3);
    block.classList.add(depthClass);

    var header = document.createElement("div");
    header.className = "lcp-filter-group-header";

    var label = document.createElement("span");
    label.className = "lcp-filter-group-label";
    label.textContent = (group.combinator || "or").toUpperCase() + " " + t("filter.group_suffix", "group");
    header.appendChild(label);

    var removeGroupBtn = document.createElement("button");
    removeGroupBtn.type = "button";
    removeGroupBtn.className = "lcp-filter-group-remove";
    removeGroupBtn.textContent = t("filter.remove_group", "Remove group");
    removeGroupBtn.addEventListener("click", function() {
      parentNode.children.splice(groupIdx, 1);
      onRerender();
    });
    header.appendChild(removeGroupBtn);

    block.appendChild(header);

    var rowsContainer = document.createElement("div");
    rowsContainer.className = "lcp-filter-group-rows";

    // Recursively render children of this group
    renderChildren(rowsContainer, group, metadata, depth + 1, maxNestingDepth);

    block.appendChild(rowsContainer);

    // Action buttons for group
    var btnRow = document.createElement("div");
    btnRow.style.display = "flex";
    btnRow.style.gap = "0.5rem";

    var addBtn = document.createElement("button");
    addBtn.type = "button";
    addBtn.className = "btn lcp-filter-group-add-btn";
    addBtn.textContent = t("filter.add_condition", "+ Add condition");
    addBtn.addEventListener("click", function() {
      group.children.push(emptyLeaf());
      onRerender();
    });
    btnRow.appendChild(addBtn);

    // Add sub-group button (only if within nesting depth limit)
    if (depth + 1 < maxNestingDepth) {
      var addSubGroupBtn = document.createElement("button");
      addSubGroupBtn.type = "button";
      addSubGroupBtn.className = "btn lcp-filter-group-add-btn";
      addSubGroupBtn.textContent = t("filter.add_subgroup", "+ Add sub-group");
      addSubGroupBtn.addEventListener("click", function() {
        // Alternate combinator from parent
        var childCombinator = group.combinator === "and" ? "or" : "and";
        group.children.push({ combinator: childCombinator, children: [emptyLeaf()] });
        onRerender();
      });
      btnRow.appendChild(addSubGroupBtn);
    }

    block.appendChild(btnRow);
    parent.appendChild(block);
  }

  // --- Cascading field picker ---

  function buildFieldTree(metadata) {
    var tree = { fields: [], associations: {} };

    metadata.fields.forEach(function(f) {
      var name = f.name;

      // Custom fields (cf[...]) and fields without dots are direct fields
      if (name.indexOf("cf[") === 0 || name.indexOf(".") === -1) {
        tree.fields.push(f);
        return;
      }

      // Dot-path field: split and walk the tree
      var parts = name.split(".");
      var node = tree;
      for (var i = 0; i < parts.length - 1; i++) {
        var assocKey = parts[i];
        if (!node.associations[assocKey]) {
          node.associations[assocKey] = {
            label: f.group || assocKey.charAt(0).toUpperCase() + assocKey.slice(1),
            fields: [],
            associations: {}
          };
        }
        node = node.associations[assocKey];
      }
      node.fields.push(f);
    });

    // Add parameterized scopes as a "Scopes" group
    if (metadata.scopes && metadata.scopes.length > 0) {
      tree.associations["_scopes"] = {
        label: (window.LcpI18n && window.LcpI18n.advanced_filter_field_groups_scopes) || "Scopes",
        fields: metadata.scopes.map(function(s) {
          return {
            name: "@" + s.name,
            label: s.label,
            type: "scope",
            scope_parameters: s.parameters
          };
        }),
        associations: {}
      };
    }

    return tree;
  }

  function decomposeFieldPath(fieldName, tree) {
    if (!fieldName) return [];

    // Direct field (no dot, or custom field)
    if (fieldName.indexOf(".") === -1 || fieldName.indexOf("cf[") === 0) {
      return [{ type: "field", value: fieldName }];
    }

    var parts = fieldName.split(".");
    var segments = [];
    var node = tree;

    for (var i = 0; i < parts.length - 1; i++) {
      var assocKey = parts[i];
      segments.push({ type: "assoc", value: assocKey });
      if (node.associations[assocKey]) {
        node = node.associations[assocKey];
      }
    }

    // The full dot-path is the field value
    segments.push({ type: "field", value: fieldName });
    return segments;
  }

  function renderCascadeFieldSelect(tree, metadata, selectedField, onChange) {
    var wrapper = document.createElement("div");
    wrapper.className = "lcp-filter-field-cascade";

    var pathSegments = decomposeFieldPath(selectedField, tree);
    buildCascadeLevels(wrapper, tree, pathSegments, onChange, metadata);

    return wrapper;
  }

  function buildCascadeLevels(wrapper, tree, pathSegments, onChange, metadata) {
    var currentNode = tree;

    if (pathSegments.length === 0) {
      // No selection: render first level with empty selection
      appendCascadeLevel(wrapper, currentNode, "", "none", onChange, metadata, 0);
      return;
    }

    for (var i = 0; i < pathSegments.length; i++) {
      var seg = pathSegments[i];

      if (seg.type === "assoc") {
        appendCascadeLevel(wrapper, currentNode, seg.value, "assoc", onChange, metadata, i);
        if (currentNode.associations[seg.value]) {
          currentNode = currentNode.associations[seg.value];
        }
      } else {
        // Field selection — this is the last level
        appendCascadeLevel(wrapper, currentNode, seg.value, "field", onChange, metadata, i);
      }
    }

    // If last segment was an association, render one more level for its children
    if (pathSegments.length > 0 && pathSegments[pathSegments.length - 1].type === "assoc") {
      appendCascadeLevel(wrapper, currentNode, "", "none", onChange, metadata, pathSegments.length);
    }
  }

  function appendCascadeLevel(wrapper, node, selectedValue, selectedType, onChange, metadata, depth) {
    // Add separator arrow between levels
    if (depth > 0) {
      var sep = document.createElement("span");
      sep.className = "lcp-cascade-separator";
      sep.textContent = "\u203A";
      wrapper.appendChild(sep);
    }

    var select = document.createElement("select");
    select.dataset.cascadeDepth = depth;
    select.innerHTML = '<option value="">' + t("filter.select_field", "Select field...") + '</option>';

    var hasFields = node.fields.length > 0;
    var assocKeys = Object.keys(node.associations);
    var hasAssocs = assocKeys.length > 0;

    // Direct fields
    node.fields.forEach(function(f) {
      var opt = document.createElement("option");
      opt.value = f.name;
      opt.textContent = f.label;
      if (selectedType === "field" && f.name === selectedValue) opt.selected = true;
      select.appendChild(opt);
    });

    // Separator between fields and associations
    if (hasFields && hasAssocs) {
      var sepOpt = document.createElement("option");
      sepOpt.disabled = true;
      sepOpt.textContent = "\u2500\u2500\u2500 " + t("filter.associations", "Associations") + " \u2500\u2500\u2500";
      select.appendChild(sepOpt);
    }

    // Association options (prefixed with "assoc:" to distinguish)
    assocKeys.forEach(function(key) {
      var opt = document.createElement("option");
      opt.value = "assoc:" + key;
      opt.textContent = node.associations[key].label + " \u203A";
      if (selectedType === "assoc" && key === selectedValue) opt.selected = true;
      select.appendChild(opt);
    });

    select.addEventListener("change", function() {
      var val = select.value;

      // Remove all levels after this one
      removeSubsequentLevels(wrapper, depth);

      if (!val) {
        // Empty selection — clear field
        onChange("");
        return;
      }

      if (val.indexOf("assoc:") === 0) {
        // Association selected — drill down
        var assocKey = val.substring(6);
        var childNode = node.associations[assocKey];
        if (childNode) {
          appendCascadeLevel(wrapper, childNode, "", "none", onChange, metadata, depth + 1);
        }
        // Don't fire onChange yet — user needs to select a field
      } else {
        // Field selected — fire onChange
        onChange(val);
      }
    });

    wrapper.appendChild(select);

    // Initialize TomSelect on this select
    if (typeof TomSelect !== "undefined") {
      new TomSelect(select, {
        allowEmptyOption: true,
        controlInput: null
      });
    }
  }

  function removeSubsequentLevels(wrapper, afterDepth) {
    var toRemove = [];
    var children = wrapper.children;
    var removing = false;

    for (var i = 0; i < children.length; i++) {
      var child = children[i];
      if (!removing && (child.tagName === "SELECT" || (child.classList && child.classList.contains("ts-wrapper")))) {
        var selectEl = child.tagName === "SELECT" ? child : child.querySelector("select");
        if (selectEl && parseInt(selectEl.dataset.cascadeDepth, 10) > afterDepth) {
          removing = true;
        }
      }
      if (removing) {
        destroyTomSelectInstances(child);
        toRemove.push(child);
      }
    }

    for (var k = 0; k < toRemove.length; k++) {
      wrapper.removeChild(toRemove[k]);
    }
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

  // Render parameter inputs for a parameterized scope condition.
  function renderScopeParams(container, parameters, condition) {
    if (!parameters || parameters.length === 0) return;

    condition.params = condition.params || {};
    var wrapper = document.createElement("div");
    wrapper.className = "lcp-scope-params";

    parameters.forEach(function(param) {
      var paramRow = document.createElement("div");
      paramRow.className = "lcp-scope-param";

      var label = document.createElement("label");
      label.textContent = param.label || param.name;
      if (param.required) label.textContent += " *";
      paramRow.appendChild(label);

      var input;
      var currentValue = condition.params[param.name];
      if (currentValue === undefined && param.default !== undefined) {
        currentValue = param.default;
        condition.params[param.name] = currentValue;
      }

      switch (param.type) {
        case "boolean":
          input = document.createElement("input");
          input.type = "checkbox";
          input.checked = currentValue === true || currentValue === "true";
          input.addEventListener("change", function() {
            condition.params[param.name] = input.checked;
          });
          break;
        case "integer":
        case "float":
          input = document.createElement("input");
          input.type = "number";
          if (param.min !== undefined) input.min = param.min;
          if (param.max !== undefined) input.max = param.max;
          if (param.step !== undefined) input.step = param.step;
          else if (param.type === "float") input.step = "0.01";
          input.value = currentValue !== undefined ? currentValue : "";
          input.addEventListener("input", function() {
            condition.params[param.name] = param.type === "integer" ? parseInt(input.value) : parseFloat(input.value);
          });
          break;
        case "date":
          input = document.createElement("input");
          input.type = "date";
          input.value = currentValue || "";
          input.addEventListener("change", function() {
            condition.params[param.name] = input.value;
          });
          break;
        case "datetime":
          input = document.createElement("input");
          input.type = "datetime-local";
          input.value = currentValue || "";
          input.addEventListener("change", function() {
            condition.params[param.name] = input.value;
          });
          break;
        case "enum":
          input = document.createElement("select");
          input.innerHTML = '<option value="">--</option>';
          (param.values || []).forEach(function(pair) {
            var opt = document.createElement("option");
            opt.value = Array.isArray(pair) ? pair[0] : pair;
            opt.textContent = Array.isArray(pair) ? pair[1] : pair;
            if (String(currentValue) === String(opt.value)) opt.selected = true;
            input.appendChild(opt);
          });
          input.addEventListener("change", function() {
            condition.params[param.name] = input.value;
          });
          break;
        case "model_select":
          input = document.createElement("select");
          input.innerHTML = '<option value="">--</option>';
          (param.options || []).forEach(function(opt) {
            var option = document.createElement("option");
            option.value = opt.value;
            option.textContent = opt.label;
            if (String(currentValue) === String(opt.value)) option.selected = true;
            input.appendChild(option);
          });
          input.addEventListener("change", function() {
            condition.params[param.name] = parseInt(input.value) || input.value;
          });
          break;
        default:
          input = document.createElement("input");
          input.type = "text";
          input.value = currentValue || "";
          if (param.placeholder) input.placeholder = param.placeholder;
          input.addEventListener("input", function() {
            condition.params[param.name] = input.value;
          });
      }

      paramRow.appendChild(input);
      wrapper.appendChild(paramRow);
    });

    container.appendChild(wrapper);
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

  // --- URL param building (recursive) ---

  function applyFilters(actionUrl, state, options) {
    var params = buildUrlParams(state);
    var url = new URL(actionUrl, window.location.origin);

    // Preserve qs and filter params
    var currentParams = new URLSearchParams(window.location.search);
    if (currentParams.has("qs")) url.searchParams.set("qs", currentParams.get("qs"));
    if (currentParams.has("filter")) url.searchParams.set("filter", currentParams.get("filter"));

    // Persist QL mode across page reload
    if (options && options.qlMode) {
      url.searchParams.set("ql_mode", "1");
    }

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

  function buildUrlParams(state) {
    var params = {};
    var groupCounter = { value: 0 };

    // Emit root combinator when it's not the default "and"
    var rootCombinator = state.combinator || "and";
    if (rootCombinator !== "and") {
      params["f[m]"] = rootCombinator;
    }

    (state.children || []).forEach(function(child) {
      if (isLeaf(child)) {
        encodeCondition(params, "f", child);
      } else if (isGroup(child)) {
        encodeGroup(params, "f", child, groupCounter);
      }
    });

    return params;
  }

  function encodeCondition(params, prefix, condition) {
    if (!condition.field || !condition.operator) return;

    // Scope condition: encode as scope[name][param]=value
    if (condition.operator === "scope" && condition.field && condition.field.charAt(0) === "@") {
      var scopeName = condition.field.substring(1);
      var scopeParams = condition.params || {};
      Object.keys(scopeParams).forEach(function(key) {
        params["scope[" + scopeName + "][" + key + "]"] = scopeParams[key];
      });
      return;
    }

    // Determine the param key format: cf[field_op] or prefix[field_op]
    var cfMatch = condition.field.match(/^cf\[([^\]]+)\]$/);
    var fieldBase, makeKey;
    if (cfMatch) {
      fieldBase = cfMatch[1];
      makeKey = function(op) { return "cf[" + fieldBase + "_" + op + "]"; };
    } else {
      fieldBase = condition.field.replace(/\./g, "_");
      makeKey = function(op) { return prefix + "[" + fieldBase + "_" + op + "]"; };
    }

    var key = makeKey(condition.operator);

    // No-value operators (boolean, null, presence) need a truthy value for Ransack
    if (NO_VALUE_OPS.indexOf(condition.operator) !== -1) {
      params[key] = "1";
      return;
    }

    if (Array.isArray(condition.value)) {
      if (condition.value.length === 2 && condition.operator === "between") {
        params[makeKey("gteq")] = condition.value[0];
        params[makeKey("lteq")] = condition.value[1];
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

  function encodeGroup(params, prefix, group, groupCounter) {
    var idx = groupCounter.value;
    groupCounter.value++;
    var groupPrefix = prefix + "[g][" + idx + "]";

    params[groupPrefix + "[m]"] = group.combinator || "or";

    (group.children || []).forEach(function(child) {
      if (isLeaf(child)) {
        encodeCondition(params, groupPrefix, child);
      } else if (isGroup(child)) {
        encodeGroup(params, groupPrefix, child, groupCounter);
      }
    });
  }

  function findFieldMeta(metadata, fieldName) {
    if (!fieldName) return null;
    for (var i = 0; i < metadata.fields.length; i++) {
      if (metadata.fields[i].name === fieldName) return metadata.fields[i];
    }
    // Also search in parameterized scopes
    if (metadata.scopes && fieldName && fieldName.charAt(0) === "@") {
      var scopeName = fieldName.substring(1);
      for (var j = 0; j < metadata.scopes.length; j++) {
        if (metadata.scopes[j].name === scopeName) {
          return {
            name: "@" + metadata.scopes[j].name,
            label: metadata.scopes[j].label,
            type: "scope",
            scope_parameters: metadata.scopes[j].parameters
          };
        }
      }
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

  // --- QL serialization: recursive state -> QL text ---

  var QL_OP_MAP = {
    eq: "=", not_eq: "!=", gt: ">", gteq: ">=", lt: "<", lteq: "<=",
    cont: "~", not_cont: "!~", start: "^", end: "$",
    "in": "in", not_in: "not in",
    "null": "is null", not_null: "is not null",
    present: "is present", blank: "is blank",
    "true": "is true", "false": "is false"
  };

  var QL_NO_VALUE = ["null", "not_null", "present", "blank", "true", "false"];

  function serializeToQl(node) {
    return serializeNodeToQl(node, null);
  }

  function serializeNodeToQl(node, parentCombinator) {
    if (!node) return "";

    if (isLeaf(node)) {
      return serializeConditionToQl(node);
    }

    var children = node.children || [];
    var combinator = node.combinator || "and";
    var parts = [];
    children.forEach(function(child) {
      var s = serializeNodeToQl(child, combinator);
      if (s) parts.push(s);
    });

    if (parts.length === 0) return "";
    if (parts.length === 1) return parts[0];

    var joined = parts.join(" " + combinator + " ");

    // Wrap in parentheses when nested inside a different combinator
    if (parentCombinator && parentCombinator !== combinator) {
      return "(" + joined + ")";
    }
    return joined;
  }

  function serializeConditionToQl(c) {
    if (!c.field || !c.operator) return null;

    var field = c.field;
    // Strip cf[...] wrapper for QL representation
    var cfMatch = field.match(/^cf\[([^\]]+)\]$/);
    if (cfMatch) field = "cf_" + cfMatch[1];

    var qlOp = QL_OP_MAP[c.operator];
    if (!qlOp) return null;

    if (QL_NO_VALUE.indexOf(c.operator) !== -1) {
      return field + " " + qlOp;
    }

    if (c.operator === "in" || c.operator === "not_in") {
      var vals = Array.isArray(c.value) ? c.value : [c.value];
      var formatted = vals.map(function(v) { return formatQlValue(v); });
      return field + " " + qlOp + " [" + formatted.join(", ") + "]";
    }

    return field + " " + qlOp + " " + formatQlValue(c.value);
  }

  function formatQlValue(v) {
    if (v === null || v === undefined || v === "") return "''";
    if (typeof v === "string" && v.match(/^-?\d+(\.\d+)?$/)) return v;
    return "'" + v.toString().replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'";
  }

  // --- QL parsing bridge ---

  function postQl(parseQlUrl, qlText, onSuccess, onError) {
    var xhr = new XMLHttpRequest();
    xhr.open("POST", parseQlUrl, true);
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");

    var token = LcpRuby.csrfToken();
    if (token) {
      xhr.setRequestHeader("X-CSRF-Token", token);
    }

    xhr.onload = function() {
      if (xhr.status === 200) {
        var result = JSON.parse(xhr.responseText);
        if (result.success && result.tree) {
          onSuccess(result.tree);
        } else if (onError) {
          onError(result.error || t("filter.ql_parse_error", "Invalid query syntax"));
        }
      } else if (onError) {
        onError(t("filter.ql_parse_error", "Invalid query syntax") + " (HTTP " + xhr.status + ")");
      }
    };

    xhr.onerror = function() {
      if (onError) onError(t("filter.ql_network_error", "Network error — please try again"));
    };

    xhr.send("ql=" + encodeURIComponent(qlText));
  }

  function parseQlToState(qlText, parseQlUrl, state, onSuccess) {
    postQl(parseQlUrl, qlText, function(tree) {
      // Server returns { combinator, children } format
      state.combinator = tree.combinator || "and";
      state.children = tree.children || [];
      if (onSuccess) onSuccess();
    });
  }

  function applyFromQl(container, actionUrl, state, metadata, rowsContainer, maxNestingDepth) {
    var qlSection = container.querySelector(".lcp-ql-section");
    var textarea = qlSection.querySelector(".lcp-ql-input");
    var errorDiv = qlSection.querySelector(".lcp-ql-error");
    var parseQlUrl = container.dataset.lcpParseQlUrl;

    errorDiv.style.display = "none";
    errorDiv.textContent = "";

    if (!textarea.value.trim()) {
      clearFilters(actionUrl);
      return;
    }

    postQl(parseQlUrl, textarea.value, function(tree) {
      state.combinator = tree.combinator || "and";
      state.children = tree.children || [];
      applyFilters(actionUrl, state, { qlMode: true });
    }, function(errorMsg) {
      errorDiv.textContent = errorMsg;
      errorDiv.style.display = "";
    });
  }

  // Public API for saved filters integration
  window.LcpAdvancedFilter = {
    // Returns the current condition tree state from the first filter builder on page.
    getConditionTree: function() {
      var container = document.querySelector("[data-lcp-filter-metadata]");
      if (!container || !container._lcpFilterState) return null;
      var state = container._lcpFilterState;
      if (!hasActiveChildren(state)) return null;
      return JSON.parse(JSON.stringify(state)); // Deep clone
    }
  };

  // Initialize on DOM ready
  document.addEventListener("DOMContentLoaded", initFilterBuilders);

  // Also handle Turbo/Turbolinks page transitions
  document.addEventListener("turbo:load", initFilterBuilders);
  document.addEventListener("turbolinks:load", initFilterBuilders);
})();
