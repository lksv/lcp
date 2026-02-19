/* Slider value display */
document.addEventListener('input', function(e) {
  if (e.target.classList.contains('lcp-slider')) {
    var wrapper = e.target.closest('.lcp-slider-wrapper');
    if (wrapper) {
      var display = wrapper.querySelector('.lcp-slider-value');
      if (display) display.textContent = e.target.value;
    }
  }
});
/* Initialize slider values on load */
document.addEventListener('DOMContentLoaded', function() {
  document.querySelectorAll('.lcp-slider').forEach(function(slider) {
    var wrapper = slider.closest('.lcp-slider-wrapper');
    if (wrapper) {
      var display = wrapper.querySelector('.lcp-slider-value');
      if (display) display.textContent = slider.value;
    }
  });
});

/* Character counter */
document.addEventListener('input', function(e) {
  var counter = e.target.parentNode && e.target.parentNode.querySelector('.lcp-char-counter');
  if (counter && e.target.maxLength > 0) {
    counter.textContent = e.target.value.length + ' / ' + e.target.maxLength;
  }
});
document.addEventListener('DOMContentLoaded', function() {
  document.querySelectorAll('.lcp-char-counter').forEach(function(counter) {
    var textarea = counter.parentNode.querySelector('textarea');
    if (textarea && textarea.maxLength > 0) {
      counter.textContent = textarea.value.length + ' / ' + textarea.maxLength;
    }
  });
});
