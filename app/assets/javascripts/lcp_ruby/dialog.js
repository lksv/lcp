// Dialog modal functionality
(function() {
  var dialog = document.getElementById('lcp-dialog');
  if (!dialog) return;

  var currentOptions = {};

  window.lcpOpenDialog = function(url, options) {
    options = options || {};
    currentOptions = options;

    // Close any existing dialog first (no nesting — D7)
    if (dialog.open) {
      dialog.close();
    }

    // Apply size class if specified
    var size = options.size || 'medium';
    dialog.className = 'lcp-dialog lcp-dialog-' + size;

    fetch(url, {
      headers: { 'Accept': 'text/html', 'X-Requested-With': 'XMLHttpRequest' }
    })
    .then(function(resp) {
      if (!resp.ok) throw new Error('Failed to load dialog');
      return resp.text();
    })
    .then(function(html) {
      dialog.innerHTML = html;
      // Read size from response if available (resolved_dialog_config)
      var sizeEl = dialog.querySelector('[data-lcp-dialog-size]');
      if (sizeEl) {
        var resolvedSize = sizeEl.getAttribute('data-lcp-dialog-size');
        if (resolvedSize) size = resolvedSize;
      }
      dialog.className = 'lcp-dialog lcp-dialog-' + size;
      dialog.showModal();
      attachDialogHandlers();
    })
    .catch(function(err) {
      console.warn('[LcpRuby] Dialog load failed:', err);
    });
  };

  function attachDialogHandlers() {
    // Close buttons
    var closeButtons = dialog.querySelectorAll('[data-action="close-dialog"]');
    closeButtons.forEach(function(btn) {
      btn.addEventListener('click', function() {
        dialog.close();
      });
    });

    // Form submit interception
    var form = dialog.querySelector('form[data-lcp-dialog-form]');
    if (form) {
      form.addEventListener('submit', function(e) {
        e.preventDefault();
        submitDialogForm(form);
      });
    }
  }

  function submitDialogForm(form) {
    // Allow pre-submit hooks to inject hidden fields or modify form
    if (typeof currentOptions.beforeSubmit === 'function') {
      currentOptions.beforeSubmit(form);
    }

    var formData = new FormData(form);
    var url = form.action;
    var method = form.method || 'POST';

    // Handle Rails _method override for PATCH
    var methodOverride = form.querySelector('input[name="_method"]');
    if (methodOverride) {
      method = 'POST'; // Always POST with _method override
    }

    var headers = { 'X-Requested-With': 'XMLHttpRequest' };
    var csrfMeta = document.querySelector("meta[name='csrf-token']");
    if (csrfMeta) {
      headers['X-CSRF-Token'] = csrfMeta.content;
    }

    fetch(url, {
      method: method,
      headers: headers,
      body: formData
    })
    .then(function(resp) {
      var contentType = resp.headers.get('Content-Type') || '';
      return resp.text().then(function(html) {
        return { ok: resp.ok, status: resp.status, html: html, contentType: contentType };
      });
    })
    .then(function(result) {
      // Stash submitted form data only for confirm_action flow
      if (currentOptions.onSuccess === 'confirm_action') {
        currentOptions.lastFormData = {};
        formData.forEach(function(value, key) {
          if (key === 'authenticity_token' || key === '_method' || key === 'utf8') return;
          var match = key.match(/^record\[(.+)\]$/);
          var cleanKey = match ? match[1] : key;
          currentOptions.lastFormData[cleanKey] = value;
        });
      }

      var tempDiv = document.createElement('div');
      tempDiv.innerHTML = result.html;

      // Check for success marker
      var actionEl = tempDiv.querySelector('[data-lcp-dialog-action]');
      if (actionEl) {
        var action = actionEl.getAttribute('data-lcp-dialog-action');
        dialog.close();
        executeOnSuccess(action);
      } else if (!result.ok && result.contentType && result.contentType.includes('application/json')) {
        // JSON error response — show errors in dialog
        try {
          var data = JSON.parse(result.html);
          var errorHtml = '<div class="lcp-errors"><ul>';
          var errors = data.errors || [data.error];
          errors.forEach(function(e) { errorHtml += '<li>' + e + '</li>'; });
          errorHtml += '</ul></div>';
          var errorContainer = dialog.querySelector('.lcp-errors');
          if (errorContainer) {
            errorContainer.outerHTML = errorHtml;
          } else {
            var body = dialog.querySelector('.lcp-dialog-body');
            if (body) body.insertAdjacentHTML('afterbegin', errorHtml);
          }
        } catch (parseErr) {
          dialog.innerHTML = result.html;
          attachDialogHandlers();
        }
      } else {
        // Re-render form with errors
        dialog.innerHTML = result.html;
        attachDialogHandlers();
      }
    })
    .catch(function(err) {
      console.warn('[LcpRuby] Dialog submit failed:', err);
    });
  }

  function executeOnSuccess(action) {
    switch (action) {
      case 'reload':
        window.location.reload();
        break;
      case 'close':
        // Just close — already done
        break;
      case 'redirect':
        var redirectUrl = currentOptions.redirectUrl;
        if (redirectUrl) {
          window.location.href = redirectUrl;
        }
        break;
      case 'confirm_action':
        if (currentOptions.pendingAction) {
          submitPendingAction(currentOptions.pendingAction, currentOptions.lastFormData);
        }
        break;
      default:
        window.location.reload();
    }
  }

  function submitPendingAction(action, confirmationData) {
    var form = document.createElement('form');
    form.method = 'POST';
    form.action = action.url;
    form.style.display = 'none';

    // CSRF token
    var csrf = document.querySelector("meta[name='csrf-token']");
    if (csrf) {
      var csrfInput = document.createElement('input');
      csrfInput.type = 'hidden';
      csrfInput.name = 'authenticity_token';
      csrfInput.value = csrf.content;
      form.appendChild(csrfInput);
    }

    // Rails method override for DELETE/PATCH
    if (action.method !== 'post') {
      var methodInput = document.createElement('input');
      methodInput.type = 'hidden';
      methodInput.name = '_method';
      methodInput.value = action.method;
      form.appendChild(methodInput);
    }

    // Forward dialog form data as confirmation_data[...]
    if (confirmationData) {
      Object.keys(confirmationData).forEach(function(key) {
        var input = document.createElement('input');
        input.type = 'hidden';
        input.name = 'confirmation_data[' + key + ']';
        input.value = confirmationData[key];
        form.appendChild(input);
      });
    }

    document.body.appendChild(form);
    form.submit();
  }

  // Close on backdrop click
  dialog.addEventListener('click', function(e) {
    if (e.target === dialog) {
      dialog.close();
    }
  });

  // Close on ESC key (native <dialog> behavior, but ensure cleanup)
  dialog.addEventListener('close', function() {
    currentOptions = {};
  });
})();
