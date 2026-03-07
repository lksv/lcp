/* Array input — tag chips with add/remove and suggestions */
document.addEventListener('DOMContentLoaded', function() {
  document.querySelectorAll('[data-lcp-array-input]').forEach(initArrayInput);
});

function initArrayInput(wrapper) {
  var hiddenField = wrapper.querySelector('[data-lcp-array-value]');
  var chipsContainer = wrapper.querySelector('[data-lcp-array-chips]');
  var textInput = wrapper.querySelector('[data-lcp-array-text-input]');
  if (!hiddenField || !chipsContainer || !textInput) return;

  var max = wrapper.dataset.lcpMax ? parseInt(wrapper.dataset.lcpMax, 10) : null;
  var suggestions = [];
  try { suggestions = JSON.parse(wrapper.dataset.lcpSuggestions || '[]'); } catch(e) { /* ignore */ }

  var suggestionsDropdown = null;

  function getValues() {
    try { return JSON.parse(hiddenField.value || '[]'); } catch(e) { return []; }
  }

  function setValues(arr) {
    hiddenField.value = JSON.stringify(arr);
  }

  function addValue(val) {
    val = val.trim();
    if (!val) return;
    var current = getValues();
    if (current.indexOf(val) !== -1) return; // duplicate
    if (max && current.length >= max) return; // at max
    current.push(val);
    setValues(current);
    renderChips();
  }

  function removeValue(val) {
    var current = getValues().filter(function(v) { return v !== val; });
    setValues(current);
    renderChips();
  }

  function renderChips() {
    chipsContainer.innerHTML = '';
    getValues().forEach(function(val) {
      var chip = document.createElement('span');
      chip.className = 'lcp-array-chip';

      var text = document.createElement('span');
      text.className = 'lcp-array-chip-text';
      text.textContent = val;
      chip.appendChild(text);

      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'lcp-array-chip-remove';
      btn.textContent = '\u00d7';
      btn.addEventListener('click', function() { removeValue(val); });
      chip.appendChild(btn);

      chipsContainer.appendChild(chip);
    });
  }

  // Prevent form submission on Enter; add tag instead
  textInput.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      e.stopPropagation();
      addValue(textInput.value);
      textInput.value = '';
      hideSuggestions();
    } else if (e.key === 'Backspace' && textInput.value === '') {
      // Remove last chip on backspace in empty input
      var current = getValues();
      if (current.length > 0) {
        removeValue(current[current.length - 1]);
      }
    } else if (e.key === 'Escape') {
      hideSuggestions();
    }
  });

  // Suggestions dropdown
  function showSuggestions(filter) {
    if (!suggestions.length) return;
    var current = getValues();
    var filtered = suggestions.filter(function(s) {
      if (current.indexOf(s) !== -1) return false; // already added
      if (filter && s.toLowerCase().indexOf(filter.toLowerCase()) === -1) return false;
      return true;
    });
    if (!filtered.length) { hideSuggestions(); return; }

    if (!suggestionsDropdown) {
      suggestionsDropdown = document.createElement('div');
      suggestionsDropdown.className = 'lcp-array-suggestions';
      wrapper.appendChild(suggestionsDropdown);
    }
    suggestionsDropdown.innerHTML = '';
    filtered.forEach(function(s) {
      var item = document.createElement('div');
      item.className = 'lcp-array-suggestion-item';
      item.textContent = s;
      item.addEventListener('mousedown', function(e) {
        e.preventDefault(); // prevent blur
        addValue(s);
        textInput.value = '';
        hideSuggestions();
        textInput.focus();
      });
      suggestionsDropdown.appendChild(item);
    });
    suggestionsDropdown.style.display = 'block';
  }

  function hideSuggestions() {
    if (suggestionsDropdown) suggestionsDropdown.style.display = 'none';
  }

  textInput.addEventListener('input', function() {
    showSuggestions(textInput.value);
  });

  textInput.addEventListener('focus', function() {
    if (suggestions.length) showSuggestions(textInput.value);
  });

  textInput.addEventListener('blur', function() {
    // Small delay so mousedown on suggestion fires first
    setTimeout(hideSuggestions, 150);
  });

  // Handle clicks on pre-rendered remove buttons (from server-side HTML)
  chipsContainer.addEventListener('click', function(e) {
    var btn = e.target.closest('.lcp-array-chip-remove');
    if (btn) {
      var val = btn.dataset.lcpArrayRemove || btn.previousElementSibling.textContent;
      removeValue(val);
    }
  });
}
