/* Conditional rendering (visible_when / disable_when) */
(function() {
  function evaluateCondition(value, operator, conditionValue) {
    switch (operator) {
      case 'eq':
        return String(value) === String(conditionValue);
      case 'not_eq': case 'neq':
        return String(value) !== String(conditionValue);
      case 'in': {
        const inList = String(conditionValue).split(',');
        return inList.indexOf(String(value)) !== -1;
      }
      case 'not_in': {
        const notInList = String(conditionValue).split(',');
        return notInList.indexOf(String(value)) === -1;
      }
      case 'gt':
        return parseFloat(value) > parseFloat(conditionValue);
      case 'gte':
        return parseFloat(value) >= parseFloat(conditionValue);
      case 'lt':
        return parseFloat(value) < parseFloat(conditionValue);
      case 'lte':
        return parseFloat(value) <= parseFloat(conditionValue);
      case 'present':
        return value !== '' && value !== null && value !== undefined;
      case 'blank':
        return value === '' || value === null || value === undefined;
      case 'matches':
        try { return new RegExp(conditionValue).test(String(value)); } catch(e) { return false; }
      case 'not_matches':
        try { return !new RegExp(conditionValue).test(String(value)); } catch(e) { return true; }
      default:
        return String(value) === String(conditionValue);
    }
  }

  function applyConditions(form) {
    var elements = form.querySelectorAll('[data-lcp-conditional]');
    elements.forEach(function(el) {
      /* visible_when */
      var visField = el.getAttribute('data-lcp-visible-field');
      if (visField) {
        var visOp = el.getAttribute('data-lcp-visible-operator') || 'eq';
        var visVal = el.getAttribute('data-lcp-visible-value');
        var fieldValue = getFieldValue(form, visField);
        var visible = evaluateCondition(fieldValue, visOp, visVal);
        el.style.display = visible ? '' : 'none';

        /* When a tab button is hidden/shown, also hide/show its panel */
        if (el.getAttribute('data-lcp-conditional') === 'tab') {
          var tabIndex = el.getAttribute('data-lcp-tab');
          var tabs = el.closest('.lcp-tabs');
          if (tabs && tabIndex) {
            var panel = tabs.querySelector('[data-lcp-panel="' + tabIndex + '"]');
            if (panel && !visible) {
              panel.style.display = 'none';
              el.classList.remove('active');
            }
          }
        }
      }
      /* disable_when */
      var disField = el.getAttribute('data-lcp-disable-field');
      if (disField) {
        var disOp = el.getAttribute('data-lcp-disable-operator') || 'eq';
        var disVal = el.getAttribute('data-lcp-disable-value');
        var disFieldValue = getFieldValue(form, disField);
        var disabled = evaluateCondition(disFieldValue, disOp, disVal);
        if (disabled) {
          el.classList.add('lcp-conditionally-disabled');
        } else {
          el.classList.remove('lcp-conditionally-disabled');
        }
        /* Properly disable/enable all form controls and Tom Select instances */
        el.querySelectorAll('input, select, textarea').forEach(function(ctrl) {
          ctrl.disabled = disabled;
          if (ctrl.tomselect) {
            disabled ? ctrl.tomselect.disable() : ctrl.tomselect.enable();
          }
        });
      }
    });

    /* Ensure a visible tab is active when active tab gets hidden */
    form.querySelectorAll('.lcp-tabs').forEach(function(tabs) {
      var activeBtn = tabs.querySelector('.lcp-tab-nav .btn.active');
      if (!activeBtn || activeBtn.style.display === 'none') {
        var firstVisible = tabs.querySelector('.lcp-tab-nav .btn:not([style*="display:none"]):not([style*="display: none"])');
        if (firstVisible) {
          firstVisible.classList.add('active');
          var idx = firstVisible.getAttribute('data-lcp-tab');
          var panel = tabs.querySelector('[data-lcp-panel="' + idx + '"]');
          if (panel) panel.style.display = '';
        }
      }
    });
  }

  /* Delegated event listeners for form changes */
  function handleFormChange(e) {
    var form = e.target.closest('form');
    if (form && form.querySelector('[data-lcp-conditional]')) {
      applyConditions(form);
    }
  }

  document.addEventListener('change', handleFormChange);
  document.addEventListener('input', handleFormChange);

  /* Initial evaluation on page load */
  document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('form').forEach(function(form) {
      if (form.querySelector('[data-lcp-conditional]')) {
        applyConditions(form);
      }
    });
  });

  /* AJAX for service conditions */
  let debounceTimer = null;
  document.addEventListener('change', function(e) {
    var form = e.target.closest('form');
    if (!form) return;
    var condUrl = form.getAttribute('data-lcp-conditions-url');
    if (!condUrl) return;

    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(function() {
      var formData = new FormData(form);
      var csrfMeta = document.querySelector('meta[name="csrf-token"]');
      var csrfToken = csrfMeta ? csrfMeta.content : null;
      var headers = { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest' };
      if (csrfToken) headers['X-CSRF-Token'] = csrfToken;
      fetch(condUrl, {
        method: 'POST',
        body: formData,
        headers: headers
      }).then(function(r) { return r.json(); }).then(function(data) {
        var serviceEls = form.querySelectorAll('[data-lcp-service-condition]');
        serviceEls.forEach(function(el) {
          var fieldName = el.getAttribute('data-lcp-field-name');
          var condType = el.getAttribute('data-lcp-conditional');
          var serviceTypes = el.getAttribute('data-lcp-service-condition').split(',');

          serviceTypes.forEach(function(serviceType) {
            var key;
            if (condType === 'field') {
              key = fieldName + '_' + serviceType;
            } else {
              key = condType + '_' + serviceType;
            }

            if (data.hasOwnProperty(key)) {
              if (serviceType === 'visible') {
                el.style.display = data[key] ? '' : 'none';
              } else if (serviceType === 'disable') {
                if (data[key]) {
                  el.classList.add('lcp-conditionally-disabled');
                } else {
                  el.classList.remove('lcp-conditionally-disabled');
                }
              }
            }
          });
        });
      }).catch(function(err) { console.warn('[LcpRuby] Service condition evaluation failed:', err); });
    }, 300);
  });
})();
