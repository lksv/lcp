// LCP Ruby — Saved Filters
//
// Handles save dialog (via presenter-driven dialog system), CRUD operations,
// filter activation, and dropdown toggles for saved filters on index pages.
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
    initSaveButton();
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

  // --- Save button ---

  function initSaveButton() {
    document.querySelectorAll("[data-lcp-open-save-filter-dialog]").forEach(function(btn) {
      btn.addEventListener("click", function() {
        openSaveFilterDialog(btn);
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

  function openSaveFilterDialog(button) {
    var conditionTree = getConditionTreeFromAdvancedFilter();
    if (!conditionTree) {
      alert("No filter conditions to save.");
      return;
    }

    var dialogUrl = button.getAttribute("data-lcp-dialog-url");
    var submitUrl = button.getAttribute("data-lcp-saved-filters-url");

    lcpOpenDialog(dialogUrl, {
      size: "medium",
      onSuccess: "reload",
      beforeSubmit: function(form) {
        // Override form action to SavedFiltersController
        form.action = submitUrl + "?_dialog=1";
        // Change param scope from record[] to saved_filter[]
        form.querySelectorAll('[name^="record["]').forEach(function(input) {
          input.name = input.name.replace(/^record\[/, "saved_filter[");
        });
        // Inject condition_tree
        var hidden = document.createElement("input");
        hidden.type = "hidden";
        hidden.name = "saved_filter[condition_tree]";
        hidden.value = JSON.stringify(conditionTree);
        form.appendChild(hidden);
      }
    });
  }

  function updateSaveButtonVisibility() {
    var hasConditions = document.querySelectorAll(".lcp-filter-row").length > 0;
    document.querySelectorAll(".lcp-save-filter-btn").forEach(function(btn) {
      btn.style.display = hasConditions ? "" : "none";
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
