// Tom Select initialization
(function() {
  if (typeof TomSelect === 'undefined') return;

  document.addEventListener('DOMContentLoaded', function() {
    var selects = document.querySelectorAll('select[data-lcp-search]');
    selects.forEach(function(selectEl) {
      var mode = selectEl.getAttribute('data-lcp-search');

      if (mode === 'remote') {
        // Remote mode: AJAX search with pagination
        var searchUrl = selectEl.getAttribute('data-lcp-search-url');
        var perPage = parseInt(selectEl.getAttribute('data-lcp-per-page')) || 25;
        var minQuery = parseInt(selectEl.getAttribute('data-lcp-min-query')) || 1;
        var isMultiple = selectEl.hasAttribute('multiple');
        var plugins = [];
        if (isMultiple) plugins.push('remove_button');

        // Clear pre-rendered options for remote mode (fetched on demand)
        var blankOpt = selectEl.querySelector('option[value=""]');
        selectEl.innerHTML = '';
        if (blankOpt) selectEl.appendChild(blankOpt);

        var lastQuery = '';
        new TomSelect(selectEl, {
          valueField: 'value',
          labelField: 'text',
          searchField: 'text',
          plugins: plugins,
          maxOptions: null,
          load: function(query, callback) {
            if (query.length < minQuery) return callback();
            var self = this;
            // Reset page counter when query changes
            if (query !== lastQuery) {
              self.currentPage = 1;
              lastQuery = query;
            }
            var page = self.currentPage || 1;
            var url = searchUrl + '&q=' + encodeURIComponent(query) + '&page=' + page + '&per_page=' + perPage;

            // Include depends_on parent filter for remote dependent selects
            var dependsOn = selectEl.getAttribute('data-lcp-depends-on');
            if (dependsOn) {
              var parentForm = selectEl.closest('form');
              if (parentForm) {
                var parentValue = getFieldValue(parentForm, dependsOn);
                if (parentValue) {
                  url += '&depends_on[' + encodeURIComponent(dependsOn) + ']=' + encodeURIComponent(parentValue);
                }
              }
            }

            fetch(url, { headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest' } })
              .then(function(resp) { return resp.json(); })
              .then(function(data) {
                var options = data.options || data;
                var items = options.map(function(opt) {
                  return { value: String(opt.value), text: opt.label, disabled: !!opt.disabled };
                });
                callback(items);
                if (data.has_more) {
                  self.currentPage = page + 1;
                }
              })
              .catch(function() { callback(); });
          },
          shouldLoad: function(query) {
            return query.length >= minQuery;
          },
          render: {
            no_results: function() {
              return '<div class="no-results">' + (window.LcpI18n && window.LcpI18n.select.no_results || 'No results found') + '</div>';
            },
            loading_more: function() {
              return '<div class="loading-more-results">' + (window.LcpI18n && window.LcpI18n.select.loading_more || 'Loading more...') + '</div>';
            }
          }
        });
      } else {
        // Local mode: client-side filtering of inline options
        var isMultiple = selectEl.hasAttribute('multiple');
        var plugins = [];
        if (isMultiple) plugins.push('remove_button');

        new TomSelect(selectEl, {
          plugins: plugins,
          create: false,
          allowEmptyOption: true
        });
      }

      // Apply display mode class to Tom Select wrapper
      var displayMode = selectEl.getAttribute('data-lcp-display-mode');
      if (displayMode && selectEl.tomselect) {
        selectEl.tomselect.wrapper.classList.add('lcp-' + displayMode);
      }

      // Inline create: add "Add new..." footer button to Tom Select dropdown
      if (selectEl.hasAttribute('data-lcp-inline-create') && selectEl.tomselect) {
        var ts = selectEl.tomselect;
        var footer = document.createElement('div');
        footer.className = 'lcp-ts-add-new';
        var addBtn = document.createElement('button');
        addBtn.type = 'button';
        addBtn.className = 'lcp-ts-add-new-btn';
        addBtn.textContent = window.LcpI18n && window.LcpI18n.select.add_new || '+ Add new...';
        addBtn.addEventListener('mousedown', function(ev) {
          ev.preventDefault();
          ev.stopPropagation();
          ts.blur();
          window.lcpOpenInlineCreate(selectEl);
        });
        footer.appendChild(addBtn);
        ts.dropdown_content.parentNode.appendChild(footer);
      }
    });
  });
})();
