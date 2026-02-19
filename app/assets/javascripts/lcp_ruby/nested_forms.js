/* Nested forms: Add row */
document.addEventListener('click', function(e) {
  var addBtn = e.target.closest('.lcp-nested-add');
  if (!addBtn) return;
  var section = addBtn.closest('.lcp-nested-section');
  if (!section) return;
  var template = section.querySelector('[data-lcp-nested-template]');
  if (!template) return;
  var container = section.querySelector('.lcp-nested-container');
  if (!container) return;

  var maxCount = parseInt(section.dataset.nestedMax) || 0;
  if (maxCount > 0) {
    var visibleRows = container.querySelectorAll('.lcp-nested-row:not(.removed)');
    if (visibleRows.length >= maxCount) return;
  }

  var clone = template.firstElementChild.cloneNode(true);
  var ts = new Date().getTime();
  clone.innerHTML = clone.innerHTML.replace(/NEW_RECORD/g, ts);
  clone.style.display = '';
  container.appendChild(clone);
});

/* Nested forms: Remove row */
document.addEventListener('click', function(e) {
  var removeBtn = e.target.closest('.lcp-nested-remove');
  if (!removeBtn) return;
  var row = removeBtn.closest('.lcp-nested-row');
  if (!row) return;
  var section = row.closest('.lcp-nested-section');
  var minCount = parseInt(section ? section.dataset.nestedMin : '0') || 0;
  var container = section ? section.querySelector('.lcp-nested-container') : null;
  if (container && minCount > 0) {
    var visibleRows = container.querySelectorAll('.lcp-nested-row:not(.removed)');
    if (visibleRows.length <= minCount) return;
  }

  var destroyField = row.querySelector('.lcp-destroy-flag');
  if (destroyField) {
    destroyField.value = 'true';
    row.classList.add('removed');
  } else {
    row.remove();
  }
});

/* Drag and drop reordering for sortable nested forms */
(function() {
  var draggedRow = null;

  function isInTemplate(el) {
    return !!el.closest('[data-lcp-nested-template]');
  }

  function updatePositionFields(container) {
    var rows = container.querySelectorAll('.lcp-nested-row:not(.removed)');
    rows.forEach(function(row, index) {
      if (isInTemplate(row)) return;
      var posField = row.querySelector('.lcp-position-field');
      if (posField) posField.value = index;
    });
  }

  /* Handle-initiated dragging (mouse) */
  document.addEventListener('mousedown', function(e) {
    var handle = e.target.closest('.lcp-drag-handle');
    if (handle) {
      var row = handle.closest('.lcp-nested-row');
      if (row && !isInTemplate(row)) row.setAttribute('draggable', 'true');
    }
  });

  document.addEventListener('mouseup', function(e) {
    document.querySelectorAll('.lcp-nested-row[draggable]').forEach(function(row) {
      row.removeAttribute('draggable');
    });
  });

  document.addEventListener('dragstart', function(e) {
    var row = e.target.closest('.lcp-nested-row');
    if (!row || !row.closest('[data-sortable]') || isInTemplate(row)) return;
    draggedRow = row;
    row.classList.add('dragging');
    e.dataTransfer.effectAllowed = 'move';
  });

  document.addEventListener('dragover', function(e) {
    if (!draggedRow) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    var targetRow = e.target.closest('.lcp-nested-row');
    if (!targetRow || targetRow === draggedRow || isInTemplate(targetRow)) return;
    var container = targetRow.closest('.lcp-nested-container');
    if (!container || container !== draggedRow.closest('.lcp-nested-container')) return;

    container.querySelectorAll('.lcp-nested-row.drag-over').forEach(function(r) {
      r.classList.remove('drag-over');
    });
    targetRow.classList.add('drag-over');
  });

  document.addEventListener('drop', function(e) {
    if (!draggedRow) return;
    e.preventDefault();
    var targetRow = e.target.closest('.lcp-nested-row');
    if (!targetRow || targetRow === draggedRow || isInTemplate(targetRow)) return;
    var container = targetRow.closest('.lcp-nested-container');
    if (!container || container !== draggedRow.closest('.lcp-nested-container')) return;

    var rect = targetRow.getBoundingClientRect();
    var midY = rect.top + rect.height / 2;
    if (e.clientY < midY) {
      container.insertBefore(draggedRow, targetRow);
    } else {
      container.insertBefore(draggedRow, targetRow.nextSibling);
    }

    updatePositionFields(container);
  });

  document.addEventListener('dragend', function(e) {
    if (draggedRow) {
      draggedRow.classList.remove('dragging');
      draggedRow.removeAttribute('draggable');
      draggedRow = null;
    }
    document.querySelectorAll('.lcp-nested-row.drag-over').forEach(function(r) {
      r.classList.remove('drag-over');
    });
  });

  /* Touch support for mobile devices */
  var touchDragRow = null;
  var touchStartY = 0;

  document.addEventListener('touchstart', function(e) {
    var handle = e.target.closest('.lcp-drag-handle');
    if (!handle) return;
    var row = handle.closest('.lcp-nested-row');
    if (!row || isInTemplate(row) || !row.closest('[data-sortable]')) return;
    touchDragRow = row;
    touchStartY = e.touches[0].clientY;
    row.classList.add('dragging');
    e.preventDefault();
  }, { passive: false });

  document.addEventListener('touchmove', function(e) {
    if (!touchDragRow) return;
    e.preventDefault();
    var touchY = e.touches[0].clientY;
    var container = touchDragRow.closest('.lcp-nested-container');
    if (!container) return;

    container.querySelectorAll('.lcp-nested-row.drag-over').forEach(function(r) {
      r.classList.remove('drag-over');
    });

    var rows = container.querySelectorAll('.lcp-nested-row:not(.removed)');
    for (var i = 0; i < rows.length; i++) {
      if (rows[i] === touchDragRow || isInTemplate(rows[i])) continue;
      var rect = rows[i].getBoundingClientRect();
      if (touchY >= rect.top && touchY <= rect.bottom) {
        rows[i].classList.add('drag-over');
        break;
      }
    }
  }, { passive: false });

  document.addEventListener('touchend', function(e) {
    if (!touchDragRow) return;
    var container = touchDragRow.closest('.lcp-nested-container');
    var overRow = container && container.querySelector('.lcp-nested-row.drag-over');

    if (overRow && overRow !== touchDragRow) {
      var rect = overRow.getBoundingClientRect();
      var lastTouchY = e.changedTouches[0].clientY;
      var midY = rect.top + rect.height / 2;
      if (lastTouchY < midY) {
        container.insertBefore(touchDragRow, overRow);
      } else {
        container.insertBefore(touchDragRow, overRow.nextSibling);
      }
      updatePositionFields(container);
    }

    touchDragRow.classList.remove('dragging');
    if (container) {
      container.querySelectorAll('.lcp-nested-row.drag-over').forEach(function(r) {
        r.classList.remove('drag-over');
      });
    }
    touchDragRow = null;
  });

  /* Update positions after adding a row */
  document.addEventListener('click', function(e) {
    var addBtn = e.target.closest('.lcp-nested-add');
    if (!addBtn) return;
    var section = addBtn.closest('.lcp-nested-section');
    if (!section || !section.dataset.sortable) return;
    /* Use setTimeout to run after the main add handler has appended the clone */
    setTimeout(function() {
      var container = section.querySelector('.lcp-nested-container');
      if (container) updatePositionFields(container);
    }, 0);
  });

  /* Update positions after removing a row */
  document.addEventListener('click', function(e) {
    var removeBtn = e.target.closest('.lcp-nested-remove');
    if (!removeBtn) return;
    var section = removeBtn.closest('.lcp-nested-section');
    if (!section || !section.dataset.sortable) return;
    setTimeout(function() {
      var container = section.querySelector('.lcp-nested-container');
      if (container) updatePositionFields(container);
    }, 0);
  });

  /* Initialize position fields on page load */
  document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('[data-sortable]').forEach(function(section) {
      var container = section.querySelector('.lcp-nested-container');
      if (container) updatePositionFields(container);
    });
  });
})();
