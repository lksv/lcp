/* Custom fields manage page: expand/collapse, add/remove rows, reindex */
(function() {
  /* Expand/collapse detail section */
  document.addEventListener('click', function(e) {
    var btn = e.target.closest('.lcp-manage-expand');
    if (!btn) return;
    var row = btn.closest('.lcp-manage-row');
    if (!row) return;
    var detail = row.querySelector('.lcp-manage-detail');
    if (!detail) return;

    var form = btn.closest('form');
    var labelDetails  = (form && form.dataset.lcpLabelDetails)  || 'Details';
    var labelCollapse = (form && form.dataset.lcpLabelCollapse) || 'Collapse';

    if (detail.style.display === 'none') {
      detail.style.display = '';
      btn.textContent = labelCollapse;
    } else {
      detail.style.display = 'none';
      btn.textContent = labelDetails;
    }
  });

  /* Add new row */
  document.addEventListener('click', function(e) {
    var btn = e.target.closest('.lcp-manage-add');
    if (!btn) return;
    var form = btn.closest('form');
    if (!form) return;
    var template = form.querySelector('[data-lcp-manage-template]');
    if (!template) return;
    var container = form.querySelector('.lcp-manage-container');
    if (!container) return;

    var clone = template.firstElementChild.cloneNode(true);
    var ts = new Date().getTime();
    clone.innerHTML = clone.innerHTML.replace(/NEW_RECORD/g, ts);
    clone.style.display = '';
    /* Re-enable inputs in the cloned row (disabled server-side in the template) */
    clone.querySelectorAll('fieldset[disabled]').forEach(function(fs) {
      fs.removeAttribute('disabled');
    });
    container.appendChild(clone);

    reindexManageRows(container);

    /* Trigger conditional rendering on new row */
    var firstInput = clone.querySelector('input, select, textarea');
    if (firstInput) {
      firstInput.dispatchEvent(new Event('change', { bubbles: true }));
    }
  });

  /* Remove row (soft-delete: set _remove flag) */
  document.addEventListener('click', function(e) {
    var btn = e.target.closest('.lcp-manage-remove-btn');
    if (!btn) return;
    var row = btn.closest('.lcp-manage-row');
    if (!row) return;

    var removeFlag = row.querySelector('.lcp-manage-remove-flag');
    if (removeFlag) {
      removeFlag.value = '1';
      row.classList.add('removed');
    } else {
      row.remove();
    }

    var container = row.closest('.lcp-manage-container');
    if (container) reindexManageRows(container);
  });

  /* Reindex row positions after add/remove */
  function reindexManageRows(container) {
    var rows = container.querySelectorAll('.lcp-manage-row:not(.removed)');
    rows.forEach(function(row, index) {
      var posField = row.querySelector('.lcp-position-field');
      if (posField) posField.value = index;
    });
  }
})();
