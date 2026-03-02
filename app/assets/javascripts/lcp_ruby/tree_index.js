(function() {
  'use strict';

  function initTreeIndex(table) {
    var slug = window.location.pathname.split('/')[1] || 'tree';
    var storageKey = 'lcp-tree-' + slug;

    // Restore expand/collapse state from sessionStorage
    var savedState = {};
    try {
      var raw = sessionStorage.getItem(storageKey);
      if (raw) savedState = JSON.parse(raw);
    } catch(e) { /* ignore */ }

    var searchActive = table.getAttribute('data-search-active') === 'true';

    // Apply saved state to rows (unless search is active — always expanded during search)
    if (!searchActive) {
      var rows = table.querySelectorAll('tr[data-record-id]');
      rows.forEach(function(row) {
        var id = row.getAttribute('data-record-id');
        if (savedState[id] !== undefined) {
          row.setAttribute('data-expanded', savedState[id] ? 'true' : 'false');
          var chevron = row.querySelector('.lcp-tree-chevron');
          if (chevron) {
            if (savedState[id]) {
              chevron.classList.add('expanded');
            } else {
              chevron.classList.remove('expanded');
            }
          }
        }
      });
      applyVisibility(table);
    }

    // Chevron click toggle
    table.addEventListener('click', function(e) {
      var toggle = e.target.closest('[data-lcp-tree-toggle]');
      if (!toggle) return;
      if (searchActive) return;

      var recordId = toggle.getAttribute('data-lcp-tree-toggle');
      var row = table.querySelector('tr[data-record-id="' + recordId + '"]');
      if (!row) return;

      var isExpanded = row.getAttribute('data-expanded') === 'true';
      row.setAttribute('data-expanded', isExpanded ? 'false' : 'true');

      var chevron = row.querySelector('.lcp-tree-chevron');
      if (chevron) {
        chevron.classList.toggle('expanded', !isExpanded);
      }

      applyVisibility(table);
      saveState(table, storageKey);
    });
  }

  function applyVisibility(table) {
    var rows = table.querySelectorAll('tr[data-record-id]');
    // Build parent expanded map
    var expandedMap = {};
    rows.forEach(function(row) {
      expandedMap[row.getAttribute('data-record-id')] = row.getAttribute('data-expanded') === 'true';
    });

    rows.forEach(function(row) {
      var parentId = row.getAttribute('data-parent-id');
      if (!parentId) {
        // Root row — always visible
        row.style.display = '';
        return;
      }

      // Walk up the parent chain — if any ancestor is collapsed, hide this row
      var visible = true;
      var currentParentId = parentId;
      while (currentParentId) {
        if (expandedMap[currentParentId] === false) {
          visible = false;
          break;
        }
        var parentRow = table.querySelector('tr[data-record-id="' + currentParentId + '"]');
        currentParentId = parentRow ? parentRow.getAttribute('data-parent-id') : null;
      }

      row.style.display = visible ? '' : 'none';
    });
  }

  function saveState(table, storageKey) {
    var state = {};
    table.querySelectorAll('tr[data-record-id][data-has-children="true"]').forEach(function(row) {
      state[row.getAttribute('data-record-id')] = row.getAttribute('data-expanded') === 'true';
    });
    try {
      sessionStorage.setItem(storageKey, JSON.stringify(state));
    } catch(e) { /* ignore */ }
  }

  // Initialize on DOMContentLoaded and Turbo
  function init() {
    document.querySelectorAll('[data-lcp-tree-index]').forEach(function(table) {
      if (!table._lcpTreeInitialized) {
        table._lcpTreeInitialized = true;
        initTreeIndex(table);
      }
    });
  }

  document.addEventListener('DOMContentLoaded', init);
  document.addEventListener('turbo:load', init);
  document.addEventListener('turbolinks:load', init);
})();
