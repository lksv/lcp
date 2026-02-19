// LCP Ruby — Active Storage Direct Upload integration + progress tracking
(function() {
  'use strict';

  // Start Active Storage if available
  if (typeof ActiveStorage !== 'undefined') {
    ActiveStorage.start();
  }

  // Progress tracking for direct uploads
  document.addEventListener('direct-upload:initialize', function(event) {
    var target = event.target;
    var detail = event.detail;
    var container = target.closest('[data-lcp-file-upload]');
    if (!container) return;

    var progressDiv = document.createElement('div');
    progressDiv.className = 'lcp-upload-progress';
    progressDiv.id = 'direct-upload-' + detail.id;
    progressDiv.innerHTML =
      '<div class="lcp-upload-progress-bar"><div class="lcp-upload-progress-fill" style="width: 0%"></div></div>' +
      '<div class="lcp-upload-progress-text">Uploading...</div>';
    container.appendChild(progressDiv);
  });

  document.addEventListener('direct-upload:start', function(event) {
    var progressDiv = document.getElementById('direct-upload-' + event.detail.id);
    if (progressDiv) {
      progressDiv.querySelector('.lcp-upload-progress-text').textContent = 'Uploading...';
    }
  });

  document.addEventListener('direct-upload:progress', function(event) {
    var progressDiv = document.getElementById('direct-upload-' + event.detail.id);
    if (!progressDiv) return;

    var percent = Math.round(event.detail.progress);
    progressDiv.querySelector('.lcp-upload-progress-fill').style.width = percent + '%';
    progressDiv.querySelector('.lcp-upload-progress-text').textContent = percent + '%';
  });

  document.addEventListener('direct-upload:end', function(event) {
    var progressDiv = document.getElementById('direct-upload-' + event.detail.id);
    if (progressDiv) {
      progressDiv.querySelector('.lcp-upload-progress-fill').style.width = '100%';
      progressDiv.querySelector('.lcp-upload-progress-text').textContent = 'Complete';
      setTimeout(function() {
        progressDiv.style.opacity = '0.5';
      }, 1000);
    }
  });

  document.addEventListener('direct-upload:error', function(event) {
    event.preventDefault();
    var progressDiv = document.getElementById('direct-upload-' + event.detail.id);
    if (progressDiv) {
      progressDiv.querySelector('.lcp-upload-progress-fill').style.background = '#dc3545';
      progressDiv.querySelector('.lcp-upload-progress-text').textContent = 'Upload failed: ' + event.detail.error;
    }
  });
})();
