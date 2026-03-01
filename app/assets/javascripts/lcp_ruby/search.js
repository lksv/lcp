/* Auto-search with debounce */
(function() {
  var timers = {};

  document.addEventListener('input', function(e) {
    var input = e.target;
    if (input.tagName !== 'INPUT' || input.name !== 'q') return;

    var form = input.closest('[data-lcp-auto-search]');
    if (!form || form.dataset.lcpAutoSearch !== 'true') return;

    var debounceMs = parseInt(form.dataset.lcpDebounce || '300', 10);
    var minQuery = parseInt(form.dataset.lcpMinQuery || '2', 10);
    var formId = form.action || 'default';

    clearTimeout(timers[formId]);

    if (input.value.length === 0 || input.value.length >= minQuery) {
      timers[formId] = setTimeout(function() {
        form.submit();
      }, debounceMs);
    }
  });
})();
