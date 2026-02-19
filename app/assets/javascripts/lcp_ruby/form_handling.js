document.addEventListener('submit', function(e) {
  var confirmMsg = (e.submitter && e.submitter.dataset.turboConfirm) ||
                   e.target.dataset.turboConfirm;
  if (confirmMsg && !confirm(confirmMsg)) {
    e.preventDefault();
  }
});

// Multi-select min/max validation via native constraint API
(function() {
  var form = document.querySelector('form.lcp-form');
  if (!form) return;

  var multiSelects = form.querySelectorAll('select[multiple][data-min], select[multiple][data-max]');
  if (!multiSelects.length) return;

  function validate(sel) {
    var count = sel.selectedOptions.length;
    var min = sel.getAttribute('data-min');
    var max = sel.getAttribute('data-max');
    var msgs = [];

    if (min && count < parseInt(min, 10)) {
      msgs.push('Select at least ' + min + ' item(s)');
    }
    if (max && count > parseInt(max, 10)) {
      msgs.push('Select at most ' + max + ' item(s)');
    }

    var msgEl = sel.parentElement.querySelector('.lcp-multi-select-error');
    if (msgs.length > 0) {
      if (!msgEl) {
        msgEl = document.createElement('span');
        msgEl.className = 'lcp-multi-select-error lcp-field-error';
        sel.parentElement.appendChild(msgEl);
      }
      msgEl.textContent = msgs.join('. ');
      sel.setCustomValidity(msgs.join('. '));
    } else {
      if (msgEl) msgEl.remove();
      sel.setCustomValidity('');
    }
  }

  multiSelects.forEach(function(sel) {
    sel.addEventListener('change', function() { validate(sel); });
    validate(sel); // validate initial state (e.g. editing existing record)
  });
})();
