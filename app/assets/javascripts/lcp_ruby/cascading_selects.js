// Dependent (cascading) select
(function() {
  var form = document.querySelector('form.lcp-form');
  if (!form) return;

  var dependents = form.querySelectorAll('[data-lcp-depends-on]');
  if (!dependents.length) return;

  var selectOptionsPath = form.dataset.lcpSelectOptionsPath;
  if (!selectOptionsPath) return;

  dependents.forEach(function(dep) {
    var parentFieldName = dep.getAttribute('data-lcp-depends-on');
    var resetStrategy = dep.getAttribute('data-lcp-depends-reset') || 'clear';

    // Find ALL parent inputs (supports select, radio buttons, checkboxes)
    var parentInputs = form.querySelectorAll(
      '[name="record[' + parentFieldName + ']"], ' +
      'input[type="radio"][name="record[' + parentFieldName + ']"], ' +
      'input[type="checkbox"][name$="[' + parentFieldName + ']"]'
    );
    if (!parentInputs.length) return;

    function handleParentChange() {
      var parentValue = getFieldValue(form, parentFieldName);
      var fieldName = dep.name.replace(/^record\[/, '').replace(/\]$/, '');

      // When parent is blank, just clear the dependent — no fetch needed
      if (!parentValue || parentValue === '') {
        var blankOpt = dep.querySelector('option[value=""]');
        var blankTxt = blankOpt ? blankOpt.textContent : '';
        if (dep.tomselect) {
          dep.tomselect.destroy();
          dep.innerHTML = '';
          if (blankTxt) {
            var bo = document.createElement('option');
            bo.value = ''; bo.textContent = blankTxt;
            dep.appendChild(bo);
          }
          dep.value = '';
          new TomSelect(dep, { plugins: [], create: false, allowEmptyOption: true });
        } else {
          dep.innerHTML = '';
          if (blankOpt) dep.appendChild(blankOpt.cloneNode(true));
          dep.value = '';
        }
        dep._lcpKeepIfValid = false;
        dep.dispatchEvent(new Event('change', { bubbles: true }));
        dep.dispatchEvent(new CustomEvent('lcp:cascade-done'));
        return;
      }

      var url = selectOptionsPath + '?field=' + encodeURIComponent(fieldName) +
                '&depends_on[' + encodeURIComponent(parentFieldName) + ']=' + encodeURIComponent(parentValue);

      // Disable select and show loading indicator during fetch
      dep.disabled = true;
      dep.classList.add('lcp-loading');

      var effectiveReset = dep._lcpKeepIfValid ? 'keep_if_valid' : resetStrategy;

      fetch(url, { headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest' } })
        .then(function(resp) { return resp.json(); })
        .then(function(data) {
          var currentValue = dep.value;
          var includeBlank = dep.querySelector('option[value=""]');
          var blankText = includeBlank ? includeBlank.textContent : '';

          // Collect all valid values
          var allValues = [];
          var flatOpts = [];

          if (Array.isArray(data) && data.length > 0 && data[0].group !== undefined) {
            data.forEach(function(g) {
              g.options.forEach(function(opt) {
                flatOpts.push(opt);
                allValues.push(String(opt.value));
              });
            });
          } else if (Array.isArray(data)) {
            data.forEach(function(opt) {
              flatOpts.push(opt);
              allValues.push(String(opt.value));
            });
          }

          var keepValid = effectiveReset === 'keep_if_valid' && allValues.indexOf(currentValue) !== -1;

          if (dep.tomselect) {
            // Destroy and re-init Tom Select to fully reset the sifter
            var hadInlineCreate = dep.hasAttribute('data-lcp-inline-create');
            var isRemote = dep.getAttribute('data-lcp-search') === 'remote';
            dep.tomselect.destroy();

            // Rebuild <option> elements on the underlying <select>
            dep.innerHTML = '';
            if (includeBlank || blankText) {
              var blankEl = document.createElement('option');
              blankEl.value = '';
              blankEl.textContent = blankText;
              dep.appendChild(blankEl);
            }
            flatOpts.forEach(function(opt) {
              var el = document.createElement('option');
              el.value = opt.value;
              el.textContent = opt.label;
              if (opt.disabled) el.disabled = true;
              dep.appendChild(el);
            });

            dep.value = keepValid ? currentValue : '';
            dep.disabled = false; // clear before Tom Select init so it starts enabled
            dep.classList.remove('lcp-loading'); // clear before init — Tom Select copies classes to wrapper

            // Re-init Tom Select with local mode (options are already populated)
            var tsSettings = { plugins: [], create: false, allowEmptyOption: true };
            var newTs = new TomSelect(dep, tsSettings);

            // Re-attach inline create footer if needed
            if (hadInlineCreate) {
              var footer = document.createElement('div');
              footer.className = 'lcp-ts-add-new';
              var addBtnEl = document.createElement('button');
              addBtnEl.type = 'button';
              addBtnEl.className = 'lcp-ts-add-new-btn';
              addBtnEl.textContent = window.LcpI18n && window.LcpI18n.select.add_new || '+ Add new...';
              addBtnEl.addEventListener('mousedown', function(ev) {
                ev.preventDefault();
                ev.stopPropagation();
                newTs.blur();
                window.lcpOpenInlineCreate(dep);
              });
              footer.appendChild(addBtnEl);
              newTs.dropdown_content.parentNode.appendChild(footer);
            }
          } else {
            // Plain <select> — rebuild options
            dep.innerHTML = '';
            if (includeBlank) {
              dep.appendChild(includeBlank.cloneNode(true));
            }

            if (Array.isArray(data) && data.length > 0 && data[0].group !== undefined) {
              data.forEach(function(g) {
                var optgroup = document.createElement('optgroup');
                optgroup.label = g.group;
                g.options.forEach(function(opt) {
                  var el = document.createElement('option');
                  el.value = opt.value;
                  el.textContent = opt.label;
                  if (opt.disabled) el.disabled = true;
                  optgroup.appendChild(el);
                });
                dep.appendChild(optgroup);
              });
            } else {
              flatOpts.forEach(function(opt) {
                var el = document.createElement('option');
                el.value = opt.value;
                el.textContent = opt.label;
                if (opt.disabled) el.disabled = true;
                dep.appendChild(el);
              });
            }

            dep.value = keepValid ? currentValue : '';
          }

          dep._lcpKeepIfValid = false;
          dep.dispatchEvent(new Event('change', { bubbles: true }));
        })
        .catch(function(err) { console.warn('[LcpRuby] Dependent select fetch failed:', err); })
        .finally(function() {
          dep.disabled = false;
          dep.classList.remove('lcp-loading');
          if (dep.tomselect) dep.tomselect.enable();
          dep.dispatchEvent(new CustomEvent('lcp:cascade-done'));
        });
    }

    // Bind change listener to each parent input
    parentInputs.forEach(function(parentInput) {
      parentInput.addEventListener('change', handleParentChange);
    });
  });
})();

// Reverse cascade: auto-fill parent selects when a child is selected
(function() {
  var form = document.querySelector('form.lcp-form');
  if (!form) return;

  var dependents = form.querySelectorAll('[data-lcp-depends-on]');
  if (!dependents.length) return;

  var selectOptionsPath = form.dataset.lcpSelectOptionsPath;
  if (!selectOptionsPath) return;

  // Build a map of field_name -> depends_on chain (bottom to top)
  function getAncestorChain(dep) {
    var chain = [];
    var current = dep;
    var seen = {};
    while (current) {
      var parentFieldName = current.getAttribute('data-lcp-depends-on');
      if (!parentFieldName || seen[parentFieldName]) break;
      seen[parentFieldName] = true;
      var parentEl = form.querySelector('[name="record[' + parentFieldName + ']"]');
      chain.push({ fieldName: parentFieldName, element: parentEl });
      current = parentEl;
    }
    return chain;
  }

  function hasEmptyAncestor(chain) {
    for (var i = 0; i < chain.length; i++) {
      if (!chain[i].element) return true;
      var val = chain[i].element.value;
      if (!val || val === '') return true;
    }
    return false;
  }

  function setFieldValue(fieldEl, value, label) {
    if (!fieldEl) return;
    if (fieldEl.tomselect) {
      fieldEl.tomselect.addOption({ value: String(value), text: label });
      fieldEl.tomselect.setValue(String(value), true); // silent
    } else {
      // Ensure the option exists
      var existing = fieldEl.querySelector('option[value="' + value + '"]');
      if (!existing) {
        var opt = document.createElement('option');
        opt.value = value;
        opt.textContent = label;
        fieldEl.appendChild(opt);
      }
      fieldEl.value = String(value);
    }
  }

  // Trigger cascade from the topmost ancestor down, waiting for each level
  function cascadeFromTop(chain, callback) {
    // chain is bottom-to-top; reverse for top-down processing
    var topDown = chain.slice().reverse();
    var idx = 0;

    function next() {
      if (idx >= topDown.length) {
        if (callback) callback();
        return;
      }
      var entry = topDown[idx];
      idx++;
      if (!entry.element) { next(); return; }

      // Set keep_if_valid flag so cascade preserves child values
      // Find all dependents of this field and set flag
      var fieldName = entry.fieldName;
      var children = form.querySelectorAll('[data-lcp-depends-on="' + fieldName + '"]');
      children.forEach(function(child) { child._lcpKeepIfValid = true; });

      // Listen for cascade-done on the immediate child
      if (children.length > 0) {
        var child = children[0];
        var onDone = function() {
          child.removeEventListener('lcp:cascade-done', onDone);
          next();
        };
        child.addEventListener('lcp:cascade-done', onDone);
      }

      // Dispatch change to trigger cascade
      entry.element.dispatchEvent(new Event('change', { bubbles: true }));

      // If no children to cascade, proceed immediately
      if (children.length === 0) { next(); }
    }

    next();
  }

  dependents.forEach(function(dep) {
    dep.addEventListener('change', function() {
      var selectedValue = dep.value;
      if (!selectedValue || selectedValue === '') return;

      var chain = getAncestorChain(dep);
      if (!chain.length) return;
      if (!hasEmptyAncestor(chain)) return;

      var fieldName = dep.name.replace(/^record\[/, '').replace(/\]$/, '');
      var url = selectOptionsPath + '?field=' + encodeURIComponent(fieldName) +
                '&ancestors_for=' + encodeURIComponent(selectedValue);

      fetch(url, { headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest' } })
        .then(function(resp) { return resp.json(); })
        .then(function(data) {
          var ancestors = data.ancestors;
          if (!ancestors || !ancestors.length) return;

          // Set values top-down (ancestors are bottom-to-top from server, reverse for top-down)
          var topDown = ancestors.slice().reverse();
          topDown.forEach(function(anc) {
            var el = form.querySelector('[name="record[' + anc.field + ']"]');
            if (el) {
              setFieldValue(el, anc.value, anc.label);
            }
          });

          // Now trigger cascade from the topmost parent down to populate dropdowns
          cascadeFromTop(chain, null);
        })
        .catch(function(err) { console.warn('[LcpRuby] Reverse cascade failed:', err); });
    });
  });
})();
