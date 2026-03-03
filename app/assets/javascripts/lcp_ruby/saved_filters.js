// LCP Ruby — Saved Filters
//
// Handles save dialog, CRUD operations, filter activation, and dropdown toggles
// for saved filters on index pages.
(function() {
  "use strict";

  document.addEventListener("DOMContentLoaded", function() {
    initSavedFilters();
  });

  document.addEventListener("turbo:load", function() {
    initSavedFilters();
  });

  function initSavedFilters() {
    initDropdownToggles();
    initSaveDialog();
    initSaveButton();
    initVisibilityToggle();
  }

  // --- Dropdown toggle ---

  function initDropdownToggles() {
    document.querySelectorAll("[data-toggle='saved-filters-dropdown']").forEach(function(btn) {
      btn.addEventListener("click", function(e) {
        e.stopPropagation();
        var menu = btn.nextElementSibling;
        if (!menu) return;
        var isVisible = menu.style.display !== "none";
        closeAllDropdowns();
        if (!isVisible) {
          menu.style.display = "block";
        }
      });
    });

    // Close dropdown when clicking outside
    document.addEventListener("click", function() {
      closeAllDropdowns();
    });
  }

  function closeAllDropdowns() {
    document.querySelectorAll(".lcp-saved-filter-dropdown-menu").forEach(function(menu) {
      menu.style.display = "none";
    });
  }

  // --- Save dialog ---

  function initSaveDialog() {
    // Close dialog on overlay or cancel click
    document.querySelectorAll("[data-action='close-save-dialog']").forEach(function(el) {
      el.addEventListener("click", function() {
        closeSaveDialog();
      });
    });

    // Form submission
    var form = document.getElementById("lcp-save-filter-form");
    if (form) {
      form.addEventListener("submit", function(e) {
        e.preventDefault();
        submitSaveFilter(form);
      });
    }
  }

  function initSaveButton() {
    document.querySelectorAll("[data-action='save-filter']").forEach(function(btn) {
      btn.addEventListener("click", function() {
        openSaveDialog();
      });
    });

    // Show save button when advanced filter has active conditions
    var advancedFilter = document.querySelector(".lcp-advanced-filter");
    if (advancedFilter) {
      var observer = new MutationObserver(function() {
        updateSaveButtonVisibility();
      });
      observer.observe(advancedFilter, { childList: true, subtree: true, attributes: true });
      updateSaveButtonVisibility();
    }
  }

  function updateSaveButtonVisibility() {
    var hasConditions = document.querySelectorAll(".lcp-filter-row").length > 0;
    document.querySelectorAll(".lcp-save-filter-btn").forEach(function(btn) {
      btn.style.display = hasConditions ? "" : "none";
    });
  }

  function openSaveDialog() {
    var dialog = document.getElementById("lcp-save-filter-dialog");
    if (dialog) {
      dialog.style.display = "flex";
      var nameInput = dialog.querySelector("#saved_filter_name");
      if (nameInput) nameInput.focus();
    }
  }

  function closeSaveDialog() {
    var dialog = document.getElementById("lcp-save-filter-dialog");
    if (dialog) {
      dialog.style.display = "none";
    }
  }

  // --- Visibility field toggles ---

  function initVisibilityToggle() {
    var select = document.getElementById("saved_filter_visibility");
    if (!select) return;

    select.addEventListener("change", function() {
      toggleVisibilityFields(select.value);
    });
    toggleVisibilityFields(select.value);
  }

  function toggleVisibilityFields(value) {
    var roleWrapper = document.getElementById("saved_filter_target_role_wrapper");
    var groupWrapper = document.getElementById("saved_filter_target_group_wrapper");

    if (roleWrapper) {
      roleWrapper.style.display = value === "role" ? "" : "none";
    }
    if (groupWrapper) {
      groupWrapper.style.display = value === "group" ? "" : "none";
    }
  }

  // --- CRUD operations ---

  function submitSaveFilter(form) {
    var url = form.dataset.url;
    var formData = new FormData(form);
    var data = {};

    formData.forEach(function(value, key) {
      // Convert form field names like "saved_filter[name]" to nested object
      var match = key.match(/^saved_filter\[(.+)\]$/);
      if (match) {
        data[match[1]] = value;
      }
    });

    // Get condition tree from the advanced filter state
    var conditionTree = getConditionTreeFromAdvancedFilter();
    if (!conditionTree) {
      alert("No filter conditions to save.");
      return;
    }
    data.condition_tree = conditionTree;

    // Get CSRF token
    var csrfToken = document.querySelector("meta[name='csrf-token']");
    var token = csrfToken ? csrfToken.content : "";

    // Determine if this is create or update
    var method = form.dataset.filterId ? "PATCH" : "POST";
    var requestUrl = form.dataset.filterId ? url + "/" + form.dataset.filterId : url;

    fetch(requestUrl, {
      method: method,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token,
        "Accept": "application/json"
      },
      body: JSON.stringify({ saved_filter: data })
    })
    .then(function(response) {
      if (response.ok) {
        return response.json();
      } else {
        return response.json().then(function(err) {
          throw new Error(err.error || err.errors?.join(", ") || "Save failed");
        });
      }
    })
    .then(function(result) {
      closeSaveDialog();
      // Navigate to the saved filter URL
      window.location.href = window.location.pathname + "?saved_filter=" + result.id;
    })
    .catch(function(error) {
      alert(error.message);
    });
  }

  function getConditionTreeFromAdvancedFilter() {
    // Try to get the condition tree from the advanced filter's state
    if (window.LcpAdvancedFilter && typeof window.LcpAdvancedFilter.getConditionTree === "function") {
      return window.LcpAdvancedFilter.getConditionTree();
    }

    // Fallback: construct from current URL params
    var urlParams = new URLSearchParams(window.location.search);
    if (urlParams.has("f")) {
      // There are filter params but we can't reconstruct the tree
      return null;
    }

    return null;
  }

  // Delete a saved filter
  window.LcpSavedFilters = {
    deleteFilter: function(filterId, url) {
      if (!confirm("Are you sure you want to delete this saved filter?")) return;

      var csrfToken = document.querySelector("meta[name='csrf-token']");
      var token = csrfToken ? csrfToken.content : "";

      fetch(url + "/" + filterId, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": token,
          "Accept": "application/json"
        }
      })
      .then(function(response) {
        if (response.ok) {
          // Reload without the saved_filter param
          window.location.href = window.location.pathname;
        }
      });
    }
  };
})();
