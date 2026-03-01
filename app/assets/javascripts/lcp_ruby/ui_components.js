/* Tab switching */
document.addEventListener('click', function(e) {
  var tabBtn = e.target.closest('[data-lcp-tab]');
  if (tabBtn) {
    var tabs = tabBtn.closest('.lcp-tabs');
    if (!tabs) return;
    var index = tabBtn.dataset.lcpTab;
    tabs.querySelectorAll('[data-lcp-tab]').forEach(function(b) { b.classList.remove('active'); });
    tabs.querySelectorAll('[data-lcp-panel]').forEach(function(p) { p.style.display = 'none'; });
    tabBtn.classList.add('active');
    var panel = tabs.querySelector('[data-lcp-panel="' + index + '"]');
    if (panel) panel.style.display = '';
  }
});

/* Collapsible sections */
document.addEventListener('click', function(e) {
  var toggle = e.target.closest('.lcp-collapse-toggle');
  if (toggle) {
    var fieldset = toggle.closest('.lcp-collapsible');
    if (!fieldset) return;
    var content = fieldset.querySelector('.lcp-collapsible-content');
    if (content) {
      var hidden = content.style.display === 'none';
      content.style.display = hidden ? '' : 'none';
      fieldset.classList.toggle('lcp-collapsed', !hidden);
    }
  }
});

/* Row click navigation */
document.addEventListener('click', function(e) {
  var row = e.target.closest('.lcp-row-clickable');
  if (row && !e.target.closest('a, button, form, .lcp-actions')) {
    window.location = row.dataset.href;
  }
});

/* Actions dropdown */
document.addEventListener('click', function(e) {
  var toggle = e.target.closest('.lcp-dropdown-toggle');
  if (toggle) {
    var dropdown = toggle.closest('.lcp-actions-dropdown');
    if (dropdown) {
      document.querySelectorAll('.lcp-actions-dropdown.open').forEach(function(d) {
        if (d !== dropdown) d.classList.remove('open');
      });
      dropdown.classList.toggle('open');
      e.stopPropagation();
    }
  } else {
    document.querySelectorAll('.lcp-actions-dropdown.open').forEach(function(d) { d.classList.remove('open'); });
  }
});

/* Copy URL to clipboard */
document.addEventListener('click', function(e) {
  var btn = e.target.closest('[data-lcp-copy-url]');
  if (!btn || !navigator.clipboard) return;
  var url = btn.dataset.lcpCopyUrl;
  navigator.clipboard.writeText(url).then(function() {
    var original = btn.textContent;
    btn.textContent = btn.dataset.lcpCopiedText || 'Copied!';
    btn.classList.add('lcp-copied');
    setTimeout(function() {
      btn.textContent = original;
      btn.classList.remove('lcp-copied');
    }, 2000);
  }).catch(function() {});
});

/* Copy field value to clipboard */
document.addEventListener('click', function(e) {
  var btn = e.target.closest('[data-lcp-copy-value]');
  if (!btn || !navigator.clipboard) return;
  var value = btn.dataset.lcpCopyValue;
  navigator.clipboard.writeText(value).then(function() {
    btn.classList.add('lcp-copied');
    setTimeout(function() { btn.classList.remove('lcp-copied'); }, 2000);
  }).catch(function() {});
});
