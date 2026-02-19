/* Shared field value reader — used by conditional_rendering, cascading_selects, and tom_select_init */
window.LcpRuby = window.LcpRuby || {};
window.LcpRuby.getFieldValue = function(form, fieldName) {
  /* Handle checkboxes (Rails hidden+checkbox pattern) */
  var checkboxes = form.querySelectorAll('input[type="checkbox"][name$="[' + fieldName + ']"]');
  if (checkboxes.length > 0) {
    return checkboxes[checkboxes.length - 1].checked ? 'true' : 'false';
  }
  /* Handle radio buttons */
  var radios = form.querySelectorAll('input[type="radio"][name$="[' + fieldName + ']"]');
  if (radios.length > 0) {
    for (var i = 0; i < radios.length; i++) {
      if (radios[i].checked) return radios[i].value;
    }
    return '';
  }
  /* Handle select and other inputs */
  var input = form.querySelector('[name$="[' + fieldName + ']"]');
  if (input) return input.value || '';
  return '';
};
/* Backward-compatible global alias */
var getFieldValue = window.LcpRuby.getFieldValue;
