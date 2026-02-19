/* Sidebar group collapse/expand */
document.addEventListener('click', function(e) {
  var toggle = e.target.closest('[data-lcp-toggle="sidebar-group"]');
  if (!toggle) return;

  var group = toggle.closest('.lcp-sidebar-group');
  if (group) {
    group.classList.toggle('lcp-sidebar-collapsed');
  }
});
