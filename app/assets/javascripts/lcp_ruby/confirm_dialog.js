// Styled confirmation dialog
(function() {
  var dialog = document.getElementById('lcp-confirm-dialog');
  if (!dialog) return;

  var pendingResolve = null;

  function showConfirmDialog(title, message, style) {
    var titleEl = document.getElementById('lcp-confirm-title');
    var messageEl = document.getElementById('lcp-confirm-message');
    var okBtn = document.getElementById('lcp-confirm-ok');

    titleEl.textContent = title;
    messageEl.textContent = message;

    // Apply style
    okBtn.className = style === 'danger' ? 'btn btn-danger' : 'btn btn-primary';

    dialog.showModal();

    return new Promise(function(resolve) {
      pendingResolve = resolve;
    });
  }

  function resolveDialog(value) {
    dialog.close();
    if (pendingResolve) {
      pendingResolve(value);
      pendingResolve = null;
    }
  }

  document.getElementById('lcp-confirm-ok').addEventListener('click', function() { resolveDialog(true); });
  document.getElementById('lcp-confirm-cancel').addEventListener('click', function() { resolveDialog(false); });
  document.getElementById('lcp-confirm-cancel-x').addEventListener('click', function() { resolveDialog(false); });
  dialog.addEventListener('click', function(e) { if (e.target === dialog) resolveDialog(false); });

  // Intercept clicks on elements with data-lcp-confirm-title
  document.addEventListener('click', function(e) {
    var target = e.target.closest('[data-lcp-confirm-title]');
    if (!target) return;
    // Skip if already confirmed (avoid re-prompting on re-submit)
    if (target.getAttribute('data-lcp-confirmed') === 'true') {
      target.removeAttribute('data-lcp-confirmed');
      return;
    }

    // Check if this is inside a form (button_to generates a form)
    var form = target.closest('form');
    var title = target.getAttribute('data-lcp-confirm-title');
    var message = target.getAttribute('data-lcp-confirm-message');
    var style = target.getAttribute('data-lcp-confirm-style');

    if (!title) return;

    e.preventDefault();
    e.stopPropagation();

    showConfirmDialog(title, message || 'Are you sure?', style).then(function(confirmed) {
      if (confirmed) {
        if (form) {
          // Mark as confirmed and re-submit
          target.setAttribute('data-lcp-confirmed', 'true');
          form.requestSubmit(target);
        } else if (target.href) {
          window.location.href = target.href;
        }
      }
    });
  }, true);

  // Intercept clicks on elements with data-lcp-confirm-page (page-based confirmation dialogs)
  document.addEventListener('click', function(e) {
    var target = e.target.closest('[data-lcp-confirm-page]');
    if (!target) return;

    e.preventDefault();
    e.stopPropagation();

    var dialogUrl = target.getAttribute('data-lcp-confirm-page-url');
    var size = target.getAttribute('data-lcp-confirm-page-size') || 'medium';
    var actionUrl = target.href;
    var actionMethod = target.getAttribute('data-lcp-confirm-action-method') || 'post';

    lcpOpenDialog(dialogUrl, {
      size: size,
      onSuccess: 'confirm_action',
      pendingAction: { url: actionUrl, method: actionMethod }
    });
  }, true);

  // Also intercept form submits that contain a confirmed button
  document.addEventListener('submit', function(e) {
    var form = e.target;
    var confirmBtn = form.querySelector('[data-lcp-confirm-title]');
    if (!confirmBtn) return;
    // Skip if already confirmed
    if (confirmBtn.getAttribute('data-lcp-confirmed') === 'true') {
      confirmBtn.removeAttribute('data-lcp-confirmed');
      return;
    }

    var title = confirmBtn.getAttribute('data-lcp-confirm-title');
    if (!title) return;

    e.preventDefault();

    var message = confirmBtn.getAttribute('data-lcp-confirm-message');
    var style = confirmBtn.getAttribute('data-lcp-confirm-style');

    showConfirmDialog(title, message || 'Are you sure?', style).then(function(confirmed) {
      if (confirmed) {
        confirmBtn.setAttribute('data-lcp-confirmed', 'true');
        form.requestSubmit();
      }
    });
  }, true);
})();
