// Inline create functionality
(function() {
  var dialog = document.getElementById('lcp-inline-create-dialog');
  if (!dialog) return;

  var currentSelectEl = null;

  window.lcpOpenInlineCreate = function(selectEl) {
    currentSelectEl = selectEl;
    var formUrl = selectEl.getAttribute('data-lcp-inline-create-form-url');
    var targetModel = selectEl.getAttribute('data-lcp-target-model');

    var titleEl = document.getElementById('lcp-inline-dialog-title');
    titleEl.textContent = (window.LcpI18n && window.LcpI18n.form.create || 'Create') + ' ' + (targetModel || '').replace(/_/g, ' ');

    var contentEl = document.getElementById('lcp-inline-dialog-content');
    contentEl.innerHTML = '';

    var errorsEl = document.getElementById('lcp-inline-dialog-errors');
    errorsEl.style.display = 'none';
    errorsEl.textContent = '';

    fetch(formUrl + '?target_model=' + encodeURIComponent(targetModel), {
      headers: { 'Accept': 'text/html', 'X-Requested-With': 'XMLHttpRequest' }
    })
    .then(function(resp) {
      if (!resp.ok) throw new Error('Failed to load form');
      return resp.text();
    })
    .then(function(html) {
      contentEl.innerHTML = html;
      dialog.showModal();
    })
    .catch(function(err) {
      console.warn('[LcpRuby] Inline create form load failed:', err);
    });
  };

  // Cancel button
  document.getElementById('lcp-inline-dialog-cancel').addEventListener('click', function() {
    dialog.close();
    currentSelectEl = null;
  });

  // Close on backdrop click
  dialog.addEventListener('click', function(e) {
    if (e.target === dialog) {
      dialog.close();
      currentSelectEl = null;
    }
  });

  // Save button
  document.getElementById('lcp-inline-dialog-save').addEventListener('click', function() {
    if (!currentSelectEl) return;

    var createUrl = currentSelectEl.getAttribute('data-lcp-inline-create-url');
    var targetModel = currentSelectEl.getAttribute('data-lcp-target-model');
    var labelMethod = currentSelectEl.getAttribute('data-lcp-label-method');

    var contentEl = document.getElementById('lcp-inline-dialog-content');
    var errorsEl = document.getElementById('lcp-inline-dialog-errors');

    // Build form data from inline fields
    var formData = new FormData();
    var inputs = contentEl.querySelectorAll('input, textarea, select');
    inputs.forEach(function(input) {
      if (input.type === 'hidden' && input.nextElementSibling && input.nextElementSibling.type === 'checkbox') {
        // Skip Rails hidden field paired with a checkbox; the checkbox handles the value
        return;
      }
      if (input.type === 'checkbox') {
        formData.set(input.name, input.checked ? '1' : '0');
      } else {
        formData.append(input.name, input.value);
      }
    });

    var url = createUrl + '?target_model=' + encodeURIComponent(targetModel);
    if (labelMethod) url += '&label_method=' + encodeURIComponent(labelMethod);

    var csrfToken = document.querySelector('meta[name="csrf-token"]');
    var headers = { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest' };
    if (csrfToken) headers['X-CSRF-Token'] = csrfToken.content;

    fetch(url, {
      method: 'POST',
      body: formData,
      headers: headers
    })
    .then(function(resp) { return resp.json().then(function(data) { return { ok: resp.ok, data: data }; }); })
    .then(function(result) {
      if (result.ok) {
        // Add new option to Tom Select and select it
        if (currentSelectEl.tomselect) {
          currentSelectEl.tomselect.addOption({ value: String(result.data.id), text: result.data.label });
          currentSelectEl.tomselect.setValue(String(result.data.id), false);
          currentSelectEl.tomselect.refreshOptions(false);
        } else {
          var opt = document.createElement('option');
          opt.value = result.data.id;
          opt.textContent = result.data.label;
          opt.selected = true;
          currentSelectEl.appendChild(opt);
        }
        dialog.close();
        currentSelectEl.dispatchEvent(new Event('change', { bubbles: true }));
        currentSelectEl = null;
      } else {
        errorsEl.textContent = (result.data.errors || []).join(', ');
        errorsEl.style.display = 'block';
      }
    })
    .catch(function(err) {
      errorsEl.textContent = 'An error occurred. Please try again.';
      errorsEl.style.display = 'block';
      console.warn('[LcpRuby] Inline create failed:', err);
    });
  });
})();
