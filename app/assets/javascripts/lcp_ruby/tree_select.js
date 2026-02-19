// Tree select widget
(function() {
  function initTreeSelect(hiddenInput) {
    var treeData = JSON.parse(hiddenInput.getAttribute('data-lcp-tree-data') || '[]');
    var includeBlank = hiddenInput.getAttribute('data-lcp-tree-include-blank') || '';
    var wrapper = hiddenInput.closest('.lcp-tree-select-wrapper');
    if (!wrapper) return;

    var trigger = wrapper.querySelector('.lcp-tree-trigger');
    var dropdown = wrapper.querySelector('.lcp-tree-dropdown');
    if (!trigger || !dropdown) return;

    function renderNodes(nodes, container, depth) {
      nodes.forEach(function(node) {
        var nodeEl = document.createElement('div');
        nodeEl.className = 'lcp-tree-node';

        var itemEl = document.createElement('div');
        itemEl.className = 'lcp-tree-item';
        itemEl.style.paddingLeft = (0.5 + depth * 1.2) + 'rem';
        if (String(node.id) === String(hiddenInput.value)) {
          itemEl.classList.add('selected');
        }

        var toggleEl = document.createElement('span');
        toggleEl.className = 'lcp-tree-toggle';
        if (node.children && node.children.length > 0) {
          toggleEl.textContent = '\u25BC';
        }
        itemEl.appendChild(toggleEl);

        var labelEl = document.createElement('span');
        labelEl.className = 'lcp-tree-label';
        labelEl.textContent = node.label;
        itemEl.appendChild(labelEl);

        nodeEl.appendChild(itemEl);

        if (node.children && node.children.length > 0) {
          var childrenEl = document.createElement('div');
          childrenEl.className = 'lcp-tree-children';
          renderNodes(node.children, childrenEl, depth + 1);
          nodeEl.appendChild(childrenEl);

          toggleEl.addEventListener('click', function(e) {
            e.stopPropagation();
            childrenEl.classList.toggle('collapsed');
            toggleEl.textContent = childrenEl.classList.contains('collapsed') ? '\u25B6' : '\u25BC';
          });
        }

        labelEl.addEventListener('click', function(e) {
          e.stopPropagation();
          // Deselect all
          dropdown.querySelectorAll('.lcp-tree-item.selected').forEach(function(el) {
            el.classList.remove('selected');
          });
          itemEl.classList.add('selected');
          hiddenInput.value = node.id;
          trigger.textContent = node.label;
          dropdown.classList.remove('open');
          hiddenInput.dispatchEvent(new Event('change', { bubbles: true }));
        });

        container.appendChild(nodeEl);
      });
    }

    // Add blank option
    if (includeBlank) {
      var blankItem = document.createElement('div');
      blankItem.className = 'lcp-tree-item';
      blankItem.style.fontStyle = 'italic';
      blankItem.style.color = '#6c757d';
      blankItem.textContent = includeBlank;
      if (!hiddenInput.value || hiddenInput.value === '') {
        blankItem.classList.add('selected');
      }
      blankItem.addEventListener('click', function(e) {
        e.stopPropagation();
        dropdown.querySelectorAll('.lcp-tree-item.selected').forEach(function(el) {
          el.classList.remove('selected');
        });
        blankItem.classList.add('selected');
        hiddenInput.value = '';
        trigger.textContent = includeBlank;
        dropdown.classList.remove('open');
        hiddenInput.dispatchEvent(new Event('change', { bubbles: true }));
      });
      dropdown.appendChild(blankItem);
    }

    renderNodes(treeData, dropdown, 0);

    // Toggle dropdown on trigger click
    trigger.addEventListener('click', function(e) {
      e.stopPropagation();
      dropdown.classList.toggle('open');
    });

    // Close dropdown on outside click
    document.addEventListener('click', function(e) {
      if (!wrapper.contains(e.target)) {
        dropdown.classList.remove('open');
      }
    });
  }

  document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('[data-lcp-tree-select]').forEach(function(input) {
      initTreeSelect(input);
    });
  });
})();
