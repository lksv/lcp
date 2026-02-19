// LCP Ruby — File Upload: drag & drop, client-side preview, client-side validation
(function() {
  'use strict';

  function initFileUpload(container) {
    var fileInput = container.querySelector('[data-lcp-file-input]');
    var dropZone = container.querySelector('[data-lcp-drop-zone]');
    var previewContainer = container.querySelector('[data-lcp-preview-container]');
    var maxSizeStr = container.dataset.lcpMaxSize;
    var maxSize = maxSizeStr ? parseSize(maxSizeStr) : null;

    if (!fileInput) return;

    // Click on drop zone triggers file input
    if (dropZone) {
      dropZone.addEventListener('click', function() {
        fileInput.click();
      });

      // Drag events
      dropZone.addEventListener('dragenter', function(e) {
        e.preventDefault();
        e.stopPropagation();
        dropZone.classList.add('dragover');
      });

      dropZone.addEventListener('dragover', function(e) {
        e.preventDefault();
        e.stopPropagation();
        dropZone.classList.add('dragover');
      });

      dropZone.addEventListener('dragleave', function(e) {
        e.preventDefault();
        e.stopPropagation();
        dropZone.classList.remove('dragover');
      });

      dropZone.addEventListener('drop', function(e) {
        e.preventDefault();
        e.stopPropagation();
        dropZone.classList.remove('dragover');

        var files = e.dataTransfer.files;
        if (files.length > 0) {
          fileInput.files = files;
          var event = new Event('change', { bubbles: true });
          fileInput.dispatchEvent(event);
        }
      });
    }

    // On file change: generate previews and validate
    fileInput.addEventListener('change', function() {
      if (!previewContainer) return;

      previewContainer.innerHTML = '';
      var files = fileInput.files;

      for (var i = 0; i < files.length; i++) {
        var file = files[i];

        // Client-side size validation
        if (maxSize && file.size > maxSize) {
          var errorDiv = document.createElement('div');
          errorDiv.className = 'lcp-file-preview-item';
          errorDiv.style.borderColor = '#dc3545';
          errorDiv.innerHTML = '<span class="lcp-preview-name" style="color: #dc3545;">' +
            escapeHtml(file.name) + ' (' + formatSize(file.size) + ') — too large</span>';
          previewContainer.appendChild(errorDiv);
          continue;
        }

        var previewItem = document.createElement('div');
        previewItem.className = 'lcp-file-preview-item';

        if (file.type.startsWith('image/')) {
          // Generate image preview
          var img = document.createElement('img');
          img.alt = file.name;
          var reader = new FileReader();
          reader.onload = (function(imgEl) {
            return function(e) {
              imgEl.src = e.target.result;
            };
          })(img);
          reader.readAsDataURL(file);
          previewItem.appendChild(img);
        }

        var nameSpan = document.createElement('span');
        nameSpan.className = 'lcp-preview-name';
        nameSpan.textContent = file.name + ' (' + formatSize(file.size) + ')';
        previewItem.appendChild(nameSpan);

        previewContainer.appendChild(previewItem);
      }
    });
  }

  function parseSize(sizeStr) {
    var match = sizeStr.match(/^(\d+(?:\.\d+)?)\s*(B|KB|MB|GB)$/i);
    if (!match) return null;

    var value = parseFloat(match[1]);
    var unit = match[2].toUpperCase();

    switch (unit) {
      case 'B': return value;
      case 'KB': return value * 1024;
      case 'MB': return value * 1024 * 1024;
      case 'GB': return value * 1024 * 1024 * 1024;
      default: return null;
    }
  }

  function formatSize(bytes) {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    return (bytes / (1024 * 1024 * 1024)).toFixed(1) + ' GB';
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  // Initialize on DOMContentLoaded
  document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('[data-lcp-file-upload]').forEach(initFileUpload);
  });
})();
