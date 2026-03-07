/* Shared field value reader — used by conditional_rendering, cascading_selects, and tom_select_init.
   scope: the nearest condition scope (row-level or form-level). Falls back to form. */
window.LcpRuby = window.LcpRuby || {};
window.LcpRuby.getFieldValue = function(scope, fieldName) {
  var container = scope;
  /* Handle checkboxes (Rails hidden+checkbox pattern) */
  var checkboxes = container.querySelectorAll('input[type="checkbox"][name$="[' + fieldName + ']"]');
  if (checkboxes.length > 0) {
    return checkboxes[checkboxes.length - 1].checked ? 'true' : 'false';
  }
  /* Handle radio buttons */
  var radios = container.querySelectorAll('input[type="radio"][name$="[' + fieldName + ']"]');
  if (radios.length > 0) {
    for (var i = 0; i < radios.length; i++) {
      if (radios[i].checked) return radios[i].value;
    }
    return '';
  }
  /* Handle select and other inputs */
  var input = container.querySelector('[name$="[' + fieldName + ']"]');
  if (input) return input.value || '';
  return '';
};
window.LcpRuby.csrfToken = function() {
  var meta = document.querySelector('meta[name="csrf-token"]');
  return meta ? meta.getAttribute('content') : null;
};
/* Backward-compatible global alias */
var getFieldValue = window.LcpRuby.getFieldValue;
