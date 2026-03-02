(function() {
  'use strict';

  function initTreeReparent(table) {
    var dragRow = null;
    var dragSubtreeIds = [];

    table.querySelectorAll('[data-reparent-url]').forEach(function(row) {
      var handle = row.querySelector('.lcp-drag-handle');
      if (!handle) return;

      handle.setAttribute('draggable', 'true');

      handle.addEventListener('dragstart', function(e) {
        dragRow = row;
        var rawIds = row.getAttribute('data-subtree-ids') || row.getAttribute('data-record-id');
        dragSubtreeIds = rawIds.split(',').map(function(id) { return id.trim(); });
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', row.getAttribute('data-record-id'));
        row.classList.add('lcp-dragging');
      });

      handle.addEventListener('dragend', function() {
        dragRow = null;
        dragSubtreeIds = [];
        row.classList.remove('lcp-dragging');
        clearAllDropIndicators(table);
      });
    });

    // Drop zones on all rows
    table.querySelectorAll('tr[data-record-id]').forEach(function(targetRow) {
      targetRow.addEventListener('dragover', function(e) {
        if (!dragRow) return;
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';

        var targetId = targetRow.getAttribute('data-record-id');

        // Prevent dropping on self or descendants (cycle prevention)
        if (dragSubtreeIds.indexOf(targetId) !== -1) {
          clearAllDropIndicators(table);
          targetRow.classList.add('lcp-tree-drop-invalid');
          return;
        }

        clearAllDropIndicators(table);

        // Determine drop zone: top 25% = before, middle 50% = child, bottom 25% = after
        var rect = targetRow.getBoundingClientRect();
        var y = e.clientY - rect.top;
        var h = rect.height;

        if (y < h * 0.25) {
          targetRow.classList.add('lcp-tree-drop-before');
        } else if (y > h * 0.75) {
          targetRow.classList.add('lcp-tree-drop-after');
        } else {
          targetRow.classList.add('lcp-tree-drop-child');
        }
      });

      targetRow.addEventListener('dragleave', function() {
        targetRow.classList.remove('lcp-tree-drop-before', 'lcp-tree-drop-child',
          'lcp-tree-drop-after', 'lcp-tree-drop-invalid');
      });

      targetRow.addEventListener('drop', function(e) {
        e.preventDefault();
        if (!dragRow) return;

        var targetId = targetRow.getAttribute('data-record-id');
        if (dragSubtreeIds.indexOf(targetId) !== -1) {
          clearAllDropIndicators(table);
          return;
        }

        var rect = targetRow.getBoundingClientRect();
        var y = e.clientY - rect.top;
        var h = rect.height;
        var dropZone;

        if (y < h * 0.25) {
          dropZone = 'before';
        } else if (y > h * 0.75) {
          dropZone = 'after';
        } else {
          dropZone = 'child';
        }

        clearAllDropIndicators(table);
        executeReparent(dragRow, targetRow, dropZone, table);
      });
    });

    // Root drop zone
    var rootZone = table.parentElement.querySelector('.lcp-tree-root-drop-zone');
    if (rootZone) {
      rootZone.addEventListener('dragover', function(e) {
        if (!dragRow) return;
        e.preventDefault();
        rootZone.classList.add('active');
      });
      rootZone.addEventListener('dragleave', function() {
        rootZone.classList.remove('active');
      });
      rootZone.addEventListener('drop', function(e) {
        e.preventDefault();
        rootZone.classList.remove('active');
        if (!dragRow) return;
        executeReparent(dragRow, null, 'root', table);
      });
    }
  }

  function clearAllDropIndicators(table) {
    table.querySelectorAll('.lcp-tree-drop-before, .lcp-tree-drop-child, .lcp-tree-drop-after, .lcp-tree-drop-invalid').forEach(function(el) {
      el.classList.remove('lcp-tree-drop-before', 'lcp-tree-drop-child',
        'lcp-tree-drop-after', 'lcp-tree-drop-invalid');
    });
  }

  function executeReparent(dragRow, targetRow, dropZone, table) {
    var url = dragRow.getAttribute('data-reparent-url');
    var treeVersion = table.getAttribute('data-tree-version');
    var newParentId;

    if (dropZone === 'root') {
      newParentId = null;
    } else if (dropZone === 'child') {
      newParentId = targetRow.getAttribute('data-record-id');
    } else {
      // before/after: use the target's parent
      newParentId = targetRow.getAttribute('data-parent-id') || null;
    }

    var body = { parent_id: newParentId };
    if (treeVersion) body.tree_version = treeVersion;

    var csrfToken = document.querySelector('meta[name="csrf-token"]');
    var headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    if (csrfToken) headers['X-CSRF-Token'] = csrfToken.getAttribute('content');

    fetch(url, {
      method: 'PATCH',
      headers: headers,
      body: JSON.stringify(body)
    }).then(function(response) {
      if (response.status === 409) {
        // Tree version conflict — reload
        window.location.reload();
        return;
      }
      if (response.status === 422) {
        return response.json().then(function(data) {
          alert(data.errors ? data.errors.join('\n') : 'Reparent failed');
        });
      }
      if (response.ok) {
        return response.json().then(function(data) {
          // Update tree version
          if (data.tree_version) {
            table.setAttribute('data-tree-version', data.tree_version);
          }
          // Reload to reflect new tree structure
          window.location.reload();
        });
      }
    }).catch(function() {
      window.location.reload();
    });
  }

  function init() {
    document.querySelectorAll('[data-lcp-tree-index]').forEach(function(table) {
      if (!table._lcpTreeReparentInitialized && table.querySelector('[data-reparent-url]')) {
        table._lcpTreeReparentInitialized = true;
        initTreeReparent(table);
      }
    });
  }

  document.addEventListener('DOMContentLoaded', init);
  document.addEventListener('turbo:load', init);
  document.addEventListener('turbolinks:load', init);
})();
